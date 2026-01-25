# Repository Guidelines

## Project Structure & Module Organization
- `FlowTouch/` contains all Swift source files for the macOS app (SwiftUI views, managers, and gesture handling).
- Key entry point: `FlowTouch/FlowTouchApp.swift` (app lifecycle + menu bar setup).
- Core logic lives in files like `GestureEngine.swift`, `MultitouchManager.swift`, and `RuleManager.swift`.
- Assets live in `FlowTouch/Assets.xcassets` (app icon and images).
- `FlowTouch.xcodeproj` stores the Xcode project configuration.

## Build, Test, and Development Commands
- Open in Xcode: `open FlowTouch.xcodeproj`, then run with ⌘R.
- CLI build (Debug): `xcodebuild -project FlowTouch.xcodeproj -scheme FlowTouch -configuration Debug build`
- CLI build (Release): `xcodebuild -project FlowTouch.xcodeproj -scheme FlowTouch -configuration Release build`
- Note: simulator runtimes are not required; this is a macOS app.

## Coding Style & Naming Conventions
- Use standard Swift style: 4‑space indentation, trailing commas where appropriate, and `// MARK:` sections to organize files.
- Type names use `UpperCamelCase`; methods and properties use `lowerCamelCase`.
- Prefer file names that match their primary type (e.g., `StatusBarManager.swift` contains `StatusBarManager`).
- Keep SwiftUI views lightweight and delegate system behavior to manager classes.

## Testing Guidelines
- There is no test target in the repo yet. If you add tests, create a `FlowTouchTests` target and place tests under `FlowTouchTests/`.
- Example test run (after adding tests): `xcodebuild test -project FlowTouch.xcodeproj -scheme FlowTouch -destination 'platform=macOS'`

## Commit & Pull Request Guidelines
- Commit history uses Conventional Commit‑style prefixes (e.g., `feat: …`). Keep the summary short and action‑oriented; Chinese is acceptable.
- PRs should include: a concise summary, steps to test, and screenshots for UI changes.
- Call out permission‑related changes (Input Monitoring/Accessibility) in the PR description.

## Security & Configuration Tips
- The app requires macOS **Input Monitoring** and **Accessibility** permissions to monitor gestures and move windows.
- Rebuilding in Xcode can invalidate permissions; remove and re‑add FlowTouch in System Settings if access stops working.
- Ensure a trackpad is available (Magic Trackpad or built‑in MacBook trackpad) when testing gesture features.
