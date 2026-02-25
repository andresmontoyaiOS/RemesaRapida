# RemesaRapida - Resilient Bill Payment Demo

RemesaRapida is an iOS demo application that showcases an **offline-first, resilient bill payment pipeline** built on top of the embedded `YunoChallengeSDK` Swift Package. Users can submit utility bill payments at any time — even without a network connection. The SDK queues payments locally, monitors connectivity, and automatically processes the queue the moment the device comes back online, applying exponential-backoff retry logic and idempotency enforcement to prevent duplicate submissions.

---

## Architecture

The project is divided into two layers: an **App layer** (the Xcode target) and an **SDK layer** (a local Swift Package). The SDK has no dependency on UIKit or SwiftUI and can be independently compiled and tested.

### Layer Diagram

```
┌──────────────────────────────────────────────────────────┐
│                      App Layer                           │
│                                                          │
│   RemesaRapidaApp (@main)  ──►  AppContainer             │
│        (entry point, env injection)   (DI root)          │
└───────────────────────────┬──────────────────────────────┘
                            │ imports / configures
┌───────────────────────────▼──────────────────────────────┐
│                    Features Layer                        │
│                                                          │
│  Dashboard          Submission          NetworkSimulator  │
│  ┌──────────┐      ┌──────────┐        ┌──────────────┐  │
│  │ Dashboard│      │Submission│        │  Simulator   │  │
│  │  View    │      │  View    │        │    View      │  │
│  │    +     │      │    +     │        │      +       │  │
│  │  VM      │      │   VM     │        │     VM       │  │
│  └────┬─────┘      └────┬─────┘        └──────┬───────┘  │
└───────┼─────────────────┼────────────────────┼───────────┘
        │                 │                    │
        │    reads sdk.payments                │ setConnected()
        │                 │ submitPayment()    │
┌───────▼─────────────────▼────────────────────▼───────────┐
│                   YunoChallengeSDK Layer                 │
│                                                          │
│   YunoChallengeSDK (ObservableObject, @MainActor)        │
│        └──► PaymentSyncService (@MainActor)              │
│                  ├──► IdempotencyManager (actor)         │
│                  └──► RetryPolicy (struct, stateless)    │
└───────────────────────┬──────────────────────────────────┘
                        │ protocol abstractions
┌───────────────────────▼──────────────────────────────────┐
│                     Data Layer                           │
│                                                          │
│  LocalPaymentQueue   MockPaymentAPI   SystemNetworkMonitor│
│  (actor, UserDefaults)  (struct, sim)   (actor, NWPath)  │
└──────────────────────────────────────────────────────────┘
```

### Data Flow

```
User submits payment
  │
  ▼
PaymentSubmissionViewModel.submit()
  │  constructs PaymentRequest
  ▼
YunoChallengeSDK.submitPayment(_:)
  │  validates SDK is configured
  ▼
PaymentSyncService.submit(_:)
  │  wraps request in Payment (id + idempotencyKey generated)
  ▼
LocalPaymentQueue.enqueue(_:)          ← payment persisted (status: .queued)
  │
  ├─ [offline] ─► waiting...
  │                  │
  │        SystemNetworkMonitor detects connectivity restored
  │                  │
  │        connectionUpdates stream emits true
  │                  │
  └─ [online] ─► PaymentSyncService.processQueue()
                     │  filters .queued and .failed payments
                     ▼
               IdempotencyManager.hasBeenSubmitted(key:)
                     │  skip if already approved (crash-safe)
                     ▼
               PaymentSyncService.submitWithRetry(_:)
                     │  status → .processing
                     ▼
               PaymentAPIProtocol.submit(_:)
                     │
                     ├─ success ─► status = .approved / .declined
                     │             idempotencyKey marked
                     │
                     └─ URLError ─► RetryPolicy.decide(error:attempt:)
                                         │
                                         ├─ .retry(delay:) ─► exponential backoff
                                         │                     retry up to maxAttempts
                                         │
                                         └─ .permanentFailure ─► status = .failed
                     │
                     ▼
               LocalPaymentQueue.update(_:)    ← new status persisted
                     │
                     ▼
               onPaymentsUpdated callback
                     │
                     ▼
               YunoChallengeSDK.payments (@Published) updated
                     │
                     ▼
               PaymentDashboardView re-renders automatically
```

