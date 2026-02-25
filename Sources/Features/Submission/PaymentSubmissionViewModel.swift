import Foundation
import Observation
import YunoChallengeSDK

@Observable
@MainActor
final class PaymentSubmissionViewModel {
    var selectedBillType: BillType = .electricity
    var billReference: String = ""
    var amountText: String = ""
    var currency: String = "USD"
    var isSubmitting = false
    var errorMessage: String?
    var didSubmitSuccessfully = false

    private let sdk: YunoChallengeSDK

    var isFormValid: Bool {
        !billReference.isEmpty && Decimal(string: amountText) != nil
    }

    init(sdk: YunoChallengeSDK) {
        self.sdk = sdk
    }

    func submit() async {
        guard let amount = Decimal(string: amountText), isFormValid else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let request = PaymentRequest(
                billType: selectedBillType,
                billReference: billReference,
                amount: amount,
                currency: currency
            )
            try await sdk.submitPayment(request)
            didSubmitSuccessfully = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
