import Foundation

/// An actor-isolated store that tracks which payment idempotency keys have already
/// been successfully submitted to the API.
///
/// `IdempotencyManager` prevents duplicate API calls for the same ``Payment`` when
/// the app retries after a crash, restart, or connectivity interruption. Once a key
/// is recorded via ``markSubmitted(key:)``, any subsequent attempt to submit a payment
/// carrying the same ``Payment/idempotencyKey`` is short-circuited inside
/// ``PaymentSyncService`` and resolved locally as ``PaymentStatus/approved`` without
/// a network round-trip.
///
/// Submitted keys are persisted to `UserDefaults.standard` so that the idempotency
/// guarantee survives process restarts.
///
/// ```swift
/// let manager = IdempotencyManager()
/// let key = UUID()
///
/// await manager.markSubmitted(key: key)
/// let isDuplicate = await manager.hasBeenSubmitted(key: key) // true
/// ```
///
/// ## Topics
/// ### Related Types
/// - ``PaymentSyncService``
/// - ``Payment``
public actor IdempotencyManager {

    // MARK: - Properties

    /// The `UserDefaults` key under which the set of submitted keys is persisted.
    private let defaultsKey = "com.yunochallengesdk.idempotency"

    /// The in-memory set of idempotency keys that have been successfully submitted.
    private var submittedKeys: Set<UUID>

    // MARK: - Lifecycle

    /// Creates an `IdempotencyManager` and restores any previously submitted keys
    /// from `UserDefaults.standard`.
    ///
    /// If the stored data is absent or cannot be decoded, the manager starts with an
    /// empty set — effectively resetting idempotency tracking for new installations
    /// or after data corruption.
    public init() {
        if let data = UserDefaults.standard.data(forKey: "com.yunochallengesdk.idempotency"),
           let keys = try? JSONDecoder().decode([UUID].self, from: data) {
            submittedKeys = Set(keys)
        } else {
            submittedKeys = []
        }
    }

    // MARK: - Public API

    /// Returns `true` if the given idempotency key has previously been marked as submitted.
    ///
    /// - Parameter key: The ``Payment/idempotencyKey`` to check.
    /// - Returns: `true` if the key is present in the submitted-keys store; `false` otherwise.
    public func hasBeenSubmitted(key: UUID) -> Bool {
        submittedKeys.contains(key)
    }

    /// Records an idempotency key as having been successfully submitted and persists
    /// the updated set to `UserDefaults`.
    ///
    /// If encoding fails, the in-memory set is still updated for the duration of the
    /// current process, but the key will not survive a restart.
    ///
    /// - Parameter key: The ``Payment/idempotencyKey`` to mark as submitted.
    public func markSubmitted(key: UUID) {
        submittedKeys.insert(key)
        let array = Array(submittedKeys)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
