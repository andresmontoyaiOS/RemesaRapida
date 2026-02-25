import Foundation
import Observation
import YunoChallengeSDK

/// The view model for `PaymentSubmissionView`, managing form field state, validation,
/// submission coordination, and error display.
///
/// `PaymentSubmissionViewModel` uses the `@Observable` macro so that SwiftUI only
/// re-renders the specific form fields whose backing properties changed, rather than
/// the entire form.
///
/// When ``submit()`` is called, the view model constructs a ``PaymentRequest`` from
/// the current field values and delegates to `YunoChallengeSDK.submitPayment(_:)`.
/// On success it sets ``didSubmitSuccessfully`` to `true`, which `PaymentSubmissionView`
/// observes via `onChange(of:)` to dismiss the sheet.
///
/// ## Topics
/// ### Related Views
/// - `PaymentSubmissionView`
/// ### Related SDK Types
/// - ``YunoChallengeSDK``
/// - ``PaymentRequest``
/// - ``BillType``
@Observable
@MainActor
final class PaymentSubmissionViewModel {

    // MARK: - Properties

    /// The bill category selected by the user. Defaults to ``BillType/electricity``.
    var selectedBillType: BillType = .electricity

    /// The provider-specific account or reference number entered by the user.
    var billReference: String = ""

    /// The payment amount entered by the user as a raw string from the text field.
    ///
    /// Validated by converting to `Decimal` via ``isFormValid``.
    var amountText: String = ""

    /// The ISO 4217 currency code entered by the user. Defaults to `"USD"`.
    var currency: String = "USD"

    /// Indicates that an async submission is currently in progress.
    ///
    /// The submit button is disabled while this is `true` to prevent duplicate taps.
    var isSubmitting = false

    /// A localized error description to present in an alert when submission fails.
    ///
    /// Set to `nil` to dismiss the alert.
    var errorMessage: String?

    /// Set to `true` when the payment has been successfully queued (or submitted).
    ///
    /// `PaymentSubmissionView` uses `onChange(of:)` on this property to dismiss itself.
    var didSubmitSuccessfully = false

    /// The SDK instance used to submit the constructed payment request.
    private let sdk: YunoChallengeSDK

    // MARK: - Computed Properties

    /// Returns `true` when all required form fields contain valid input.
    ///
    /// Validity requires a non-empty ``billReference`` and a parseable
    /// positive `Decimal` in ``amountText``.
    var isFormValid: Bool {
        !billReference.isEmpty && Decimal(string: amountText) != nil
    }

    // MARK: - Lifecycle

    /// Creates a view model backed by the given SDK instance.
    ///
    /// - Parameter sdk: The `YunoChallengeSDK` singleton that will receive the submitted request.
    init(sdk: YunoChallengeSDK) {
        self.sdk = sdk
    }

    // MARK: - Public API

    /// Validates the form and submits the payment request to the SDK.
    ///
    /// This method is a no-op if ``isFormValid`` is `false`. On success,
    /// ``didSubmitSuccessfully`` is set to `true`. On failure, ``errorMessage``
    /// is populated with the localized error description.
    ///
    /// The ``isSubmitting`` flag is set to `true` for the duration of the async
    /// call and reset to `false` upon completion regardless of outcome.
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
