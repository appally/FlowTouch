# FlowTouch

FlowTouch is a powerful macOS application that allows users to trigger various actions using multi-touch gestures. Built entirely in Swift and SwiftUI, it enhances productivity by bringing intuitive gesture-based commands directly to your Mac.

## Features
- **Gesture Recognition:** Custom gesture engine (`GestureEngine.swift`) capable of interpreting complex multi-touch gestures.
- **System Integration:** Operates seamlessly with the macOS system through Accessibility and Input Monitoring APIs.
- **Rule Management:** Advanced `RuleManager.swift` to handle triggered actions based on gesture configurations.
- **SwiftUI Views:** Lightweight UI components focused on configuration and system status management.

## Project Architecture
- `FlowTouch/` Core directory containing all Swift source files (Views, Managers, Gesture Handling logic).
- `FlowTouch/FlowTouchApp.swift` Application entry point and menu bar setup.
- `FlowTouch/Assets.xcassets` Contains the app icon and other image assets.
- `FlowTouch.xcodeproj` The Xcode project file for building and developing the app.

## Requirements & Permissions
To function properly, FlowTouch requires specific macOS permissions:
- **Input Monitoring:** Needed to capture and interpret custom trackpad gestures.
- **Accessibility:** Needed to execute window management actions and system-level commands.
> **Note:** Rebuilding the app via Xcode may invalidate your previously granted permissions. If gestures stop responding, remove and re-add **FlowTouch** in `System Settings -> Privacy & Security`.

## Getting Started

### Development 
You do not need a simulator runtime as this is a native macOS application. A physical trackpad (Magic Trackpad or built-in MacBook trackpad) is required for testing.

1. **Open the project in Xcode:**
   ```bash
   open FlowTouch.xcodeproj
   ```
2. **Run the App:** Press `⌘R` in Xcode to run the application.

### Command-Line Building
You can also compile the project directly from the terminal:
- **Debug Build:**
  ```bash
  xcodebuild -project FlowTouch.xcodeproj -scheme FlowTouch -configuration Debug build
  ```
- **Release Build:**
  ```bash
  xcodebuild -project FlowTouch.xcodeproj -scheme FlowTouch -configuration Release build
  ```

## Testing
Currently, the project focuses on app-level manual gesture verification. 
If adding automated tests:
1. Create a `FlowTouchTests` target in Xcode.
2. Place your test files inside the `FlowTouchTests/` directory.
3. Run tests via CLI:
   ```bash
   xcodebuild test -project FlowTouch.xcodeproj -scheme FlowTouch -destination 'platform=macOS'
   ```

## Contributing
- **Code Style:** Standard Swift styling. 4-space indentation, trailing commas where appropriate, and use `// MARK:` to organize large files.
- **Naming Conventions:** Use `UpperCamelCase` for types and `lowerCamelCase` for methods/properties. File names should match the main type they encapsulate (e.g., `StatusBarManager.swift`).
- **Commits:** We follow Conventional Commits (e.g., `feat: ...`, `fix: ...`). Keep commit messages short and action-oriented (Chinese is perfectly acceptable).
- **Pull Requests:** PRs must include a concise summary of changes, steps to test the feature/fix, and UI screenshots if applicable. If your PR modifies permission requirements, make that clear in your PR description.
