import Cocoa
import ApplicationServices

// MARK: - Window Layout Types

enum SnapDirection: String, CaseIterable {
    case left           // Left half
    case right          // Right half
    case top            // Top half
    case bottom         // Bottom half
    case topLeft        // Top-left quarter
    case topRight       // Top-right quarter
    case bottomLeft     // Bottom-left quarter
    case bottomRight    // Bottom-right quarter
    case maximize       // Full screen (visible area)
    case center         // Center with reasonable size
    case restore        // Restore to previous size
}

// MARK: - Coordinate System Utilities

/// Utility for converting between Cocoa (bottom-left origin) and Accessibility (top-left origin) coordinates
struct ScreenCoordinates {

    /// Get the primary screen height (used as reference for coordinate conversion)
    static var primaryScreenHeight: CGFloat {
        return primaryScreenFrame.maxY
    }

    private static var primaryScreenFrame: CGRect {
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary.frame
        }
        if let main = NSScreen.main {
            return main.frame
        }
        return NSScreen.screens.first?.frame ?? .zero
    }

    /// Convert a point from Cocoa coordinates to Accessibility coordinates
    /// - Parameters:
    ///   - point: Point in Cocoa coordinates (origin at bottom-left of primary screen)
    ///   - height: Height of the rect being positioned (needed for top-left conversion)
    /// - Returns: Point in Accessibility coordinates (origin at top-left of primary screen)
    static func cocoaToAccessibility(_ point: CGPoint, rectHeight: CGFloat = 0) -> CGPoint {
        // In Cocoa: (0,0) is bottom-left of primary screen
        // In Accessibility: (0,0) is top-left of primary screen
        // Formula: axY = primaryScreenHeight - cocoaY - rectHeight
        let axY = primaryScreenHeight - point.y - rectHeight
        return CGPoint(x: point.x, y: axY)
    }

    /// Convert a rect from Cocoa coordinates to Accessibility coordinates
    static func cocoaToAccessibility(_ rect: NSRect) -> CGRect {
        let origin = cocoaToAccessibility(rect.origin, rectHeight: rect.height)
        return CGRect(origin: origin, size: rect.size)
    }

    /// Get the visible frame of a screen in Accessibility coordinates
    static func visibleFrameInAXCoordinates(for screen: NSScreen) -> CGRect {
        return cocoaToAccessibility(screen.visibleFrame)
    }
}

// MARK: - Window Manager

class WindowManager {
    static let shared = WindowManager()

    // Store previous window frames for restore functionality
    private var previousFrames: [pid_t: [String: CGRect]] = [:]

    // Track last operation for undo functionality
    private var lastOperationWindow: (pid: pid_t, windowId: String, previousFrame: CGRect)?

    // MARK: - Permission Check

    /// Check if we have Accessibility permission
    var isAccessibilityTrusted: Bool {
        return AXIsProcessTrusted()
    }

    /// Request Accessibility permission with prompt
    func requestAccessibilityPermission() {
        DispatchQueue.main.async {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }

    // MARK: - Window Operations (Thread-Safe Public API)

    /// Snap the focused window to a specific layout direction (thread-safe)
    /// - Parameter direction: The desired layout position
    @discardableResult
    func snapFocusedWindow(direction: SnapDirection) -> Bool {
        // Execute synchronously on main thread for immediate response
        if Thread.isMainThread {
            return snapFocusedWindowOnMain(direction: direction)
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.snapFocusedWindowOnMain(direction: direction) ?? false
            }
        }
    }

