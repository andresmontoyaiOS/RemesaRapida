import Foundation

/// A fully-tracked bill payment record that wraps a ``PaymentRequest`` with
/// lifecycle metadata, idempotency support, and retry bookkeeping.
///
/// `Payment` is the core entity persisted by ``LocalPaymentQueue`` and processed
/// by ``PaymentSyncService``. Every field is `public` so that the host application
/// can observe and display payment state without needing internal access.
///
/// A payment is created with ``PaymentStatus/queued`` status and transitions through
/// the states described in ``PaymentStatus`` as `PaymentSyncService` processes it.
///
/// ## Example
/// ```swift
/// let payment = Payment(
///     request: PaymentRequest(
///         billType: .water,
///         billReference: "W-9901",
///         amount: 42.00,
///         currency: "USD"
///     )
/// )
/// // payment.status == .queued
/// // payment.retryCount == 0
/// ```
///
/// ## Topics
/// ### Related Types
/// - ``PaymentRequest``
/// - ``PaymentStatus``
/// - ``PaymentQueueProtocol``
public struct Payment: Codable, Identifiable, Sendable {

    // MARK: - Properties

    /// A stable unique identifier for this payment record.
    public let id: UUID

    /// A unique key used to detect and prevent duplicate API submissions.
    ///
    /// Before calling the payment API, ``PaymentSyncService`` checks
    /// ``IdempotencyManager/hasBeenSubmitted(key:)`` with this key.
    /// If the key is already marked, the payment is resolved as ``PaymentStatus/approved``
    /// without making a network request.
    public let idempotencyKey: UUID

    /// The original payment details supplied by the user.
    public let request: PaymentRequest

    /// The current lifecycle state of this payment. Updated by ``PaymentSyncService``.
    public var status: PaymentStatus

    /// The number of times the API submission has been attempted after the initial try.
    ///
    /// Incremented by ``PaymentSyncService`` each time a retryable error is encountered.
    /// Capped at ``RetryPolicy/maxAttempts``.
    public var retryCount: Int

    /// The timestamp at which this payment record was originally created.
    public let createdAt: Date

    /// The timestamp of the most recent status change or retry attempt.
    public var updatedAt: Date

    // MARK: - Lifecycle

    /// Creates a new payment record.
    ///
    /// Default values are appropriate for newly queued payments. Explicit arguments
    /// are provided when reconstituting payments from persistent storage.
    ///
    /// - Parameters:
    ///   - id: Stable unique identifier. Defaults to a new `UUID`.
    ///   - idempotencyKey: Deduplication key for API submissions. Defaults to a new `UUID`.
    ///   - request: The billing details for this payment.
    ///   - status: Initial lifecycle state. Defaults to ``PaymentStatus/queued``.
    ///   - retryCount: Number of previous retry attempts. Defaults to `0`.
    ///   - createdAt: Creation timestamp. Defaults to the current date.
    ///   - updatedAt: Last-modified timestamp. Defaults to the current date.
    public init(
        id: UUID = UUID(),
        idempotencyKey: UUID = UUID(),
        request: PaymentRequest,
        status: PaymentStatus = .queued,
        retryCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.request = request
        self.status = status
        self.retryCount = retryCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
