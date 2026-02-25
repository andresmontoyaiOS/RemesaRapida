import Foundation

@MainActor
public final class PaymentSyncService {
    private let queue: any PaymentQueueProtocol
    private let api: any PaymentAPIProtocol
    private let monitor: any NetworkMonitorProtocol
    private let idempotencyManager: IdempotencyManager
    private var onPaymentsUpdated: (@Sendable ([Payment]) -> Void)?
    private var monitoringTask: Task<Void, Never>?

    public init(
        queue: any PaymentQueueProtocol,
        api: any PaymentAPIProtocol,
        monitor: any NetworkMonitorProtocol,
        idempotencyManager: IdempotencyManager = IdempotencyManager()
    ) {
        self.queue = queue
        self.api = api
        self.monitor = monitor
        self.idempotencyManager = idempotencyManager
    }

    public func setOnPaymentsUpdated(_ handler: @escaping @Sendable ([Payment]) -> Void) {
        self.onPaymentsUpdated = handler
    }

    public func start() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            for await isConnected in self.monitor.connectionUpdates {
                if isConnected {
                    await self.processQueue()
                }
            }
        }
        if let sysMonitor = monitor as? SystemNetworkMonitor {
            Task { await sysMonitor.startMonitoring() }
        }
    }

    public func submit(_ request: PaymentRequest) async throws {
        let payment = Payment(request: request)
        try await queue.enqueue(payment)
        await notifyUpdated()
        let connected = await monitor.isConnected
        if connected {
            await processQueue()
        }
    }

    public func processQueue() async {
        guard let allPayments = try? await queue.dequeueAll() else { return }
        let pending = allPayments.filter { $0.status == .queued || $0.status == .failed }
        for payment in pending {
            var mutablePayment = payment
            await submitWithRetry(&mutablePayment)
        }
        await notifyUpdated()
    }

    private func submitWithRetry(_ payment: inout Payment) async {
        let alreadySubmitted = await idempotencyManager.hasBeenSubmitted(key: payment.idempotencyKey)
        if alreadySubmitted {
            payment.status = .approved
            payment.updatedAt = Date()
            try? await queue.update(payment)
            return
        }

        payment.status = .processing
        payment.updatedAt = Date()
        try? await queue.update(payment)

        var attempt = 0
        while attempt < RetryPolicy.maxAttempts {
            do {
                let result = try await api.submit(payment)
                payment.status = result
                payment.updatedAt = Date()
                if result == .approved {
                    await idempotencyManager.markSubmitted(key: payment.idempotencyKey)
                }
                try? await queue.update(payment)
                return
            } catch {
                attempt += 1
                switch RetryPolicy.decide(error: error, attempt: attempt) {
                case .retry(let delay):
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                case .permanentFailure:
                    payment.status = .failed
                    payment.retryCount = attempt
                    payment.updatedAt = Date()
                    try? await queue.update(payment)
                    return
                }
            }
        }

        payment.status = .failed
        payment.retryCount = attempt
        payment.updatedAt = Date()
        try? await queue.update(payment)
    }

    private func notifyUpdated() async {
        let payments = (try? await queue.dequeueAll()) ?? []
        onPaymentsUpdated?(payments)
    }
}
