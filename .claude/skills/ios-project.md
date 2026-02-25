---
name: ios-project
description: "Generates a complete iOS SwiftUI project using 3 parallel agents in tmux: ios-project-creator (Clean Architecture + xcodegen + xcpretty), ios-unit-tester (Swift Testing), and ios-documenter (DocC + README). Usage: /ios-project <ProjectName> - <description>"
---

# iOS Project Generator

Generates a production-ready iOS project using **3 agents running in parallel** inside a tmux session.

## What each agent does

| Pane | Agent | Responsibility |
|------|-------|----------------|
| Left | `ios-project-creator` | Clean Architecture + SwiftUI + xcodegen + xcpretty build verification |
| Top-right | `ios-unit-tester` | Swift Testing unit tests (`@Suite`, `@Test`, `#expect`) |
| Bottom-right | `ios-documenter` | DocC comments + README with architecture diagrams |

## How to invoke this skill

```
/ios-project <ProjectName> - <brief description of the app>
```

Examples:
```
/ios-project TaskManager - a todo app with categories and due dates
/ios-project WeatherApp - shows current weather using an API
/ios-project CounterApp - simple counter with increment and decrement
```

## Your job when this skill is invoked

Extract the **ProjectName** and **description** from the user's input, then execute ALL of the following steps:

### Step 1 — Parse input

From the user's message extract:
- `PROJECT_NAME`: the first word/phrase before ` - ` (use CamelCase, no spaces)
- `PROJECT_DESC`: everything after ` - `
- `PROJECT_DIR`: `$HOME/Projects/<ProjectName>`

### Step 2 — Create project directory

```bash
mkdir -p ~/Projects/<ProjectName>
```

### Step 3 — Launch tmux session with 3 panes

```bash
# Kill existing session with same name if any
tmux kill-session -t <ProjectName> 2>/dev/null || true

# Create session detached
tmux new-session -d -s <ProjectName> -x 220 -y 55
tmux rename-window -t "<ProjectName>:0" "<ProjectName>"

# Split into 3 panes:
# Left full height = Creator | Right top = Tester | Right bottom = Documenter
tmux split-window -h -t "<ProjectName>:0.0"
tmux split-window -v -t "<ProjectName>:0.1"
tmux select-layout -t "<ProjectName>" main-vertical

# Labels on pane borders
tmux select-pane -t "<ProjectName>:0.0" -T "🏗️  CREATOR"
tmux select-pane -t "<ProjectName>:0.1" -T "🧪 TESTER"
tmux select-pane -t "<ProjectName>:0.2" -T "📝 DOCUMENTER"
tmux set -t "<ProjectName>" pane-border-status top
tmux set -t "<ProjectName>" pane-border-format " #{pane_title} "
```

### Step 4 — Start the 3 agents in interactive mode

```bash
# All 3 agents start simultaneously
tmux send-keys -t "<ProjectName>:0.0" "cd ~/Projects/<ProjectName> && claude --agent ios-project-creator --dangerously-skip-permissions" Enter
tmux send-keys -t "<ProjectName>:0.1" "cd ~/Projects/<ProjectName> && claude --agent ios-unit-tester --dangerously-skip-permissions" Enter
tmux send-keys -t "<ProjectName>:0.2" "cd ~/Projects/<ProjectName> && claude --agent ios-documenter --dangerously-skip-permissions" Enter
```

Wait 8 seconds for claude to initialize in all panes, then confirm the workspace trust dialog by sending Enter to each pane.

### Step 5 — Send prompts to each agent via tmux buffers

Write each prompt to a temp file, then load and paste it.

