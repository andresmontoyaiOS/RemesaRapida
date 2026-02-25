import Foundation

public protocol PaymentQueueProtocol: Sendable {
    func enqueue(_ payment: Payment) async throws
    func dequeueAll() async throws -> [Payment]
    func update(_ payment: Payment) async throws
    func remove(id: UUID) async throws
}
