import Foundation
import Observation
import YunoChallengeSDK

@Observable
@MainActor
final class PaymentDashboardViewModel {
    private let sdk: YunoChallengeSDK

    var payments: [Payment] { sdk.payments }

    var pendingCount: Int {
        payments.filter { $0.status == .queued || $0.status == .processing }.count
    }

    var approvedTotal: Decimal {
        payments
            .filter { $0.status == .approved }
            .reduce(Decimal.zero) { $0 + $1.request.amount }
    }

    init(sdk: YunoChallengeSDK) {
        self.sdk = sdk
    }
}
