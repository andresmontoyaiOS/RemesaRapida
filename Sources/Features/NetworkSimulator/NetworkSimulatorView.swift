import SwiftUI
import YunoChallengeSDK

struct NetworkSimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.networkMonitor) private var monitor
    @State private var viewModel = NetworkSimulatorViewModel()

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
