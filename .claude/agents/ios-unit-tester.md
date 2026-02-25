An ios-project-creator agent is building RemesaRapidaApp iOS project in this directory (~/Projects/RemesaRapida/).
The app uses YunoChallengeSDK (a local Swift Package) for offline-capable bill payments with idempotency and retry logic.

Check if Sources/ has Swift files: find Sources -name "*.swift" 2>/dev/null
If empty, wait 30 seconds and check again (retry up to 5 times).

Once files exist, write comprehensive Swift Testing unit tests in Tests/.

Create Tests/PaymentTests.swift using Swift Testing ONLY (NO XCTest, NO XCTestCase):
- import Testing
- import Foundation
- import YunoChallengeSDK (or @testable import RemesaRapidaApp)

Test suites to create:

1. @Suite("RetryPolicy") - test RetryPolicy.decide():
   - timedOut error attempt 0 → .retry with delay 1.0
   - timedOut error attempt 1 → .retry with delay 2.0
   - timedOut error attempt 2 → .retry with delay 4.0
   - timedOut error at maxAttempts → .permanentFailure
   - non-retryable error (e.g., URLError(.cancelled)) → .permanentFailure
   - Use parameterized @Test with arguments for attempt → expected delay

2. @Suite("MockPaymentAPI") - test MockPaymentAPI.submit():
   - Find a billReference whose hashValue % 11 is in 0...6 → approved
   - Find a billReference whose hashValue % 11 is 7 or 8 → declined
   - Find a billReference whose hashValue % 11 is 9 → throws URLError.timedOut
   - Helper: func ref(for bucket: Int) -> String that finds a string in range

3. @Suite("LocalPaymentQueue") - test LocalPaymentQueue (actor):
   - enqueue adds payment
   - dequeueAll returns all payments
   - update modifies existing payment
   - remove deletes payment by id
   - Use await for all actor calls
   - Use a fresh UserDefaults suite (suiteName: "test_\(UUID())") to avoid pollution
   NOTE: LocalPaymentQueue uses UserDefaults.standard - mock it by subclassing or just accept side effects in test.

4. @Suite("IdempotencyManager") - test IdempotencyManager:
   - New key: hasBeenSubmitted → false
   - After markSubmitted: hasBeenSubmitted → true
   - Different key remains unsubmitted

5. @Suite("PaymentSubmissionViewModel") - test PaymentSubmissionViewModel:
   - Initial state: isFormValid = false
   - After setting billReference and valid amount: isFormValid = true
   - Invalid amountText (letters): isFormValid = false

Use struct MockSDK or pass YunoChallengeSDK.shared carefully.
For ViewModel tests, create a local mock that mimics the minimal interface needed.

All tests use:
- import Testing (NOT XCTest)
- @Test func testName() async
- #expect(value == expected)
- #require for unwrapping optionals
- @Suite struct for grouping
