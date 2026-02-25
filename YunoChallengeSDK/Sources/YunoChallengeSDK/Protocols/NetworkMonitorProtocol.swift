import Foundation

/// Defines the interface for observing network reachability.
///
/// Conforming types must be `Sendable` so they can be safely passed across
/// Swift concurrency boundaries. The SDK ships ``SystemNetworkMonitor`` as the
/// production implementation and accepts custom conformances for testing.
///
/// ``PaymentSyncService`` consumes this protocol to decide whether to attempt
/// immediate submission or to defer until connectivity is restored.
///
/// ## Example — custom test double
/// ```swift
/// actor MockNetworkMonitor: NetworkMonitorProtocol {
///     var isConnected: Bool = true
///     var connectionUpdates: AsyncStream<Bool> { ... }
/// }
/// ```
///
/// ## Topics
/// ### Implementations
/// - ``SystemNetworkMonitor``
public protocol NetworkMonitorProtocol: Sendable {

    /// The current reachability state of the device.
    ///
    /// Accessing this property is `async` because implementations such as
    /// ``SystemNetworkMonitor`` are `actor`-isolated and must be awaited.
    var isConnected: Bool { get async }

    /// An infinite `AsyncStream` that emits a `Bool` every time connectivity changes.
    ///
    /// A value of `true` signals that the network is reachable; `false` signals
    /// that it is not. ``PaymentSyncService/start()`` subscribes to this stream
    /// and calls ``PaymentSyncService/processQueue()`` on each `true` event.
    var connectionUpdates: AsyncStream<Bool> { get }
}
