import Foundation

/// A persistent, actor-isolated payment queue backed by `UserDefaults`.
///
/// `LocalPaymentQueue` serializes ``Payment`` values to JSON and stores them under
/// a fixed `UserDefaults` key. Actor isolation guarantees that concurrent queue
/// mutations from multiple Swift tasks are always serialized, preventing data races.
///
/// The queue survives process termination, enabling offline-first behavior: payments
/// enqueued while the device is offline remain available after the app relaunches.
///
/// Inject a custom `UserDefaults` suite in tests to isolate state between runs:
/// ```swift
/// let queue = LocalPaymentQueue(defaults: UserDefaults(suiteName: "test-suite")!)
/// ```
///
/// ## Topics
/// ### Protocol Conformance
/// - ``PaymentQueueProtocol``
public actor LocalPaymentQueue: PaymentQueueProtocol {

    // MARK: - Properties

    /// The `UserDefaults` key under which the encoded payment array is stored.
    private let key = "com.yunochallengesdk.queue"

    /// The `UserDefaults` instance used for persistence. Injected at initialization.
    private let defaults: UserDefaults

    // MARK: - Lifecycle

    /// Creates a queue that persists payments in the given `UserDefaults` instance.
    ///
    /// - Parameter defaults: The `UserDefaults` store to use. Defaults to
    ///   `UserDefaults.standard`. Pass a custom suite in tests to prevent
    ///   cross-test state pollution.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Appends a payment to the persistent queue.
    ///
    /// - Parameter payment: The ``Payment`` to store.
    /// - Throws: An `EncodingError` if the payment array cannot be JSON-encoded.
    public func enqueue(_ payment: Payment) async throws {
        var payments = try loadAll()
        payments.append(payment)
        try save(payments)
    }

    /// Returns all payments currently held in the queue without removing them.
    ///
    /// - Returns: An array of ``Payment`` in insertion order, or an empty array
    ///   if no payments are stored.
    /// - Throws: A `DecodingError` if the stored data cannot be JSON-decoded.
    public func dequeueAll() async throws -> [Payment] {
        try loadAll()
    }

    /// Replaces the stored entry for a payment matched by its ``Payment/id``.
    ///
    /// If no entry with the matching `id` is found, the call is a no-op.
    ///
    /// - Parameter payment: The updated ``Payment`` to persist.
    /// - Throws: An encoding or decoding error if serialization fails.
    public func update(_ payment: Payment) async throws {
        var payments = try loadAll()
        guard let index = payments.firstIndex(where: { $0.id == payment.id }) else { return }
        payments[index] = payment
        try save(payments)
    }

    /// Removes the payment with the given identifier from the queue.
    ///
    /// If no entry with the matching `id` is found, the call is a no-op.
    ///
    /// - Parameter id: The ``Payment/id`` of the entry to delete.
    /// - Throws: An encoding or decoding error if serialization fails.
    public func remove(id: UUID) async throws {
        var payments = try loadAll()
        payments.removeAll { $0.id == id }
        try save(payments)
    }

    // MARK: - Private Helpers

    /// Reads and decodes the payment array from `UserDefaults`.
    ///
    /// - Returns: The decoded `[Payment]`, or an empty array if no data is stored.
    /// - Throws: A `DecodingError` if stored data is present but cannot be decoded.
    private func loadAll() throws -> [Payment] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([Payment].self, from: data)
    }

    /// Encodes the payment array and writes it to `UserDefaults`.
    ///
    /// - Parameter payments: The array of ``Payment`` to persist.
    /// - Throws: An `EncodingError` if the array cannot be JSON-encoded.
    private func save(_ payments: [Payment]) throws {
        let data = try JSONEncoder().encode(payments)
        defaults.set(data, forKey: key)
    }
}
