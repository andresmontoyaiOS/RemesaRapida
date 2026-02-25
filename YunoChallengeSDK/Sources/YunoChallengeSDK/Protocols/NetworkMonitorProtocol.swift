import Foundation

public protocol NetworkMonitorProtocol: Sendable {
    var isConnected: Bool { get async }
    var connectionUpdates: AsyncStream<Bool> { get }
}
