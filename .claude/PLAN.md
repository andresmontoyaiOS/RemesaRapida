# RemesaRapida App + YunoChallengeSDK — Implementation Plan

## Context

RemesaRápida needs a resilient iOS payment component for offline-capable bill payments. The challenge requires two interconnected pieces:
1. **YunoChallengeSDK** — a reusable Swift Package that handles offline queuing, idempotency, retry logic, and network monitoring
2. **RemesaRapidaApp** — a SwiftUI demo app that integrates the SDK and demonstrates all features

---

## Project Layout

```
~/Projects/RemesaRapida/
├── YunoChallengeSDK/                   ← Swift Package (the SDK)
│   ├── Package.swift
│   └── Sources/YunoChallengeSDK/
│       ├── Models/
│       │   ├── Payment.swift
│       │   ├── PaymentStatus.swift
│       │   ├── PaymentRequest.swift
│       │   └── BillType.swift
│       ├── Protocols/
│       │   ├── PaymentQueueProtocol.swift
│       │   ├── PaymentAPIProtocol.swift
│       │   └── NetworkMonitorProtocol.swift
│       ├── Data/
│       │   ├── LocalPaymentQueue.swift
│       │   ├── MockPaymentAPI.swift
│       │   └── SystemNetworkMonitor.swift
│       ├── Services/
│       │   ├── IdempotencyManager.swift
│       │   ├── RetryPolicy.swift
│       │   └── PaymentSyncService.swift
│       └── YunoChallengeSDK.swift
│
├── project.yml
├── Sources/
│   ├── App/
│   │   ├── RemesaRapidaApp.swift
│   │   └── AppContainer.swift
│   └── Features/
│       ├── Dashboard/
│       ├── Submission/
│       └── NetworkSimulator/
├── Tests/
└── .claude/                            ← Agent prompts & skill used to build this
```

---

## Agents Used

| Agent | File | Role |
|-------|------|------|
| ios-project-creator | `.claude/agents/ios-project-creator.md` | Created all SDK + app Swift files, ran xcodegen, fixed Swift 6 errors until green build |
| ios-unit-tester | `.claude/agents/ios-unit-tester.md` | Wrote Swift Testing suites in `Tests/` |
| ios-documenter | `.claude/agents/ios-documenter.md` | Added DocC comments and README |
| github-sync | `.claude/agents/github-sync.md` | Created public GitHub repo and pushed commits |

Skill invoked: `.claude/skills/ios-project.md`

---

## SDK Key Design Decisions

### Offline-First Queue
All payments are enqueued locally (UserDefaults + JSONEncoder) before any network attempt.
Survives app restarts. Processed automatically when connectivity is restored.

### Idempotency
Each `Payment` carries a `idempotencyKey: UUID` generated at creation time.
`IdempotencyManager` (actor) persists submitted keys across launches.
A payment whose key was already submitted is immediately marked `.approved` — no API call.

### Retry Policy (RetryPolicy.swift)
- `URLError.timedOut / .notConnectedToInternet / .badServerResponse` → retry
- Exponential backoff: 1s → 2s → 4s (max 3 attempts)
- Business errors (declined, unknown) → permanent failure, no retry

### Swift 6 Strict Concurrency
- `SWIFT_STRICT_CONCURRENCY: complete` in project.yml
- All actors are self-isolated — no `@MainActor` on actor methods
- `AsyncStream` continuation stored as `nonisolated(unsafe)` in `SystemNetworkMonitor`
- All models are `Sendable` value types

---

## MockPaymentAPI Scenarios

Deterministic based on `abs(billReference.hashValue) % 11`:

| Hash | Result | Delay | Retryable |
|------|--------|-------|-----------|
| 0–6 (≈70%) | `.approved` | 0.5–3s | — |
| 7–8 (≈15%) | `.declined` | 0.2s | ❌ permanent |
| 9 (≈10%) | `URLError(.timedOut)` | 0.5s | ✅ |
| 10 (≈5%) | `URLError(.badServerResponse)` | 0.3s | ✅ |

---

## Build & Run

```bash
cd ~/Projects/RemesaRapida
xcodegen generate
xcodebuild build -scheme RemesaRapidaApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO | xcpretty
open RemesaRapidaApp.xcodeproj
```