---

## Features

- **Offline-first queuing** — payments submitted without connectivity are persisted in `UserDefaults` and survive app restarts.
- **Automatic queue drain** — `PaymentSyncService` listens to `SystemNetworkMonitor.connectionUpdates` and processes the queue whenever the device comes online.
- **Exponential backoff retry** — transient `URLError` failures (timeout, no connection, connection lost, bad server response) are retried up to 3 times with delays of 1 s, 2 s, and 4 s.
- **Idempotency enforcement** — each payment carries a unique `idempotencyKey`. Once an approved key is recorded by `IdempotencyManager`, any retry resolves locally without a network call.
- **Network simulator** — `NetworkSimulatorView` lets developers toggle simulated offline/online state at runtime without requiring a real network change.
- **Deterministic mock API** — `MockPaymentAPI` derives outcomes from a hash of the bill reference, producing reproducible approved / declined / timeout / server-error scenarios across test runs.

---

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 6.0 (strict concurrency enabled in the SDK target)

---

## Setup

1. Clone the repository.
2. Open `RemesaRapidaApp.xcodeproj` in Xcode 16 or later.
3. Select the `RemesaRapidaApp` scheme.
4. Press **Command-R** to build and run on the simulator or a physical device.
5. Press **Command-U** to run the full test suite.

No API keys, environment variables, or external services are required. The project runs entirely with the embedded `MockPaymentAPI`.

---

## Project Structure

```
RemesaRapida/
├── Sources/
│   ├── App/
│   │   ├── AppContainer.swift               # Composition root — wires SDK dependencies
│   │   └── RemesaRapidaApp.swift            # @main entry point, environment injection
│   └── Features/
│       ├── Dashboard/
│       │   ├── PaymentDashboardView.swift    # Root view: payment list + summary
│       │   └── PaymentDashboardViewModel.swift  # @Observable: pendingCount, approvedTotal
│       ├── Submission/
│       │   ├── PaymentSubmissionView.swift   # Modal form for submitting a payment
│       │   └── PaymentSubmissionViewModel.swift # @Observable: form state, validation, submit
│       └── NetworkSimulator/
│           ├── NetworkSimulatorView.swift    # Developer tool: offline/online toggle
│           └── NetworkSimulatorViewModel.swift  # @Observable: isSimulatingOffline, statusMessage
│
├── Tests/
│   ├── IdempotencyManagerTests.swift         # 3 tests: mark/detect, key independence, parameterized
│   ├── LocalPaymentQueueTests.swift          # 4 tests: enqueue/dequeue, update, remove, empty
│   ├── PaymentDashboardViewModelTests.swift  # 5 tests: pending count, approved total, RetryPolicy
│   └── PaymentSyncServiceTests.swift         # 4 tests: offline queue, timeout retry, declined, idempotency
│
├── YunoChallengeSDK/
│   ├── Package.swift                         # Swift 6, iOS 17+, single library product
│   └── Sources/YunoChallengeSDK/
│       ├── YunoChallengeSDK.swift            # Public entry point (ObservableObject singleton)
│       ├── Models/
│       │   ├── BillType.swift                # Enum: electricity, water, phone, internet
│       │   ├── Payment.swift                 # Core entity: id, idempotencyKey, status, retryCount
│       │   ├── PaymentRequest.swift          # Value type: billType, billReference, amount, currency
│       │   └── PaymentStatus.swift           # Enum: queued, processing, approved, declined, failed
│       ├── Protocols/
│       │   ├── NetworkMonitorProtocol.swift  # isConnected, connectionUpdates stream
│       │   ├── PaymentAPIProtocol.swift      # submit(_:) -> PaymentStatus
│       │   └── PaymentQueueProtocol.swift    # enqueue, dequeueAll, update, remove
│       ├── Services/
│       │   ├── IdempotencyManager.swift      # Actor: tracks submitted idempotency keys
│       │   ├── PaymentSyncService.swift      # @MainActor: orchestrates queue, retry, idempotency
│       │   └── RetryPolicy.swift             # Stateless: exponential backoff decision
│       └── Data/
│           ├── LocalPaymentQueue.swift       # Actor: UserDefaults-backed persistent queue
│           ├── MockPaymentAPI.swift          # Struct: deterministic simulated API
│           └── SystemNetworkMonitor.swift    # Actor: NWPathMonitor-backed reachability
│
└── README.md
```

