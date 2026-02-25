import Foundation

/// A deterministic, in-process implementation of ``PaymentAPIProtocol`` for testing
/// and demo purposes.
///
/// `MockPaymentAPI` derives an outcome from the hash of ``PaymentRequest/billReference``
/// so that the same reference always produces the same result, making behaviour
/// reproducible across runs while still exercising multiple code paths:
///
/// | Hash bucket (mod 11) | Simulated outcome | Delay |
/// |---|---|---|
/// | 0 – 6 (64%) | ``PaymentStatus/approved`` | 0.5 – 3.0 s |
/// | 7 – 8 (18%) | ``PaymentStatus/declined`` | 0.2 s |
/// | 9 (9%) | throws `URLError(.timedOut)` | 0.5 s |
/// | 10 (9%) | throws `URLError(.badServerResponse)` | 0.3 s |
///
/// The injected delays simulate real network latency and allow the UI to display
/// ``PaymentStatus/processing`` states during development.
///
/// ## Topics
/// ### Protocol Conformance
/// - ``PaymentAPIProtocol``
public struct MockPaymentAPI: PaymentAPIProtocol {

    // MARK: - Lifecycle

    /// Creates a new `MockPaymentAPI` instance.
    public init() {}

    // MARK: - Public API

    /// Simulates a remote API submission with a deterministic outcome and artificial delay.
    ///
    /// The outcome is derived from `abs(payment.request.billReference.hashValue) % 11`,
    /// so a given reference string always produces the same result.
    ///
    /// - Parameter payment: The ``Payment`` to simulate. Only ``PaymentRequest/billReference``
    ///   affects the outcome; all other fields are ignored.
    /// - Returns: ``PaymentStatus/approved`` or ``PaymentStatus/declined`` depending on the
    ///   hash bucket.
    /// - Throws: `URLError(.timedOut)` or `URLError(.badServerResponse)` to exercise
    ///   ``RetryPolicy`` timeout and server-error paths.
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
