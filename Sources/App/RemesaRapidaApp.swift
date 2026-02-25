import SwiftUI
import YunoChallengeSDK

@main
struct RemesaRapidaApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            PaymentDashboardView()
                .environmentObject(container.sdk)
                .environment(\.networkMonitor, container.networkMonitor)
        }
    }
}

private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: SystemNetworkMonitor? = nil
}

extension EnvironmentValues {
    var networkMonitor: SystemNetworkMonitor? {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}
