import Foundation
import Observation
import YunoChallengeSDK

/// The view model for `PaymentDashboardView`, providing derived display state from
/// the SDK's payment list.
///
/// `PaymentDashboardViewModel` uses the `@Observable` macro for fine-grained
/// observation: SwiftUI re-renders only the portions of `PaymentDashboardView`
/// that read properties that actually changed, rather than the entire view tree.
///
/// All computed properties read from `sdk.payments`, which is a `@Published`
/// property on `YunoChallengeSDK`. Because `YunoChallengeSDK` is an
/// `ObservableObject`, changes propagate automatically and `@Observable` picks
/// them up without additional wiring.
///
/// ## Topics
/// ### Related Views
/// - `PaymentDashboardView`
/// ### Related SDK Types
/// - ``YunoChallengeSDK``
/// - ``Payment``
/// - ``PaymentStatus``
@Observable
@MainActor
final class PaymentDashboardViewModel {

    // MARK: - Properties

    /// The SDK instance used as the single source of truth for payment data.
    private let sdk: YunoChallengeSDK

    /// The current list of all payments, mirrored from `sdk.payments`.
    var payments: [Payment] { sdk.payments }

    /// The number of payments currently in a pending lifecycle state.
    ///
    /// Payments with status ``PaymentStatus/queued`` or ``PaymentStatus/processing``
    /// are considered pending. This count drives the summary badge in the dashboard.
    var pendingCount: Int {
        payments.filter { $0.status == .queued || $0.status == .processing }.count
    }

    /// The sum of amounts for all approved payments in the current session.
    ///
    /// Uses `Decimal` arithmetic to avoid floating-point precision errors.
    var approvedTotal: Decimal {
        payments
            .filter { $0.status == .approved }
            .reduce(Decimal.zero) { $0 + $1.request.amount }
    }

    // MARK: - Lifecycle

    /// Creates a view model backed by the given SDK instance.
    ///
    /// - Parameter sdk: The `YunoChallengeSDK` singleton that owns the payment list.
    init(sdk: YunoChallengeSDK) {
        self.sdk = sdk
    }
}