**CREATOR prompt** (send to pane 0):
```
Create a complete iOS SwiftUI project called <ProjectName> in the current directory.
App description: <PROJECT_DESC>

Architecture: Clean Architecture + Observable MVVM (iOS 17+).

MANDATORY STEPS IN ORDER:
1. brew install xcodegen (if missing)
2. Create project.yml — iOS 17 app target (sources: Sources/), test target (sources: Tests/), Swift 6, SWIFT_STRICT_CONCURRENCY=complete
3. Create Sources/Info.plist
4. Create Resources/Assets.xcassets with AccentColor.colorset and AppIcon.appiconset (with Contents.json in each)
5. Create ALL Swift source files under Sources/ using Clean Architecture:
   - Sources/App/<ProjectName>App.swift (@main, injects AppContainer via .environment)
   - Sources/App/AppContainer.swift (DI composition root, builds all ViewModels)
   - Sources/Features/<MainFeature>/Domain/<Entity>.swift (value type, Equatable, Sendable)
   - Sources/Features/<MainFeature>/Domain/<Entity>UseCase.swift (protocol + DefaultImpl)
   - Sources/Features/<MainFeature>/Presentation/<Feature>ViewModel.swift (@Observable @MainActor)
   - Sources/Features/<MainFeature>/Presentation/<Feature>View.swift (SwiftUI, @Environment ViewModel)
6. Run: xcodegen generate
7. Compile: xcodebuild build -scheme <ProjectName> -destination "id=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; iphones=[v for k,vs in d.items() if 'iOS' in k for v in vs if 'iPhone' in v['name'] and v['isAvailable']]; print(iphones[0]['udid'] if iphones else '')" ) CODE_SIGNING_ALLOWED=NO | xcpretty
8. If build fails → read xcpretty errors → fix Swift files → re-run xcodebuild until green
9. Once build passes → open <ProjectName>.xcodeproj

Swift 6 strict concurrency. No force unwraps. DocC comments (///) on every public type and method.
```

**TESTER prompt** (send to pane 1):
```
An ios-project-creator agent is building <ProjectName> iOS project in this directory.
Check if Sources/ has Swift files: find Sources -name "*.swift" 2>/dev/null
If empty, wait 20 seconds and check again (retry up to 3 times).

Once files exist, write Swift Testing unit tests:
- Create Tests/<MainFeature>Tests.swift
- Use Swift Testing ONLY: import Testing, @Suite @MainActor, @Test, #expect, #require
- Test the ViewModel: initial state, main action increments/changes state, edge cases
- Test the UseCase: happy path, returns correct value, does not mutate input
- Create a Mock<UseCase> as an inner struct conforming to the use-case protocol
- Add parameterized @Test with arguments: for multiple input values
- NO XCTest, NO XCTestCase
```

**DOCUMENTER prompt** (send to pane 2):
```
An ios-project-creator agent is building <ProjectName> iOS project in this directory.
Check if Sources/ has Swift files: find Sources -name "*.swift" 2>/dev/null
If empty, wait 20 seconds and check again (retry up to 3 times).

Once files exist, generate documentation:
1. Edit each Swift file in Sources/ in place to add:
   - DocC comments (///) on every type, property, and method
   - // MARK: - sections (Properties, Lifecycle, Public API, Private Helpers)
2. Create README.md with:
   - App description and purpose
   - ASCII architecture diagram (4 layers: App, Presentation, Domain, Model)
   - Data flow diagram with → arrows
   - Complete file tree
   - How to build and run in Xcode (⌘R) and run tests (⌘U)
   - Key design decisions table
```

### Step 6 — Tell the user how to connect

After launching all agents, tell the user:

```
✅ Proyecto <ProjectName> iniciado con 3 agentes en paralelo.

Conectate a tmux para ver el progreso en tiempo real:
  tmux attach-session -t <ProjectName>

Controles tmux:
  Ctrl+B ←/→/↑/↓  — moverse entre agentes
  Ctrl+B z         — zoom al pane actual
  Ctrl+B d         — desconectarte (los agentes siguen corriendo)

El proyecto se generará en: ~/Projects/<ProjectName>/
Xcode se abrirá automáticamente cuando el build sea verde ✅
```

## Important notes

- Always use `tmux load-buffer` + `tmux paste-buffer` to send prompts — never inline them in `send-keys` to avoid shell escaping issues
- Wait for trust dialog confirmation before sending prompts (claude asks on first run in a directory)
- The Creator uses `xcodegen` + `xcpretty` — it will not open Xcode until the build compiles cleanly
- Tester and Documenter poll for files from Creator before starting their work
