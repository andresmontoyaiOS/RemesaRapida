import SwiftUI
import YunoChallengeSDK

/// The SwiftUI application entry point for RemesaRapida.
///
/// `RemesaRapidaApp` creates the `AppContainer` composition root as a `@State`
/// property (ensuring a single instance tied to the app's lifetime) and injects
/// the SDK and network monitor into the view hierarchy via the SwiftUI environment.
///
/// `PaymentDashboardView` is the root view. It receives:
/// - `YunoChallengeSDK` as an `EnvironmentObject` for payment submission and observation.
/// - `SystemNetworkMonitor` via the custom ``EnvironmentValues/networkMonitor`` key
///   so that `NetworkSimulatorView` can toggle simulated connectivity.
@main
struct RemesaRapidaApp: App {

    // MARK: - Properties

    /// The application-level composition root. Holds all infrastructure singletons.
    @State private var container = AppContainer()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            PaymentDashboardView()
                .environmentObject(container.sdk)
                .environment(\.networkMonitor, container.networkMonitor)
        }
    }
}

/// A private `EnvironmentKey` that propagates the `SystemNetworkMonitor` through
/// the SwiftUI view hierarchy.
///
/// Access the value using the ``EnvironmentValues/networkMonitor`` key path.
private struct NetworkMonitorKey: EnvironmentKey {
    /// The default value is `nil`; the real monitor is injected at the root by `RemesaRapidaApp`.
    static let defaultValue: SystemNetworkMonitor? = nil
}

extension EnvironmentValues {
    /// The `SystemNetworkMonitor` injected by the app root.
    ///
    /// `NetworkSimulatorView` reads this value to call `setConnected(_:)` for
    /// offline simulation. Views that do not need this value receive `nil`.
    var networkMonitor: SystemNetworkMonitor? {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}
