import Foundation
import Combine

/// The main entry point for the YunoChallengeSDK.
///
/// `YunoChallengeSDK` is a singleton `ObservableObject` that exposes a
/// `@Published` payment list to SwiftUI and delegates all business logic to
/// a ``PaymentSyncService`` instance wired up during ``configure(queue:api:monitor:)``.
///
/// ### Setup
/// Call ``configure(queue:api:monitor:)`` once at app launch (typically from
/// ``AppContainer``) before submitting any payments:
///
/// ```swift
/// YunoChallengeSDK.shared.configure(
///     queue: LocalPaymentQueue(),
///     api: MockPaymentAPI(),
///     monitor: SystemNetworkMonitor()
/// )
/// ```
///
/// ### Submitting payments
/// ```swift
/// let request = PaymentRequest(
///     billType: .electricity,
///     billReference: "ACCT-9901",
///     amount: 120.00,
///     currency: "USD"
/// )
/// try await YunoChallengeSDK.shared.submitPayment(request)
/// ```
///
/// ### SwiftUI integration
/// Inject the shared instance as an environment object and bind to `payments`
/// for automatic UI updates:
/// ```swift
/// @EnvironmentObject private var sdk: YunoChallengeSDK
/// // sdk.payments is @Published and triggers view re-renders on change
/// ```
///
/// ## Topics
/// ### Configuration
/// - ``configure(queue:api:monitor:)``
/// ### Submitting Payments
/// - ``submitPayment(_:)``
/// ### Observing State
/// - ``payments``
/// ### Errors
/// - ``SDKError``
@MainActor
public final class YunoChallengeSDK: ObservableObject {

    // MARK: - Properties

    /// The shared singleton instance of the SDK.
    ///
    /// Always use this instance to avoid creating multiple isolated state stores.
    public static let shared = YunoChallengeSDK()

    /// The current list of all payments known to the SDK, updated automatically
    /// as payments move through the submission pipeline.
    ///
    /// Because `YunoChallengeSDK` conforms to `ObservableObject` and this property
    /// is `@Published`, SwiftUI views that observe the SDK re-render whenever
    /// the array changes.
    @Published public private(set) var payments: [Payment] = []

    /// The internal sync service responsible for queuing, submitting, and retrying payments.
    private var syncService: PaymentSyncService?

    // MARK: - Lifecycle

    private init() {}

    // MARK: - Public API

    /// Configures the SDK with the given infrastructure dependencies and starts monitoring.
    ///
    /// This method must be called exactly once before any calls to ``submitPayment(_:)``.
    /// Calling it again replaces the existing service and restarts network monitoring.
    ///
    /// - Parameters:
    ///   - queue: A ``PaymentQueueProtocol`` implementation for persistent storage.
    ///   - api: A ``PaymentAPIProtocol`` implementation for remote submission.
    ///   - monitor: A ``NetworkMonitorProtocol`` implementation for connectivity events.
    public func configure(
        queue: any PaymentQueueProtocol,
        api: any PaymentAPIProtocol,
        monitor: any NetworkMonitorProtocol
    ) {
        let service = PaymentSyncService(queue: queue, api: api, monitor: monitor)
        service.setOnPaymentsUpdated { [weak self] updated in
            Task { @MainActor [weak self] in
                self?.payments = updated
            }
        }
        self.syncService = service
        service.start()
    }

    /// Submits a payment request through the SDK's offline-capable pipeline.
    ///
    /// The request is immediately persisted to the local queue. If the device is
    /// online, submission is attempted synchronously. If offline, the payment is
    /// held in the queue and submitted automatically when connectivity is restored.
    ///
    /// - Parameter request: The billing details to submit.
    /// - Throws: ``SDKError/notConfigured`` if ``configure(queue:api:monitor:)`` has
    ///   not been called, or a queue persistence error if the payment cannot be stored.
    public func submitPayment(_ request: PaymentRequest) async throws {
        guard let service = syncService else { throw SDKError.notConfigured }
        try await service.submit(request)
    }
}

/// Errors thrown by the top-level ``YunoChallengeSDK`` interface.
///
/// ## Topics
/// ### Cases
/// - ``notConfigured``
public enum SDKError: Error, Sendable {
    /// The SDK was used before ``YunoChallengeSDK/configure(queue:api:monitor:)`` was called.
    case notConfigured
}
