Your job is to create a public GitHub repository for the RemesaRapida project and keep it in sync as files are created by other agents.

## Step 1: Check GitHub auth
Run: gh auth status
If not authenticated, run: gh auth login

## Step 2: Initialize git and create .gitignore
Run these commands:
cd ~/Projects/RemesaRapida
git init
cat > .gitignore << 'EOF'
.DS_Store
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
build/
DerivedData/
.build/
*.o
*.d
.swiftpm/
xcuserdata/
*.xccheckout
*.moved-aside
*.orig
EOF

## Step 3: Create the public GitHub repo
Run: gh repo create RemesaRapida --public --description "Offline-first iOS bill payment app with YunoChallengeSDK — idempotency, retry logic, NWPathMonitor, Swift 6" --source=. --remote=origin

## Step 4: Initial commit with whatever files exist now
Run:
git add .
git commit -m "feat: initial project scaffold

YunoChallengeSDK Swift Package + RemesaRapidaApp demo
- Offline-first payment queue with idempotency
- Exponential backoff retry (3 attempts)
- NWPathMonitor network monitoring
- Swift 6 strict concurrency"

git push -u origin main

## Step 5: Poll and push new files every 60 seconds
After the initial push, enter a loop:
- Every 60 seconds, run: git status
- If there are new/modified files: git add . && git commit -m "chore: sync project files from agents" && git push
- Continue until you see RemesaRapidaApp.xcodeproj exists (that means the creator is done)

## Step 6: Final commit when project is complete
When you detect RemesaRapidaApp.xcodeproj exists AND README.md exists:
git add .
git commit -m "feat: complete RemesaRapida implementation

- YunoChallengeSDK: LocalPaymentQueue, MockPaymentAPI (15 scenarios), SystemNetworkMonitor
- PaymentSyncService: offline queuing + retry + idempotency
- SwiftUI app: Dashboard, Submission form, NetworkSimulator debug panel
- Tests: PaymentSyncServiceTests, IdempotencyManagerTests, LocalPaymentQueueTests, PaymentDashboardViewModelTests
- README with architecture diagram and ADRs"

git push

Then print the repo URL.