---

## How to Build and Test

```bash
# Build and run on iPhone 16 simulator
open RemesaRapidaApp.xcodeproj
# Press Command-R in Xcode

# Run the full test suite from the command line
xcodebuild test \
  -scheme RemesaRapidaApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a specific test suite
xcodebuild test \
  -scheme RemesaRapidaApp \
  -only-testing:RemesaRapidaTests/PaymentSyncServiceTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| YunoChallengeSDK as a local Swift Package | Provides clean separation of concerns: the SDK has no UIKit/SwiftUI dependency, compiles independently, and can be extracted into a standalone package or distributed via Swift Package Index without changes. |
| `@MainActor` on `YunoChallengeSDK` and `PaymentSyncService` | Guarantees that `@Published var payments` is always mutated on the main actor, satisfying SwiftUI's requirement for main-thread updates without manual `DispatchQueue.main` hops. |
| Actor-based `LocalPaymentQueue` and `IdempotencyManager` | Swift 6 strict concurrency eliminates data races at compile time. Actors serialize all queue mutations without explicit locking, making the code correct-by-construction. |
| Exponential backoff retry via `RetryPolicy` | Transient infrastructure failures (timeouts, connection drops, server errors) are retried with delays of 1 s, 2 s, and 4 s before a payment is permanently failed. Business rejections (non-`URLError`) are never retried. |
| `MockPaymentAPI` with hash-based determinism | The hash of `billReference` maps to a fixed outcome bucket, so the same reference always produces the same API response. This makes tests reproducible and lets developers predict behavior by choosing a specific reference string. |
| `SystemNetworkMonitor.setConnected(_:)` as a debug API | Exposes a controlled injection point for synthetic connectivity events. `NetworkSimulatorView` uses this to exercise the offline queuing and reconnection paths without requiring a physical network change or swapping the monitor implementation in tests. |
| `@Observable` on app-layer view models (not `ObservableObject`) | The `@Observable` macro (iOS 17+) provides fine-grained property observation: only the specific properties read by a view body trigger a re-render, reducing unnecessary work compared to `ObservableObject` + `@Published`. |
| Lazy view model initialization in `.onAppear` | View models that depend on `@EnvironmentObject` (e.g. the SDK) cannot be initialized as `@State` at struct creation time because the environment is not yet available. `.onAppear` guarantees the environment is injected before the view model is constructed. |

---

## Testing

The test suite uses **Swift Testing** (`import Testing`), the native testing framework introduced in Xcode 16. Key conventions:

| Annotation | Purpose |
|---|---|
| `@Suite("Name")` | Groups related tests under a named suite visible in the Xcode test navigator. |
| `@Test("description")` | Marks an individual test function. The string is the human-readable test name. |
| `#expect(expression)` | Asserts that an expression is `true`. Failures include the source expression in the report. |
| `try #require(expression)` | Like `#expect`, but throws if the expression is `nil` or `false`, stopping the test immediately. |
| `@Test("desc", arguments: [...])` | Parameterized test — the test function runs once per element in the arguments array. |
| `Issue.record("message")` | Records a test failure with a custom message without stopping execution. |

Tests use isolated `UserDefaults` suites (`UserDefaults(suiteName: UUID().uuidString)`) to prevent cross-test state pollution when exercising `LocalPaymentQueue`. Protocol-based mock types (`MockQueue`, `AlwaysApprovedAPI`, `MockNetworkMonitor`, etc.) are defined inline in `PaymentSyncServiceTests.swift` to keep the test dependencies explicit and self-contained.

---

## Dependencies

The project has **no third-party dependencies**. All functionality is implemented using Apple SDK frameworks:

| Framework | Used by |
|---|---|
| `Foundation` | All targets — `UUID`, `Date`, `Decimal`, `UserDefaults`, `JSONEncoder/Decoder` |
| `Network` | `SystemNetworkMonitor` — `NWPathMonitor` for OS-level reachability |
| `Combine` | `YunoChallengeSDK` — `ObservableObject` conformance for `@Published` |
| `Observation` | App-layer view models — `@Observable` macro |
| `SwiftUI` | All app-layer views |
| `Testing` | Test suite — `@Suite`, `@Test`, `#expect` |
