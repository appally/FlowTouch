<p align="center">
  <img src="docs/assets/flowtouch-icon.png" width="128" height="128" alt="FlowTouch Icon">
</p>

<h1 align="center">FlowTouch</h1>

<p align="center">
  <b>Gesture-driven productivity for macOS</b><br>
  Turn your trackpad into a powerful command center — swipe, tap, or pinch to control windows, apps, media, and more.
</p>

<p align="center">
  <a href="README_CN.md">🇨🇳 中文文档</a>
</p>

---

## ✨ Highlights

| | |
|---|---|
| 🖐️ **Multi-touch gestures** | Swipe (2–5 fingers), tap (single / double / triple), pinch in & out |
| 🪟 **50+ built-in actions** | Window snapping, media controls, screenshots, Spaces navigation, custom keyboard shortcuts, and more |
| 🎯 **Per-app rules** | Assign different actions to the same gesture depending on the active application |
| 🧪 **Learning mode** | Visualize recognized gestures without executing — perfect for new users |
| 🔄 **Undo support** | Instantly revert the last window operation |
| 💡 **Visual feedback HUD** | On-screen overlay confirms every action at a glance |

---

## 🚀 Quick Start

### Requirements

- **macOS** (native app, no simulator needed)
- A trackpad — Magic Trackpad or built-in MacBook trackpad

### Installation

1. Download the latest release from [Releases](https://github.com/appally/FlowTouch/releases).
2. Move **FlowTouch.app** to your `/Applications` folder.
3. Launch the app and grant the required permissions (see below).

### Permissions

FlowTouch needs two system permissions to function:

| Permission | Why |
|---|---|
| **Input Monitoring** | Captures raw multi-touch data from the trackpad |
| **Accessibility** | Moves and resizes windows, simulates key events |

> **Tip:** Rebuilding from Xcode may invalidate permissions. If gestures stop working, go to  
> `System Settings → Privacy & Security` and re-add FlowTouch.

---

## 🎮 Supported Actions

<table>
<tr><th>Category</th><th>Actions</th></tr>
<tr><td>🪟 Window Layout</td><td>Snap left / right / top / bottom, quarter-screen corners</td></tr>
<tr><td>🔲 Window Control</td><td>Maximize, minimize, center, restore, close, fullscreen, undo, maximize height / width, minimize all, restore all</td></tr>
<tr><td>🖥️ Screens & Spaces</td><td>Move window to next / previous screen, switch Spaces left / right</td></tr>
<tr><td>🏠 Desktop & System</td><td>Mission Control, Show Desktop, App Exposé, Launchpad, Spotlight, Lock Screen, Screensaver</td></tr>
<tr><td>📱 App Control</td><td>Quit, hide, hide others, switch app, previous app</td></tr>
<tr><td>🗂️ Tab Control</td><td>New tab, close tab, next / previous tab</td></tr>
<tr><td>🎵 Media</td><td>Play / Pause, next / previous track, volume up / down / mute, brightness up / down</td></tr>
<tr><td>📸 Screenshot</td><td>Capture full screen, area, or window</td></tr>
<tr><td>⌨️ Custom Shortcut</td><td>Trigger any keyboard shortcut you define</td></tr>
</table>

---

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/appally/FlowTouch.git
cd FlowTouch

# Open in Xcode
open FlowTouch.xcodeproj
# Then press ⌘R to run
```

**CLI build:**

```bash
# Debug
xcodebuild -project FlowTouch.xcodeproj -scheme FlowTouch -configuration Debug build

# Release
xcodebuild -project FlowTouch.xcodeproj -scheme FlowTouch -configuration Release build
```

---

## 🤝 Contributing

| Topic | Guideline |
|---|---|
| **Code style** | Standard Swift — 4-space indent, `// MARK:` sections, file names match primary type |
| **Naming** | `UpperCamelCase` for types, `lowerCamelCase` for methods & properties |
| **Commits** | Conventional Commits (`feat:`, `fix:`, …), Chinese messages are welcome |
| **Pull requests** | Include summary, test steps, and screenshots for UI changes |

---

## 📄 License

See [LICENSE](LICENSE) for details.
