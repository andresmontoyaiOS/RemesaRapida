import Foundation

/// Defines the interface for a persistent, actor-safe payment queue.
///
/// Implementations are responsible for durably storing ``Payment`` records so that
/// pending payments survive app restarts. ``LocalPaymentQueue`` provides the
/// production implementation backed by `UserDefaults`.
///
/// All methods are `async throws` to accommodate actor-isolated implementations and
/// potential I/O errors during serialization or persistence.
///
/// ## Topics
/// ### Implementations
/// - ``LocalPaymentQueue``
public protocol PaymentQueueProtocol: Sendable {

    /// Appends a payment to the end of the persistent queue.
    ///
    /// - Parameter payment: The ``Payment`` to persist. The payment's `id` must be
    ///   unique within the queue; duplicates are not checked by the protocol contract.
    /// - Throws: A serialization error if the payment cannot be encoded for storage.
    func enqueue(_ payment: Payment) async throws

    /// Returns all payments currently held in the queue without removing them.
    ///
    /// - Returns: An array of ``Payment`` in insertion order. Returns an empty array
    ///   if the queue contains no entries.
    /// - Throws: A deserialization error if stored data cannot be decoded.
    func dequeueAll() async throws -> [Payment]

    /// Replaces the stored entry for a payment with an updated version.
    ///
    /// The payment is matched by its ``Payment/id``. If no matching entry exists,
    /// the call is a no-op; no error is thrown.
    ///
    /// - Parameter payment: The updated ``Payment`` value to persist.
    /// - Throws: A serialization error if the updated payment cannot be encoded.
    func update(_ payment: Payment) async throws

    /// Removes a payment from the queue by its unique identifier.
    ///
    /// If no payment with the given `id` exists, the call is a no-op.
    ///
    /// - Parameter id: The ``Payment/id`` of the entry to delete.
    /// - Throws: A serialization error if the updated queue cannot be persisted.
    func remove(id: UUID) async throws
}
