// Coverage target: LocalPaymentQueue – 4 test cases
// Tests: enqueue+dequeue, update, remove, empty queue
// Each test uses a fresh UserDefaults suite to prevent cross-test pollution.

import Testing
import Foundation
@testable import YunoChallengeSDK

@Suite("LocalPaymentQueue")
struct LocalPaymentQueueTests {

    // MARK: Helpers

    private func makeQueue() -> LocalPaymentQueue {
        // Unique suite name per invocation ensures full test isolation
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return LocalPaymentQueue(defaults: defaults)
    }

    private func makePayment(status: PaymentStatus = .queued) -> Payment {
        Payment(
            request: PaymentRequest(
                billType: .electricity,
                billReference: "REF-\(UUID())",
                amount: 100,
                currency: "USD"
            ),
            status: status
        )
    }

    // MARK: Enqueue + dequeue

    @Test("enqueue and dequeueAll returns all payments")
    func enqueueDequeue() async throws {
        let queue = makeQueue()
        let p1 = makePayment()
        let p2 = makePayment()

        try await queue.enqueue(p1)
        try await queue.enqueue(p2)

        let all = try await queue.dequeueAll()
        #expect(all.count == 2)
        #expect(all.contains { $0.id == p1.id })
        #expect(all.contains { $0.id == p2.id })
    }

    // MARK: Update

    @Test("update modifies existing payment")
    func updatePayment() async throws {
        let queue = makeQueue()
        var payment = makePayment()
        try await queue.enqueue(payment)

        payment.status = .approved
        try await queue.update(payment)

        let all = try await queue.dequeueAll()
        let updated = try #require(all.first { $0.id == payment.id })
        #expect(updated.status == .approved)
    }

    // MARK: Remove

    @Test("remove deletes payment by id")
    func removePayment() async throws {
        let queue = makeQueue()
        let payment = makePayment()
        try await queue.enqueue(payment)

        try await queue.remove(id: payment.id)

        let all = try await queue.dequeueAll()
        #expect(all.isEmpty)
    }

    // MARK: Empty state

    @Test("empty queue returns empty array")
    func emptyQueue() async throws {
        let queue = makeQueue()
        let all = try await queue.dequeueAll()
        #expect(all.isEmpty)
    }
}
