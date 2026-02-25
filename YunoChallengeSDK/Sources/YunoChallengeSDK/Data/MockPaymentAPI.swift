import Foundation

public struct MockPaymentAPI: PaymentAPIProtocol {
    public init() {}

    public func submit(_ payment: Payment) async throws -> PaymentStatus {
        let hash = abs(payment.request.billReference.hashValue) % 11
        switch hash {
        case 0...6:
            let delay = Double.random(in: 0.5...3.0)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .approved
        case 7...8:
            try await Task.sleep(nanoseconds: 200_000_000)
            return .declined
        case 9:
            try await Task.sleep(nanoseconds: 500_000_000)
            throw URLError(.timedOut)
        default:
            try await Task.sleep(nanoseconds: 300_000_000)
            throw URLError(.badServerResponse)
        }
    }
}
