import Cocoa
import Carbon
import ApplicationServices

// MARK: - Custom Shortcut Configuration

/// Represents a custom keyboard shortcut
struct CustomShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt32  // Carbon modifier flags

    /// Human-readable representation
    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }

        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let specialKeys: [UInt16: String] = [
            0x24: "↩︎",  // Return
            0x30: "⇥",  // Tab
            0x31: "␣",  // Space
            0x33: "⌫",  // Delete
            0x35: "⎋",  // Escape
            0x7B: "←",
            0x7C: "→",
            0x7D: "↓",
            0x7E: "↑",
            0x73: "Home",
            0x77: "End",
            0x74: "PgUp",
            0x79: "PgDn",
            // Standard ANSI
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x32: "`"
        ]

        if let special = specialKeys[keyCode] {
            return special
        }

        // For regular keys, try to get the character
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key\(keyCode)"
        }

        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let layoutPtr = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        let result = UCKeyTranslate(
            layoutPtr,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        if result == noErr && length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }

        return "Key\(keyCode)"
    }
}

// MARK: - Custom Shortcut Storage

class CustomShortcutManager {
    static let shared = CustomShortcutManager()

    private let storageKey = "CustomShortcuts"

    /// Get custom shortcut for a rule
    func getShortcut(for ruleId: UUID) -> CustomShortcut? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let shortcuts = try? JSONDecoder().decode([String: CustomShortcut].self, from: data) else {
            return nil
        }
        return shortcuts[ruleId.uuidString]
    }

    /// Set custom shortcut for a rule
    func setShortcut(_ shortcut: CustomShortcut, for ruleId: UUID) {
        var shortcuts = getAllShortcuts()
        shortcuts[ruleId.uuidString] = shortcut
        saveShortcuts(shortcuts)
    }

    /// Remove shortcut for a rule
    func removeShortcut(for ruleId: UUID) {
        var shortcuts = getAllShortcuts()
        shortcuts.removeValue(forKey: ruleId.uuidString)
        saveShortcuts(shortcuts)
    }

    private func getAllShortcuts() -> [String: CustomShortcut] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let shortcuts = try? JSONDecoder().decode([String: CustomShortcut].self, from: data) else {
            return [:]
        }
        return shortcuts
    }

    private func saveShortcuts(_ shortcuts: [String: CustomShortcut]) {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - System Actions Manager

/// Executes system-level actions (non-window actions)
class SystemActionsManager {
    static let shared = SystemActionsManager()

    // MARK: - Execute Action

    /// Execute a non-window action
    /// - Parameters:
    ///   - action: The action to execute
    ///   - ruleId: Optional rule ID for custom shortcut lookup
    /// - Returns: Whether the action was executed successfully
    @discardableResult
    func execute(_ action: WindowAction, ruleId: UUID? = nil) -> Bool {
        switch action {
        // ============================================
        // Desktop & System Actions
        // ============================================
        case .missionControl:
            return simulateKeyPress(keyCode: 0x7E, modifiers: CGEventFlags.maskControl)  // Ctrl+Up

        case .showDesktop:
            return simulateFunctionKey(.f11)

        case .appExpose:
            return simulateKeyPress(keyCode: 0x7D, modifiers: CGEventFlags.maskControl)  // Ctrl+Down

        case .launchpad:
            return simulateFunctionKey(.f4)

        case .spotlight:
            return simulateKeyPress(keyCode: 0x31, modifiers: CGEventFlags.maskCommand)  // Cmd+Space

        case .lockScreen:
            return lockScreen()

        case .startScreensaver:
            return startScreensaver()

        // ============================================
        // Space Navigation
        // ============================================
        case .spaceLeft:
            return simulateKeyPress(keyCode: 0x7B, modifiers: CGEventFlags.maskControl)  // Ctrl+Left

        case .spaceRight:
            return simulateKeyPress(keyCode: 0x7C, modifiers: CGEventFlags.maskControl)  // Ctrl+Right

        case .moveToNextSpace:
            // Move window to next space - this is complex and requires private APIs
            #if DEBUG
            print("[SystemActions] moveToNextSpace not yet implemented")
            #endif
            return false

        case .moveToPrevSpace:
            #if DEBUG
            print("[SystemActions] moveToPrevSpace not yet implemented")
            #endif
            return false

        case .moveToNextScreen:
            return WindowManager.shared.moveToNextScreen()

        case .moveToPrevScreen:
            return WindowManager.shared.moveToPrevScreen()

        // ============================================
        // Application Actions
        // ============================================
        case .quitApp:
            return simulateKeyPress(keyCode: 0x0C, modifiers: CGEventFlags.maskCommand)  // Cmd+Q

        case .hideApp:
            return simulateKeyPress(keyCode: 0x04, modifiers: CGEventFlags.maskCommand)  // Cmd+H

        case .hideOthers:
            return simulateKeyPress(keyCode: 0x04, modifiers: [CGEventFlags.maskCommand, CGEventFlags.maskAlternate])  // Cmd+Opt+H

        case .switchApp:
            return simulateKeyPress(keyCode: 0x30, modifiers: CGEventFlags.maskCommand)  // Cmd+Tab

        case .previousApp:
            return simulateKeyPress(keyCode: 0x30, modifiers: [CGEventFlags.maskCommand, CGEventFlags.maskShift])  // Cmd+Shift+Tab

        // ============================================
        // Custom Shortcut
        // ============================================
        case .customShortcut:
            guard let ruleId = ruleId,
                  let shortcut = CustomShortcutManager.shared.getShortcut(for: ruleId) else {
                #if DEBUG
                print("[SystemActions] No custom shortcut configured")
                #endif
                return false
            }
            return executeCustomShortcut(shortcut)

        // ============================================
        // Extended Window Control (handled by WindowManager)
        // ============================================
        case .maximizeHeight:
            return WindowManager.shared.maximizeHeight()

        case .maximizeWidth:
            return WindowManager.shared.maximizeWidth()

        case .minimizeAll:
            return minimizeAllWindows()

        case .restoreAllMinimized:
            return restoreAllMinimizedWindows()

        // ============================================
        // Tab Control
        // ============================================
        case .newTab:
            return simulateKeyPress(keyCode: 0x11, modifiers: CGEventFlags.maskCommand)  // Cmd+T

        case .closeTab:
            return simulateKeyPress(keyCode: 0x0D, modifiers: CGEventFlags.maskCommand)  // Cmd+W

        case .nextTab:
            return simulateKeyPress(keyCode: 0x30, modifiers: CGEventFlags.maskControl)  // Ctrl+Tab

        case .prevTab:
            return simulateKeyPress(keyCode: 0x30, modifiers: [CGEventFlags.maskControl, CGEventFlags.maskShift])  // Ctrl+Shift+Tab

        // ============================================
        // Media Control
        // ============================================
        case .playPause:
            return simulateMediaKey(.playPause)

        case .nextTrack:
            return simulateMediaKey(.next)

        case .prevTrack:
            return simulateMediaKey(.previous)

        case .volumeUp:
            return simulateMediaKey(.volumeUp)

        case .volumeDown:
            return simulateMediaKey(.volumeDown)

        case .volumeMute:
            return simulateMediaKey(.mute)

        // ============================================
        // Brightness Control
        // ============================================
        case .brightnessUp:
            return simulateMediaKey(.brightnessUp)

        case .brightnessDown:
            return simulateMediaKey(.brightnessDown)

        // ============================================
        // Screenshot
        // ============================================
        case .screenshot:
            return simulateKeyPress(keyCode: 0x14, modifiers: [CGEventFlags.maskCommand, CGEventFlags.maskShift])  // Cmd+Shift+3

        case .screenshotArea:
            return simulateKeyPress(keyCode: 0x15, modifiers: [CGEventFlags.maskCommand, CGEventFlags.maskShift])  // Cmd+Shift+4

        case .screenshotWindow:
            return simulateKeyPress(keyCode: 0x17, modifiers: [CGEventFlags.maskCommand, CGEventFlags.maskShift])  // Cmd+Shift+5

        default:
            // Other actions (window layout, etc.) should be handled by WindowManager
            return false
        }
    }

    // MARK: - Keyboard Simulation

    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            print("[SystemActions] Failed to create key down event")
            return false
        }
        keyDown.flags = modifiers

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("[SystemActions] Failed to create key up event")
            return false
        }
        keyUp.flags = modifiers

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        #if DEBUG
        print("[SystemActions] Simulated key press: \(keyCode) with modifiers: \(modifiers.rawValue)")
        #endif
        return true
    }

    private enum FunctionKey {
        case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

        var keyCode: CGKeyCode {
            switch self {
            case .f1: return 0x7A
            case .f2: return 0x78
            case .f3: return 0x63
            case .f4: return 0x76
            case .f5: return 0x60
            case .f6: return 0x61
            case .f7: return 0x62
            case .f8: return 0x64
            case .f9: return 0x65
            case .f10: return 0x6D
            case .f11: return 0x67
            case .f12: return 0x6F
            }
        }
    }

    private func simulateFunctionKey(_ key: FunctionKey) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: false) else {
            return false
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        #if DEBUG
        print("[SystemActions] Simulated function key: \(key)")
        #endif
        return true
    }

    // MARK: - Media Key Simulation

    private enum MediaKey: Int {
        case playPause = 16     // NX_KEYTYPE_PLAY
        case next = 17          // NX_KEYTYPE_NEXT
        case previous = 18      // NX_KEYTYPE_PREVIOUS
        case mute = 7           // NX_KEYTYPE_MUTE
        case volumeUp = 0       // NX_KEYTYPE_SOUND_UP
        case volumeDown = 1     // NX_KEYTYPE_SOUND_DOWN
        case brightnessUp = 2   // NX_KEYTYPE_BRIGHTNESS_UP
        case brightnessDown = 3 // NX_KEYTYPE_BRIGHTNESS_DOWN
    }

    private func simulateMediaKey(_ key: MediaKey) -> Bool {
        // Media keys use special HID system events
        // We need to post them as system-defined events

        let keyCode = Int32(key.rawValue)

        // Create key down event
        let keyDownEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: NSPoint.zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),  // NX_KEYDOWN
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,  // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            data1: Int((keyCode << 16) | (0xa << 8)),  // key down
            data2: -1
        )

        // Create key up event
        let keyUpEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: NSPoint.zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),  // NX_KEYUP
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,  // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            data1: Int((keyCode << 16) | (0xb << 8)),  // key up
            data2: -1
        )

        guard let downEvent = keyDownEvent, let upEvent = keyUpEvent else {
            print("[SystemActions] Failed to create media key event")
            return false
        }

        // Post events to system
        guard let downCGEvent = downEvent.cgEvent, let upCGEvent = upEvent.cgEvent else {
            print("[SystemActions] Failed to get CGEvent from NSEvent")
            return false
        }

        downCGEvent.post(tap: .cghidEventTap)
        upCGEvent.post(tap: .cghidEventTap)

        #if DEBUG
        print("[SystemActions] Simulated media key: \(key)")
        #endif
        return true
    }

    private func executeCustomShortcut(_ shortcut: CustomShortcut) -> Bool {
        // Convert Carbon modifiers to CGEventFlags
        var flags = CGEventFlags()

        if shortcut.modifiers & UInt32(cmdKey) != 0 {
            flags.insert(.maskCommand)
        }
        if shortcut.modifiers & UInt32(optionKey) != 0 {
            flags.insert(.maskAlternate)
        }
        if shortcut.modifiers & UInt32(controlKey) != 0 {
            flags.insert(.maskControl)
        }
        if shortcut.modifiers & UInt32(shiftKey) != 0 {
            flags.insert(.maskShift)
        }

        return simulateKeyPress(keyCode: CGKeyCode(shortcut.keyCode), modifiers: flags)
    }

    // MARK: - System Commands

    private func lockScreen() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]

        do {
            try task.run()
            #if DEBUG
            print("[SystemActions] Lock screen executed")
            #endif
            return true
        } catch {
            print("[SystemActions] Lock screen failed: \(error)")
            return false
        }
    }

    private func startScreensaver() -> Bool {
        let result = NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        #if DEBUG
        print("[SystemActions] Start screensaver: \(result)")
        #endif
        return result
    }

    private func minimizeAllWindows() -> Bool {
        // Use AppleScript for reliability
        let script = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            tell application frontApp to set miniaturized of every window to true
        end tell
        """

        return runAppleScript(script)
    }

    private func restoreAllMinimizedWindows() -> Bool {
        // Use AppleScript to restore minimized windows
        let script = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            tell application frontApp to set miniaturized of every window to false
        end tell
        """

        return runAppleScript(script)
    }

    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else {
            print("[SystemActions] Failed to create AppleScript")
            return false
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        if let error = error {
            print("[SystemActions] AppleScript error: \(error)")
            return false
        }

        #if DEBUG
        print("[SystemActions] AppleScript executed successfully")
        #endif
        return true
    }
}
