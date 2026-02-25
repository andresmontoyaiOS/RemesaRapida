import Foundation
import YunoChallengeSDK

/// The composition root for the RemesaRapida application.
///
/// `AppContainer` creates and wires together the concrete infrastructure
/// dependencies required by the SDK, then calls
/// `YunoChallengeSDK.shared.configure(queue:api:monitor:)` to activate the
/// offline-capable payment pipeline.
///
/// It is instantiated once as a `@State` property on `RemesaRapidaApp` and its
/// lifetime is bound to the app process. Both the SDK singleton and the
/// `SystemNetworkMonitor` are exposed so that child views can access them via the
/// SwiftUI environment.
///
/// ### Dependency graph
/// ```
/// AppContainer
///   ├─ YunoChallengeSDK.shared  (configured with ↓)
///   │    ├─ LocalPaymentQueue   (UserDefaults-backed persistence)
///   │    ├─ MockPaymentAPI      (deterministic simulated API)
///   │    └─ SystemNetworkMonitor (NWPathMonitor-backed reachability)
///   └─ networkMonitor           (same instance, exposed for NetworkSimulatorView)
/// ```
@MainActor
final class AppContainer {

    // MARK: - Properties

    /// The configured SDK singleton. Injected into the view hierarchy as an
    /// `EnvironmentObject` so all views can call `sdk.submitPayment(_:)` and
    /// observe `sdk.payments`.
    let sdk: YunoChallengeSDK

    /// The shared `SystemNetworkMonitor` instance. Exposed separately so that
    /// `NetworkSimulatorView` can call `setConnected(_:)` to simulate
    /// offline/online transitions without going through the SDK public API.
    let networkMonitor: SystemNetworkMonitor

    // MARK: - Lifecycle

    /// Creates the application container, wires all dependencies, and starts the SDK.
    init() {
        let monitor = SystemNetworkMonitor()
        self.networkMonitor = monitor
        self.sdk = YunoChallengeSDK.shared
        sdk.configure(
            queue: LocalPaymentQueue(),
            api: MockPaymentAPI(),
            monitor: monitor
        )
    }
}
