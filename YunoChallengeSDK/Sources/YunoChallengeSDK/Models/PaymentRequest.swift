import Foundation

/// The user-supplied details required to initiate a bill payment.
///
/// A `PaymentRequest` is a pure value type that carries no lifecycle state.
/// It is wrapped inside a ``Payment`` when enqueued, which adds identifiers,
/// status tracking, and retry metadata.
///
/// ## Example
/// ```swift
/// let request = PaymentRequest(
///     billType: .electricity,
///     billReference: "ACCT-00123",
///     amount: 85.50,
///     currency: "USD"
/// )
/// try await sdk.submitPayment(request)
/// ```
///
/// ## Topics
/// ### Related Types
/// - ``Payment``
/// - ``BillType``
public struct PaymentRequest: Codable, Sendable {

    // MARK: - Properties

    /// The category of the bill being paid.
    public let billType: BillType

    /// The provider-specific account or reference number for the bill.
    ///
    /// This value is passed verbatim to the payment API and is used by
    /// ``MockPaymentAPI`` to deterministically simulate different API outcomes.
    public let billReference: String

    /// The monetary amount to pay, expressed as a `Decimal` to avoid floating-point precision loss.
    ///
    /// Must be a positive value. The API does not validate the amount range; callers
    /// should enforce business rules before constructing the request.
    public let amount: Decimal

    /// The ISO 4217 currency code (e.g. `"USD"`, `"EUR"`).
    public let currency: String

    // MARK: - Lifecycle

    /// Creates a new payment request with the provided billing details.
    ///
    /// - Parameters:
    ///   - billType: The category of the utility or service bill.
    ///   - billReference: The account or reference number issued by the provider.
    ///   - amount: The amount to pay. Must be a positive `Decimal` value.
    ///   - currency: The ISO 4217 currency code for the transaction.
    public init(billType: BillType, billReference: String, amount: Decimal, currency: String) {
        self.billType = billType
        self.billReference = billReference
        self.amount = amount
        self.currency = currency
    }
}
