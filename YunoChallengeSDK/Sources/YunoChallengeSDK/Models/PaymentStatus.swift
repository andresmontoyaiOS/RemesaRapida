import Foundation

/// The lifecycle state of a ``Payment`` as it moves through the submission pipeline.
///
/// Status transitions follow a directed path:
///
/// ```
/// queued → processing → approved
///                     → declined
///        → failed  (after retry exhaustion)
/// ```
///
/// The ``PaymentSyncService`` drives all status transitions during queue processing.
///
/// ## Topics
/// ### States
/// - ``queued``
/// - ``processing``
/// - ``approved``
/// - ``declined``
/// - ``failed``
public enum PaymentStatus: String, Codable, Sendable {
    /// The payment is persisted locally and awaiting network connectivity.
    case queued
    /// The payment has been picked up by ``PaymentSyncService`` and an API call is in flight.
    case processing
    /// The payment was accepted and settled by the payment API.
    case approved
    /// The payment was rejected by the payment API as a business decision (not retried).
    case declined
    /// The payment exhausted all retry attempts defined by ``RetryPolicy/maxAttempts``.
    case failed
}
