import Foundation

/// Defines the interface for submitting a payment to a remote payment processor.
///
/// Implementations must be `Sendable` to allow safe use across Swift concurrency
/// contexts. The SDK ships ``MockPaymentAPI`` as a deterministic test implementation.
/// Production apps are expected to provide a real network implementation.
///
/// ``PaymentSyncService`` calls `submit(_:)` inside its retry loop, relying on thrown
/// errors to drive ``RetryPolicy`` decisions.
///
/// ## Topics
/// ### Implementations
/// - ``MockPaymentAPI``
public protocol PaymentAPIProtocol: Sendable {

    /// Submits a payment to the remote payment processor and returns the result.
    ///
    /// This call performs a network round-trip. Retryable failures should be communicated
    /// via thrown errors (e.g. `URLError`) so that ``RetryPolicy`` can make a
    /// `retry` vs `permanentFailure` decision. Business-level rejections such as
    /// insufficient funds must be communicated via the returned ``PaymentStatus``
    /// (e.g. ``PaymentStatus/declined``), not by throwing.
    ///
    /// - Parameter payment: The ``Payment`` to submit, including its idempotency key.
    /// - Returns: The ``PaymentStatus`` assigned by the processor (typically
    ///   ``PaymentStatus/approved`` or ``PaymentStatus/declined``).
    /// - Throws: `URLError` for network-level failures that may be retried.
    func submit(_ payment: Payment) async throws -> PaymentStatus
}
