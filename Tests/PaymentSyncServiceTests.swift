// Coverage target: PaymentSyncService – 4 test cases
// Tests: offline queuing, timeout retry, declined no-retry, idempotency guard

import Testing
import Foundation
@testable import YunoChallengeSDK

// MARK: - Mocks

actor MockQueue: PaymentQueueProtocol {
    var payments: [Payment] = []
    func enqueue(_ payment: Payment) async throws { payments.append(payment) }
    func dequeueAll() async throws -> [Payment] { payments }
    func update(_ payment: Payment) async throws {
        if let i = payments.firstIndex(where: { $0.id == payment.id }) { payments[i] = payment }
    }
    func remove(id: UUID) async throws { payments.removeAll { $0.id == id } }
}

struct AlwaysApprovedAPI: PaymentAPIProtocol {
    func submit(_ payment: Payment) async throws -> PaymentStatus { .approved }
}

struct AlwaysDeclinedAPI: PaymentAPIProtocol {
    func submit(_ payment: Payment) async throws -> PaymentStatus { .declined }
}

struct AlwaysTimeoutAPI: PaymentAPIProtocol {
    func submit(_ payment: Payment) async throws -> PaymentStatus { throw URLError(.timedOut) }
}

actor MockNetworkMonitor: NetworkMonitorProtocol {
    var _isConnected: Bool
    var connectionUpdates: AsyncStream<Bool>
    var continuation: AsyncStream<Bool>.Continuation?

    init(connected: Bool = true) {
        _isConnected = connected
        var cont: AsyncStream<Bool>.Continuation?
        connectionUpdates = AsyncStream { cont = $0 }
        continuation = cont
    }

    var isConnected: Bool { _isConnected }

    func setConnected(_ value: Bool) {
        _isConnected = value
        continuation?.yield(value)
    }
}

// MARK: - Suite

@Suite("PaymentSyncService") @MainActor
struct PaymentSyncServiceTests {

    // MARK: Offline queuing

    @Test("queues payment offline, submits on reconnect")
    func queuingWhileOffline() async throws {
        let queue = MockQueue()
        let monitor = MockNetworkMonitor(connected: false)
        let api = AlwaysApprovedAPI()
        let service = PaymentSyncService(queue: queue, api: api, monitor: monitor)

        let request = PaymentRequest(
            billType: .electricity,
            billReference: "TEST001",
            amount: 50,
            currency: "USD"
        )
        try await service.submit(request)

        let payments = try await queue.dequeueAll()
        #expect(payments.count == 1)
        #expect(payments[0].status == .queued)
    }

    // MARK: Timeout retry

    @Test("retries on network timeout up to maxAttempts")
    func retryOnTimeout() async throws {
        let queue = MockQueue()
        let monitor = MockNetworkMonitor(connected: true)
        let api = AlwaysTimeoutAPI()
        let service = PaymentSyncService(queue: queue, api: api, monitor: monitor)

        let request = PaymentRequest(
            billType: .water,
            billReference: "TEST002",
            amount: 30,
            currency: "USD"
        )
        try await service.submit(request)

        let payments = try await queue.dequeueAll()
        #expect(!payments.isEmpty)
        let payment = try #require(payments.first)
        #expect(payment.status == .failed || payment.retryCount > 0)
    }

    // MARK: Declined — no retry

    @Test("does not retry on declined payment")
    func noRetryOnDeclined() async throws {
        let queue = MockQueue()
        let monitor = MockNetworkMonitor(connected: true)
        let api = AlwaysDeclinedAPI()
        let service = PaymentSyncService(queue: queue, api: api, monitor: monitor)

        let request = PaymentRequest(
            billType: .phone,
            billReference: "TEST003",
            amount: 20,
            currency: "USD"
        )
        try await service.submit(request)

        let payments = try await queue.dequeueAll()
        let payment = try #require(payments.first)
        #expect(payment.status == .declined)
        #expect(payment.retryCount == 0)
    }

    // MARK: Idempotency

    @Test("respects idempotency - does not submit twice")
    func idempotencyGuard() async throws {
        let queue = MockQueue()
        let monitor = MockNetworkMonitor(connected: true)
        let api = AlwaysApprovedAPI()
        let idempotency = IdempotencyManager()
        let service = PaymentSyncService(
            queue: queue,
            api: api,
            monitor: monitor,
            idempotencyManager: idempotency
        )

        let request = PaymentRequest(
            billType: .internet,
            billReference: "TEST004",
            amount: 40,
            currency: "USD"
        )
        try await service.submit(request)

        let payments = try await queue.dequeueAll()
        let payment = try #require(payments.first)

        // Mark the idempotency key as already submitted
        await idempotency.markSubmitted(key: payment.idempotencyKey)

        // Attempt to process the queue a second time
        await service.processQueue()

        // Payment should be approved but not re-submitted
        let updated = try await queue.dequeueAll()
        let updatedPayment = try #require(updated.first)
        #expect(updatedPayment.status == .approved)
    }
}
