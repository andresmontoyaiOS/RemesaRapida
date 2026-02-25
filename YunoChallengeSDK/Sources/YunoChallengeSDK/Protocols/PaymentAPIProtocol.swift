import Foundation

public protocol PaymentAPIProtocol: Sendable {
    func submit(_ payment: Payment) async throws -> PaymentStatus
}
