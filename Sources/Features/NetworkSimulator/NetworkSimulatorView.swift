import SwiftUI
import YunoChallengeSDK

/// A developer tool that allows manual toggling of simulated network connectivity.
///
/// `NetworkSimulatorView` is presented as a modal sheet from `PaymentDashboardView`
/// when the antenna toolbar button is tapped. It surfaces a single toggle that
/// calls `SystemNetworkMonitor.setConnected(_:)` to inject synthetic connectivity
/// events into the SDK pipeline — no actual network changes are required.
///
/// ### Effect on the SDK
/// - Setting the toggle to **offline** causes `SystemNetworkMonitor` to broadcast
///   `false` on its `connectionUpdates` stream. New payments submitted while offline
///   are queued locally.
/// - Setting the toggle back to **online** broadcasts `true`, which triggers
///   `PaymentSyncService.processQueue()` and submits any queued payments.
///
/// The `SystemNetworkMonitor` instance is received via the custom
/// `\.networkMonitor` `EnvironmentKey` set by `RemesaRapidaApp`.
struct NetworkSimulatorView: View {

    // MARK: - Properties

    /// SwiftUI dismiss action used to close the sheet when the user taps "Listo".
    @Environment(\.dismiss) private var dismiss

    /// The shared `SystemNetworkMonitor`, provided via the custom environment key.
    ///
    /// `nil` if the view is previewed or instantiated outside the normal app hierarchy.
    @Environment(\.networkMonitor) private var monitor

    /// The view model managing toggle state and status message.
    @State private var viewModel = NetworkSimulatorViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Estado de Red") {
                    HStack {
                        Label(
                            viewModel.statusMessage,
                            systemImage: viewModel.isSimulatingOffline ? "wifi.slash" : "wifi"
                        )
                        .foregroundStyle(viewModel.isSimulatingOffline ? .red : .green)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isSimulatingOffline },
                            set: { _ in Task { await viewModel.toggleOffline() } }
                        ))
                    }
                }
                Section("Informacion") {
                    Text("Activa el modo offline para probar el comportamiento de cola. Los pagos enviados sin conexion se procesaran automaticamente al restaurar la conectividad.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Simulador de Red")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .onAppear {
            if let monitor { viewModel.configure(monitor: monitor) }
        }
    }
}
