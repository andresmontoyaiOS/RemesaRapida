import Network
import Foundation

/// A production ``NetworkMonitorProtocol`` implementation backed by `Network.framework`'s
/// `NWPathMonitor`.
///
/// `SystemNetworkMonitor` is an `actor` so that all state mutations are serialized
/// without explicit locking. It broadcasts connectivity changes as an `AsyncStream<Bool>`
/// that ``PaymentSyncService`` observes to trigger automatic queue processing.
///
/// Call ``startMonitoring()`` once after the SDK is configured to begin receiving real
/// path updates from the OS. In tests and the network simulator feature, call
/// ``setConnected(_:)`` directly to inject synthetic connectivity events without
/// requiring an actual network change.
///
/// ```swift
/// let monitor = SystemNetworkMonitor()
/// await monitor.startMonitoring()
/// // monitor.isConnected reflects the device's current reachability
///
/// // Simulate going offline in the NetworkSimulator feature:
/// await monitor.setConnected(false)
/// ```
///
/// ## Topics
/// ### Protocol Conformance
/// - ``NetworkMonitorProtocol``
public actor SystemNetworkMonitor: NetworkMonitorProtocol {

    // MARK: - Properties

    /// The underlying OS path monitor.
    private let monitor = NWPathMonitor()

    /// The dedicated dispatch queue on which `NWPathMonitor` delivers path updates.
    private let monitorQueue = DispatchQueue(label: "com.yunochallengesdk.network", qos: .utility)

    /// The cached connectivity state, updated on every path change or manual override.
    private var _isConnected: Bool = true

    /// The continuation used to push values into ``connectionUpdates``.
    ///
    /// Marked `nonisolated(unsafe)` because it is assigned once during `init` before
    /// actor isolation takes effect, then only mutated from within the actor.
    nonisolated(unsafe) private var _continuation: AsyncStream<Bool>.Continuation?

    /// An infinite stream that emits `true` when the network becomes reachable and
    /// `false` when it becomes unreachable.
    ///
    /// Consumers should iterate this stream with `for await` to react to changes.
    /// The stream runs indefinitely until the actor is deallocated.
    public nonisolated let connectionUpdates: AsyncStream<Bool>

    // MARK: - Lifecycle

    /// Creates a `SystemNetworkMonitor` and prepares the connectivity stream.
    ///
    /// Call ``startMonitoring()`` after initialization to begin receiving OS-level
    /// path updates.
    public init() {
        var cont: AsyncStream<Bool>.Continuation?
        connectionUpdates = AsyncStream { cont = $0 }
        _continuation = cont
    }

    // MARK: - Public API

    /// The current reachability state of the device.
    ///
    /// Returns the last value received from `NWPathMonitor`, or `true` as the
    /// optimistic default before monitoring has started.
    public var isConnected: Bool {
        _isConnected
    }

    /// Starts the `NWPathMonitor` and begins emitting real OS connectivity events.
    ///
    /// This method is idempotent if called more than once; subsequent calls restart
    /// the underlying monitor. It should be called once during app startup via
    /// ``PaymentSyncService/start()``.
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { [weak self] in
                await self?.updateConnectivity(connected)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    /// Overrides the connectivity state and broadcasts the new value to all observers.
    ///
    /// Use this method to simulate offline or online conditions during development or
    /// testing without requiring a real network change. The ``NetworkSimulatorView``
    /// calls this method when the user toggles the simulator.
    ///
    /// - Parameter connected: `true` to simulate reachability; `false` to simulate
    ///   no network connection.
    public func setConnected(_ connected: Bool) {
        _isConnected = connected
        _continuation?.yield(connected)
    }

    // MARK: - Private Helpers

    /// Updates the cached connectivity state and notifies stream consumers.
    ///
    /// - Parameter connected: The new reachability value received from `NWPathMonitor`.
    private func updateConnectivity(_ connected: Bool) {
        _isConnected = connected
        _continuation?.yield(connected)
    }
}
