import Foundation
import Observation
import YunoChallengeSDK

/// The view model for `NetworkSimulatorView`, managing the simulated connectivity toggle
/// and status display string.
///
/// `NetworkSimulatorViewModel` holds an optional reference to the shared
/// `SystemNetworkMonitor`. The monitor is injected after the view appears (via
/// ``configure(monitor:)``), because the `@Environment` value is only available
/// at render time, not during view model initialization.
///
/// When the user flips the toggle, ``toggleOffline()`` inverts the simulated
/// state and calls `SystemNetworkMonitor.setConnected(_:)`, which broadcasts the
/// change through ``NetworkMonitorProtocol/connectionUpdates`` and triggers
/// `PaymentSyncService.processQueue()` if connectivity is restored.
///
/// ## Topics
/// ### Related Views
/// - `NetworkSimulatorView`
/// ### Related SDK Types
/// - ``SystemNetworkMonitor``
@Observable
@MainActor
final class NetworkSimulatorViewModel {

    // MARK: - Properties

    /// Indicates whether the offline simulation mode is currently active.
    ///
    /// `true` means the app behaves as if there is no network connection.
    var isSimulatingOffline = false

    /// A human-readable description of the current simulated network state.
    ///
    /// Displayed in the `NetworkSimulatorView` form row alongside the toggle.
    var statusMessage = "Conectado"

    /// The network monitor whose connectivity state is overridden by the simulator.
    ///
    /// Set via ``configure(monitor:)`` once the `@Environment` value is available.
    private var monitor: SystemNetworkMonitor?

    // MARK: - Public API

    /// Injects the `SystemNetworkMonitor` instance used to broadcast connectivity events.
    ///
    /// - Parameter monitor: The same `SystemNetworkMonitor` passed to the SDK at startup.
    func configure(monitor: SystemNetworkMonitor) {
        self.monitor = monitor
    }

    /// Toggles the simulated connectivity state and broadcasts the change to the SDK.
    ///
    /// Flips ``isSimulatingOffline``, calls `SystemNetworkMonitor.setConnected(_:)`
    /// with the inverse value, and updates ``statusMessage`` to reflect the new state.
    ///
    /// If no monitor has been configured yet, the call is a no-op.
    func toggleOffline() async {
        isSimulatingOffline.toggle()
        await monitor?.setConnected(!isSimulatingOffline)
        statusMessage = isSimulatingOffline ? "Simulando Sin Conexion" : "Conectado"
    }
}
