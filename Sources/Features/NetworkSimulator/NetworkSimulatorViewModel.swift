import Foundation
import Observation
import YunoChallengeSDK

@Observable
@MainActor
final class NetworkSimulatorViewModel {
    var isSimulatingOffline = false
    var statusMessage = "Conectado"
    private var monitor: SystemNetworkMonitor?

    func configure(monitor: SystemNetworkMonitor) {
        self.monitor = monitor
    }

    func toggleOffline() async {
        isSimulatingOffline.toggle()
        await monitor?.setConnected(!isSimulatingOffline)
        statusMessage = isSimulatingOffline ? "Simulando Sin Conexion" : "Conectado"
    }
}