    /// Undo the last window operation (thread-safe)
    /// Returns true if undo was successful
    @discardableResult
    func undoLastOperation() -> Bool {
        if Thread.isMainThread {
            return undoLastOperationOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.undoLastOperationOnMain() ?? false
            }
        }
    }

    private func undoLastOperationOnMain() -> Bool {
        guard let lastOp = lastOperationWindow else {
            #if DEBUG
            print("[WindowManager] No operation to undo")
            #endif
            return false
        }

        // Find the window by PID and try to restore its position
        let app = AXUIElementCreateApplication(lastOp.pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            print("[WindowManager] Could not get windows for PID \(lastOp.pid)")
            return false
        }

        // Find the window with matching identifier
        for window in windows {
            let windowId = getWindowIdentifier(window) ?? "default"
            if windowId == lastOp.windowId {
                // Restore to previous frame
                let success = setWindowFrame(window, frame: lastOp.previousFrame)
                if success {
                    #if DEBUG
                    print("[WindowManager] Undo successful: restored window to \(lastOp.previousFrame)")
                    #endif
                    lastOperationWindow = nil  // Clear undo state after successful undo
                }
                return success
            }
        }

        #if DEBUG
        print("[WindowManager] Could not find window to undo")
        #endif
        return false
    }

    /// Check if there's an operation that can be undone
    var canUndo: Bool {
        return lastOperationWindow != nil
    }

    /// Close the focused window (thread-safe)
    @discardableResult
    func closeFocusedWindow() -> Bool {
        if Thread.isMainThread {
            return closeFocusedWindowOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.closeFocusedWindowOnMain() ?? false
            }
        }
    }

    /// Minimize the focused window (thread-safe)
    @discardableResult
    func minimizeFocusedWindow() -> Bool {
        if Thread.isMainThread {
            return minimizeFocusedWindowOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.minimizeFocusedWindowOnMain() ?? false
            }
        }
    }

    /// Toggle fullscreen for the focused window (thread-safe)
    @discardableResult
    func toggleFullscreen() -> Bool {
        if Thread.isMainThread {
            return toggleFullscreenOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.toggleFullscreenOnMain() ?? false
            }
        }
    }

    /// Move window to next screen
    @discardableResult
    func moveToNextScreen() -> Bool {
        if Thread.isMainThread {
            return moveToNextScreenOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.moveToNextScreenOnMain() ?? false
            }
        }
    }

    /// Move window to previous screen
    @discardableResult
    func moveToPrevScreen() -> Bool {
        if Thread.isMainThread {
            return moveToPrevScreenOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.moveToPrevScreenOnMain() ?? false
            }
        }
    }

    @discardableResult
    private func moveToNextScreenOnMain() -> Bool {
        return moveToScreenOnMain(next: true)
    }

    @discardableResult
    private func moveToPrevScreenOnMain() -> Bool {
        return moveToScreenOnMain(next: false)
    }

    private func moveToScreenOnMain(next: Bool) -> Bool {
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            return false
        }

        let screens = NSScreen.screens
        guard screens.count > 1 else {
            #if DEBUG
            print("[WindowManager] Only one screen available")
            #endif
            return false
        }

        guard let axWindow = getFocusedWindow(),
              let currentFrame = getWindowFrame(axWindow) else {
            return false
        }

        // Find which screen the window is currently on
        let windowCenter = CGPoint(
            x: currentFrame.origin.x + currentFrame.width / 2,
            y: currentFrame.origin.y + currentFrame.height / 2
        )

        // Convert to Cocoa coordinates to find the screen
        let cocoaY = ScreenCoordinates.primaryScreenHeight - windowCenter.y
        let cocoaCenter = CGPoint(x: windowCenter.x, y: cocoaY)

        var currentScreenIndex = 0
        for (index, screen) in screens.enumerated() {
            if screen.frame.contains(cocoaCenter) {
                currentScreenIndex = index
                break
            }
        }

        // Calculate target screen index
        let targetScreenIndex: Int
        if next {
            targetScreenIndex = (currentScreenIndex + 1) % screens.count
        } else {
            targetScreenIndex = (currentScreenIndex - 1 + screens.count) % screens.count
        }

        let targetScreen = screens[targetScreenIndex]
        let targetVisibleFrame = ScreenCoordinates.visibleFrameInAXCoordinates(for: targetScreen)

        // Keep relative position and size if possible
        let currentVisibleFrame = ScreenCoordinates.visibleFrameInAXCoordinates(for: screens[currentScreenIndex])

        // Calculate relative position (0-1 range)
        let relativeX = (currentFrame.origin.x - currentVisibleFrame.origin.x) / currentVisibleFrame.width
        let relativeY = (currentFrame.origin.y - currentVisibleFrame.origin.y) / currentVisibleFrame.height
        let relativeWidth = currentFrame.width / currentVisibleFrame.width
        let relativeHeight = currentFrame.height / currentVisibleFrame.height

        // Apply to target screen
        let newX = targetVisibleFrame.origin.x + relativeX * targetVisibleFrame.width
        let newY = targetVisibleFrame.origin.y + relativeY * targetVisibleFrame.height
        let newWidth = min(relativeWidth * targetVisibleFrame.width, targetVisibleFrame.width)
        let newHeight = min(relativeHeight * targetVisibleFrame.height, targetVisibleFrame.height)

        let newFrame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        return setWindowFrame(axWindow, frame: newFrame)
    }

    /// Maximize window height while keeping width and horizontal position
    @discardableResult
    func maximizeHeight() -> Bool {
        if Thread.isMainThread {
            return maximizeHeightOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.maximizeHeightOnMain() ?? false
            }
        }
    }

    /// Maximize window width while keeping height and vertical position
    @discardableResult
    func maximizeWidth() -> Bool {
        if Thread.isMainThread {
            return maximizeWidthOnMain()
        } else {
            return DispatchQueue.main.sync { [weak self] in
                self?.maximizeWidthOnMain() ?? false
            }
        }
    }

    @discardableResult
    private func maximizeHeightOnMain() -> Bool {
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            return false
        }

        guard let axWindow = getFocusedWindow(),
              let currentFrame = getWindowFrame(axWindow),
              let screen = getScreenWithMouse() else {
            return false
        }

        let visibleFrame = ScreenCoordinates.visibleFrameInAXCoordinates(for: screen)

        // Keep x position and width, maximize height
        let newFrame = CGRect(
            x: currentFrame.origin.x,
            y: visibleFrame.origin.y,
            width: currentFrame.width,
            height: visibleFrame.height
        )

        return setWindowFrame(axWindow, frame: newFrame)
    }

    @discardableResult
    private func maximizeWidthOnMain() -> Bool {
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            return false
        }

        guard let axWindow = getFocusedWindow(),
              let currentFrame = getWindowFrame(axWindow),
              let screen = getScreenWithMouse() else {
            return false
        }

        let visibleFrame = ScreenCoordinates.visibleFrameInAXCoordinates(for: screen)

        // Keep y position and height, maximize width
        let newFrame = CGRect(
            x: visibleFrame.origin.x,
            y: currentFrame.origin.y,
            width: visibleFrame.width,
            height: currentFrame.height
        )

        return setWindowFrame(axWindow, frame: newFrame)
    }

    /// Get list of all windows for current application
    func getWindowList() -> [AXUIElement] {
        // This should only be called from main thread
        guard Thread.isMainThread else {
            print("[WindowManager] WARNING: getWindowList called from background thread")
            return []
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return [] }
        let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        return windows
    }

    // MARK: - Private Implementation (Main Thread Only)

    @discardableResult
    private func snapFocusedWindowOnMain(direction: SnapDirection) -> Bool {
        // Check permission first
        guard isAccessibilityTrusted else {
            print("[WindowManager] ERROR: Accessibility permission not granted")
            requestAccessibilityPermission()
            return false
        }

        // Get frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("[WindowManager] ERROR: No frontmost application")
            return false
        }

        let pid = frontApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get focused window
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)

        guard result == .success, let window = windowRef else {
            print("[WindowManager] ERROR: Could not get focused window for PID \(pid), error: \(result.rawValue)")
            return false
        }

        // Safe cast to AXUIElement
        guard CFGetTypeID(window) == AXUIElementGetTypeID() else {
            print("[WindowManager] ERROR: Window reference is not an AXUIElement")
            return false
        }
        let axWindow = window as! AXUIElement

        // Get current window frame for restore functionality
        if direction != .restore {
            if let currentFrame = getWindowFrame(axWindow) {
                let windowId = getWindowIdentifier(axWindow) ?? "default"
                if previousFrames[pid] == nil {
                    previousFrames[pid] = [:]
                }
                previousFrames[pid]?[windowId] = currentFrame

                // Track for undo functionality
                lastOperationWindow = (pid: pid, windowId: windowId, previousFrame: currentFrame)
            }
        }

        // Get the screen where the mouse is located
        guard let screen = getScreenWithMouse() else {
            print("[WindowManager] ERROR: Could not determine current screen")
            return false
        }

        // Calculate target frame based on direction
        let targetFrame: CGRect

        switch direction {
        case .restore:
            let windowId = getWindowIdentifier(axWindow) ?? "default"
            if let savedFrame = previousFrames[pid]?[windowId] {
                targetFrame = savedFrame
            } else {
                print("[WindowManager] No saved frame to restore")
                return false
            }

        default:
            targetFrame = calculateFrame(for: direction, in: screen)
        }

        // Apply the new frame
        return setWindowFrame(axWindow, frame: targetFrame)
    }

    @discardableResult
    private func closeFocusedWindowOnMain() -> Bool {
        guard isAccessibilityTrusted else {
            print("[WindowManager] ERROR: Accessibility permission not granted")
            requestAccessibilityPermission()
            return false
        }

        guard let axWindow = getFocusedWindow() else {
            print("[WindowManager] ERROR: No focused window to close")
            return false
        }

        // Find and press the close button
        var closeButtonRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXCloseButtonAttribute as CFString, &closeButtonRef)

        guard result == .success, let closeButton = closeButtonRef else {
            print("[WindowManager] ERROR: Could not find close button")
            return false
        }

        let pressResult = AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)

        if pressResult == .success {
            #if DEBUG
            print("[WindowManager] Window closed successfully")
            #endif
            return true
        } else {
            print("[WindowManager] ERROR: Failed to close window, error: \(pressResult.rawValue)")
            return false
        }
    }

    @discardableResult
    private func minimizeFocusedWindowOnMain() -> Bool {
        guard isAccessibilityTrusted else {
            print("[WindowManager] ERROR: Accessibility permission not granted")
            requestAccessibilityPermission()
            return false
        }

        guard let axWindow = getFocusedWindow() else {
            print("[WindowManager] ERROR: No focused window to minimize")
            return false
        }

        // Find and press the minimize button
        var minimizeButtonRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXMinimizeButtonAttribute as CFString, &minimizeButtonRef)

        guard result == .success, let minimizeButton = minimizeButtonRef else {
            // Fallback: try setting minimized attribute directly
            let minimized: CFBoolean = kCFBooleanTrue
            let setResult = AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, minimized)
            if setResult == .success {
                #if DEBUG
                print("[WindowManager] Window minimized via attribute")
                #endif
                return true
            }
            print("[WindowManager] ERROR: Could not minimize window")
            return false
        }

        let pressResult = AXUIElementPerformAction(minimizeButton as! AXUIElement, kAXPressAction as CFString)

        if pressResult == .success {
            #if DEBUG
            print("[WindowManager] Window minimized successfully")
            #endif
            return true
        } else {
            print("[WindowManager] ERROR: Failed to minimize window, error: \(pressResult.rawValue)")
            return false
        }
    }

    @discardableResult
    private func toggleFullscreenOnMain() -> Bool {
        guard isAccessibilityTrusted else {
            print("[WindowManager] ERROR: Accessibility permission not granted")
            requestAccessibilityPermission()
            return false
        }

        guard let axWindow = getFocusedWindow() else {
            print("[WindowManager] ERROR: No focused window for fullscreen")
            return false
        }

        // Find and press the fullscreen button (zoom button)
        var fullscreenButtonRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXFullScreenButtonAttribute as CFString, &fullscreenButtonRef)

        guard result == .success, let fullscreenButton = fullscreenButtonRef else {
            // Fallback: try zoom button
            var zoomButtonRef: CFTypeRef?
            let zoomResult = AXUIElementCopyAttributeValue(axWindow, kAXZoomButtonAttribute as CFString, &zoomButtonRef)

            if zoomResult == .success, let zoomButton = zoomButtonRef {
                let pressResult = AXUIElementPerformAction(zoomButton as! AXUIElement, kAXPressAction as CFString)
                if pressResult == .success {
                    #if DEBUG
                    print("[WindowManager] Fullscreen toggled via zoom button")
                    #endif
                    return true
                }
            }

            print("[WindowManager] ERROR: Could not find fullscreen button")
            return false
        }

        let pressResult = AXUIElementPerformAction(fullscreenButton as! AXUIElement, kAXPressAction as CFString)

        if pressResult == .success {
            #if DEBUG
            print("[WindowManager] Fullscreen toggled successfully")
            #endif
            return true
        } else {
            print("[WindowManager] ERROR: Failed to toggle fullscreen, error: \(pressResult.rawValue)")
            return false
        }
    }

    // MARK: - Frame Calculation

    /// Calculate the target frame for a given direction on a specific screen
    private func calculateFrame(for direction: SnapDirection, in screen: NSScreen) -> CGRect {
        // Get visible frame in Accessibility coordinates
        let visibleFrame = ScreenCoordinates.visibleFrameInAXCoordinates(for: screen)

        let x = visibleFrame.origin.x
        let y = visibleFrame.origin.y
        let w = visibleFrame.width
        let h = visibleFrame.height

        switch direction {
        case .left:
            return CGRect(x: x, y: y, width: w / 2, height: h)

        case .right:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)

        case .top:
            return CGRect(x: x, y: y, width: w, height: h / 2)

        case .bottom:
            return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)

        case .topLeft:
            return CGRect(x: x, y: y, width: w / 2, height: h / 2)

        case .topRight:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h / 2)

        case .bottomLeft:
            return CGRect(x: x, y: y + h / 2, width: w / 2, height: h / 2)

        case .bottomRight:
            return CGRect(x: x + w / 2, y: y + h / 2, width: w / 2, height: h / 2)

        case .maximize:
            return CGRect(x: x, y: y, width: w, height: h)

        case .center:
            // Center window with 70% of screen size
            let centerW = w * 0.7
            let centerH = h * 0.7
            let centerX = x + (w - centerW) / 2
            let centerY = y + (h - centerH) / 2
            return CGRect(x: centerX, y: centerY, width: centerW, height: centerH)

        case .restore:
            // Handled separately
            return visibleFrame
        }
    }

    // MARK: - Accessibility Helpers

    /// Get the current frame of a window in Accessibility coordinates
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }

    /// Set the frame of a window using Accessibility API
    @discardableResult
    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        var position = frame.origin
        var size = frame.size

        // Create AXValue for position
        guard let positionVal = AXValueCreate(.cgPoint, &position) else {
            print("[WindowManager] ERROR: Failed to create position AXValue")
            return false
        }

        // Create AXValue for size
        guard let sizeVal = AXValueCreate(.cgSize, &size) else {
            print("[WindowManager] ERROR: Failed to create size AXValue")
            return false
        }

        // Set position first, then size (order matters for some apps)
        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionVal)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)

        if posResult != .success {
            print("[WindowManager] WARNING: Failed to set position, error: \(posResult.rawValue)")
        }
        if sizeResult != .success {
            print("[WindowManager] WARNING: Failed to set size, error: \(sizeResult.rawValue)")
        }

        let success = posResult == .success || sizeResult == .success
        if success {
            #if DEBUG
            print("[WindowManager] Snapped window to \(frame)")
            #endif
        }

        return success
    }

    /// Get a unique identifier for a window (for restore functionality)
    private func getWindowIdentifier(_ window: AXUIElement) -> String? {
        var numberRef: CFTypeRef?
        let windowNumberAttribute = "AXWindowNumber" as CFString
        if AXUIElementCopyAttributeValue(window, windowNumberAttribute, &numberRef) == .success,
           let number = numberRef as? NSNumber {
            return "windowNumber:\(number.intValue)"
        }
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String {
            return title
        }
        return nil
    }

    /// Get the screen containing the mouse cursor
    private func getScreenWithMouse() -> NSScreen? {
        let mouseLoc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) }
    }

    /// Get the currently focused window
    private func getFocusedWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = frontApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)

        guard result == .success, let window = windowRef else {
            return nil
        }

        guard CFGetTypeID(window) == AXUIElementGetTypeID() else {
            return nil
        }

        return (window as! AXUIElement)
    }
}
