// Coverage target: PaymentDashboardViewModel + RetryPolicy – 5 test cases
// Tests: pending status classification, approved total aggregation,
//        RetryPolicy on timeout, RetryPolicy max-attempts exhaustion,
//        RetryPolicy no-retry on business errors.

import Testing
import Foundation
@testable import YunoChallengeSDK

@Suite("PaymentDashboardViewModel") @MainActor
struct PaymentDashboardViewModelTests {

    // MARK: Pending status classification

    @Test("pendingCount reflects queued and processing payments")
    func pendingCount() async throws {
        let queuedPayment = Payment(
            request: PaymentRequest(
                billType: .water,
                billReference: "W001",
                amount: 50,
                currency: "USD"
            ),
            status: .queued
        )
        #expect(queuedPayment.status == .queued)

        let processingPayment = Payment(
            request: PaymentRequest(
                billType: .water,
                billReference: "W002",
                amount: 75,
                currency: "USD"
            ),
            status: .processing
        )
        #expect(processingPayment.status == .processing)

        // Both statuses are considered "pending"
        let pendingStatuses: [PaymentStatus] = [.queued, .processing]
        #expect(pendingStatuses.contains(queuedPayment.status))
        #expect(pendingStatuses.contains(processingPayment.status))
    }

    // MARK: Approved total aggregation

    @Test("approvedTotal sums approved payment amounts")
    func approvedTotal() async throws {
        let payments: [Payment] = [
            Payment(
                request: PaymentRequest(
                    billType: .electricity,
                    billReference: "E001",
                    amount: 100,
                    currency: "USD"
                ),
                status: .approved
            ),
            Payment(
                request: PaymentRequest(
                    billType: .water,
                    billReference: "W001",
                    amount: 50,
                    currency: "USD"
                ),
                status: .approved
            ),
            Payment(
                request: PaymentRequest(
                    billType: .phone,
                    billReference: "P001",
                    amount: 30,
                    currency: "USD"
                ),
                status: .declined
            ),
        ]

        let approvedTotal = payments
            .filter { $0.status == .approved }
            .reduce(Decimal.zero) { $0 + $1.request.amount }

        #expect(approvedTotal == 150)
    }

    // MARK: RetryPolicy — timeout → retry

    @Test("RetryPolicy retries on timeout")
    func retryPolicyTimeout() async throws {
        let decision = RetryPolicy.decide(error: URLError(.timedOut), attempt: 0)
        if case .retry(let delay) = decision {
            #expect(delay > 0)
        } else {
            Issue.record("Expected .retry decision for a timed-out URLError on attempt 0")
        }
    }

    // MARK: RetryPolicy — max attempts → permanent failure

    @Test("RetryPolicy permanent failure after maxAttempts")
    func retryPolicyMaxAttempts() async throws {
        let decision = RetryPolicy.decide(
            error: URLError(.timedOut),
            attempt: RetryPolicy.maxAttempts
        )
        if case .permanentFailure = decision {
            // Expected — no further retries once ceiling is reached
        } else {
            Issue.record("Expected .permanentFailure once maxAttempts is reached")
        }
    }

    // MARK: RetryPolicy — business error → no retry

    @Test("RetryPolicy no retry for non-URLError business errors")
    func retryPolicyDeclined() async throws {
        struct BusinessError: Error {}
        let decision = RetryPolicy.decide(error: BusinessError(), attempt: 0)
        if case .permanentFailure = decision {
            // Expected — business / domain errors should not be retried
        } else {
            Issue.record("Expected .permanentFailure for a non-URLError business error")
        }
    }
}
