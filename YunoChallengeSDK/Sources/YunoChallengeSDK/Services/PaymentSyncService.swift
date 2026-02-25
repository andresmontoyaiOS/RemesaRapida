import Foundation

/// The central orchestrator that manages offline queuing, network-triggered
/// processing, retry logic, and idempotency enforcement for bill payments.
///
/// `PaymentSyncService` is `@MainActor`-isolated so that it can safely update
/// `@Published` state on `YunoChallengeSDK` without explicit `DispatchQueue.main` hops.
///
/// ### Submission flow
/// ```
/// submit(_:)
///   └─ enqueue payment (status: .queued)
///   └─ if online → processQueue()
///        └─ for each pending payment:
///             └─ submitWithRetry(_:)
///                  └─ idempotency check → skip if already approved
///                  └─ mark .processing
///                  └─ api.submit(_:) → retry on transient URLError
///                  └─ mark .approved / .declined / .failed
///   └─ notifyUpdated() → onPaymentsUpdated callback
/// ```
///
/// ### Connectivity-triggered processing
/// `start()` opens a long-lived `Task` that iterates
/// ``NetworkMonitorProtocol/connectionUpdates``. Each `true` event triggers
/// ``processQueue()``, ensuring that queued payments are submitted as soon as the
/// device regains connectivity.
///
/// ## Topics
/// ### Related Types
/// - ``PaymentQueueProtocol``
/// - ``PaymentAPIProtocol``
/// - ``NetworkMonitorProtocol``
/// - ``IdempotencyManager``
/// - ``RetryPolicy``
@MainActor
public final class PaymentSyncService {

    // MARK: - Properties

    /// The persistent queue used to store and retrieve payments.
    private let queue: any PaymentQueueProtocol

    /// The API used to submit payments to the remote processor.
    private let api: any PaymentAPIProtocol

    /// The network monitor used to observe connectivity changes.
    private let monitor: any NetworkMonitorProtocol

    /// The idempotency manager that prevents duplicate API submissions.
    private let idempotencyManager: IdempotencyManager

    /// A callback invoked after every queue mutation to notify the SDK layer of state changes.
    private var onPaymentsUpdated: (@Sendable ([Payment]) -> Void)?

    /// The long-lived `Task` that observes ``NetworkMonitorProtocol/connectionUpdates``.
    private var monitoringTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// Creates a `PaymentSyncService` wired to the given infrastructure dependencies.
    ///
    /// - Parameters:
    ///   - queue: The persistent store for pending and completed payments.
    ///   - api: The remote payment processor to submit payments to.
    ///   - monitor: The network reachability observer.
    ///   - idempotencyManager: The store of previously submitted payment keys.
    ///     Defaults to a new ``IdempotencyManager`` instance.
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

    // MARK: - Public API

    /// Registers a callback to be invoked whenever the queue contents change.
    ///
    /// The callback receives the full current snapshot of all payments. Use this
    /// to propagate updates to the presentation layer. `YunoChallengeSDK` uses
    /// this to update its `@Published var payments` property.
    ///
    /// - Parameter handler: A `@Sendable` closure receiving the updated payment array.
    public func setOnPaymentsUpdated(_ handler: @escaping @Sendable ([Payment]) -> Void) {
        self.onPaymentsUpdated = handler
    }

    /// Starts the connectivity monitor and begins listening for network-change events.
    ///
    /// Each time ``NetworkMonitorProtocol/connectionUpdates`` emits `true`,
    /// ``processQueue()`` is called automatically. If a `SystemNetworkMonitor`
    /// is detected as the concrete implementation, its `startMonitoring()` method
    /// is also invoked to activate `NWPathMonitor`.
    ///
    /// Calling `start()` cancels any previously active monitoring task before
    /// creating a new one.
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

    /// Enqueues a payment request and, if the device is online, immediately processes the queue.
    ///
    /// The payment is always persisted to the queue first to guarantee durability
    /// regardless of connectivity. If the device is online, ``processQueue()`` is
    /// called inline so the user sees a result without waiting for a connectivity event.
    ///
    /// - Parameter request: The billing details for the payment to submit.
    /// - Throws: An error from ``PaymentQueueProtocol/enqueue(_:)`` if the payment
    ///   cannot be persisted locally.
    public func submit(_ request: PaymentRequest) async throws {
        let payment = Payment(request: request)
        try await queue.enqueue(payment)
        await notifyUpdated()
        let connected = await monitor.isConnected
        if connected {
            await processQueue()
        }
    }

    /// Fetches all queued or failed payments and attempts to submit each one via the API.
    ///
    /// Only payments with status ``PaymentStatus/queued`` or ``PaymentStatus/failed``
    /// are eligible for processing. Payments that are ``PaymentStatus/processing``,
    /// ``PaymentStatus/approved``, or ``PaymentStatus/declined`` are skipped.
    ///
    /// After processing all eligible payments, ``notifyUpdated()`` is called to
    /// propagate the latest queue snapshot to the presentation layer.
    public func processQueue() async {
        guard let allPayments = try? await queue.dequeueAll() else { return }
        let pending = allPayments.filter { $0.status == .queued || $0.status == .failed }
        for payment in pending {
            var mutablePayment = payment
            await submitWithRetry(&mutablePayment)
        }
        await notifyUpdated()
    }

    // MARK: - Private Helpers

    /// Submits a single payment to the API, applying idempotency checks and retry logic.
    ///
    /// The submission flow:
    /// 1. If the idempotency key is already recorded, resolve the payment as `.approved`
    ///    without making a network call.
    /// 2. Mark the payment as `.processing` and persist the change.
    /// 3. Call `api.submit(_:)` in a retry loop governed by ``RetryPolicy``.
    /// 4. On success, record the idempotency key and update the status to the API result.
    /// 5. On permanent failure (non-retryable error or retry exhaustion), mark the
    ///    payment as `.failed` with the accumulated `retryCount`.
    ///
    /// - Parameter payment: An `inout` reference to the payment being processed.
    ///   The payment's `status`, `retryCount`, and `updatedAt` are mutated in place
    ///   and persisted to the queue after each state transition.
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

    /// Fetches the current queue snapshot and invokes the registered update callback.
    ///
    /// Called after every queue mutation (enqueue, status update) to keep the
    /// presentation layer in sync.
    private func notifyUpdated() async {
        let payments = (try? await queue.dequeueAll()) ?? []
        onPaymentsUpdated?(payments)
    }
}
