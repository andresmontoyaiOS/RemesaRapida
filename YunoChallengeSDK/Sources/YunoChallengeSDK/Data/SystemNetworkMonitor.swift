import Network
import Foundation

public actor SystemNetworkMonitor: NetworkMonitorProtocol {
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.yunochallengesdk.network", qos: .utility)
    private var _isConnected: Bool = true
    nonisolated(unsafe) private var _continuation: AsyncStream<Bool>.Continuation?
    public nonisolated let connectionUpdates: AsyncStream<Bool>

    public init() {
        var cont: AsyncStream<Bool>.Continuation?
        connectionUpdates = AsyncStream { cont = $0 }
        _continuation = cont
    }

    public var isConnected: Bool {
        _isConnected
    }

    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { [weak self] in
                await self?.updateConnectivity(connected)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func updateConnectivity(_ connected: Bool) {
        _isConnected = connected
        _continuation?.yield(connected)
    }

    public func setConnected(_ connected: Bool) {
        _isConnected = connected
        _continuation?.yield(connected)
    }
}
