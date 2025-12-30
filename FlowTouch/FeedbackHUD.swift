import Cocoa
import QuartzCore

// MARK: - HUD Configuration

struct HUDConfig {
    // Snap preview
    static let previewBorderColor = NSColor.systemBlue.withAlphaComponent(0.8)
    static let previewFillColor = NSColor.systemBlue.withAlphaComponent(0.12)
    static let previewBorderWidth: CGFloat = 2.5
    static let previewCornerRadius: CGFloat = 12

    // Action indicator (center of screen)
    static let actionIndicatorHeight: CGFloat = 52
    static let actionIndicatorPadding: CGFloat = 28
    static let actionIndicatorCornerRadius: CGFloat = 14
    static let actionIndicatorBgColor = NSColor.black.withAlphaComponent(0.8)
    static let actionIndicatorTextColor = NSColor.white

    // Animation
    static let previewFadeInDuration: CFTimeInterval = 0.12
    static let previewFadeOutDuration: CFTimeInterval = 0.15
    static let actionDisplayDuration: CFTimeInterval = 0.7
}

// MARK: - Feedback HUD (Simplified - No Touch Cursors)

class FeedbackHUD {
    static let shared = FeedbackHUD()

    private var window: NSWindow?
    private var containerLayer: CALayer?

    // Visual elements
    private var previewLayer: CAShapeLayer?
    private var actionLayer: CALayer?
    private var actionTextLayer: CATextLayer?

    // Screen info cache
    private var screenFrame: CGRect = .zero
    private var visibleFrame: CGRect = .zero

    // State
    private var isPreviewVisible = false
    private var currentScreen: NSScreen?  // Track which screen we're on

    // MARK: - Setup

    func setup() {
        DispatchQueue.main.async { [weak self] in
            self?.setupOnMainThread()
        }
    }

    /// Get the target screen for displaying HUD (focused window's screen, or mouse screen as fallback)
    private func getTargetScreen() -> NSScreen? {
        // Try to get focused window's screen first
        if let focusedApp = NSWorkspace.shared.frontmostApplication,
           let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            let appPID = focusedApp.processIdentifier
            for windowInfo in windows {
                if let pid = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                   pid == appPID,
                   let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                   let windowX = bounds["X"],
                   let windowY = bounds["Y"] {
                    // Find which screen contains this window
                    let windowPoint = NSPoint(x: windowX + 50, y: windowY + 50) // Offset a bit into the window
                    for screen in NSScreen.screens {
                        if screen.frame.contains(windowPoint) {
                            return screen
                        }
                    }
                }
            }
        }

        // Fallback: use screen containing mouse pointer
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }

        // Last fallback: main screen
        return NSScreen.main
    }

    /// Update HUD to target screen if changed
    private func updateScreenIfNeeded() {
        guard let targetScreen = getTargetScreen() else { return }

        // Check if screen changed
        if currentScreen?.frame != targetScreen.frame {
            currentScreen = targetScreen
            screenFrame = targetScreen.frame
            visibleFrame = targetScreen.visibleFrame

            // Update window position to new screen
            window?.setFrame(screenFrame, display: true)

            // Update container layer size
            containerLayer?.frame = CGRect(origin: .zero, size: screenFrame.size)
            window?.contentView?.frame = CGRect(origin: .zero, size: screenFrame.size)

            #if DEBUG
            print("[FeedbackHUD] Screen changed to: \(screenFrame)")
            #endif
        }
    }

    private func setupOnMainThread() {
        guard let screen = NSScreen.main else {
            print("[FeedbackHUD] ERROR: No main screen found")
            return
        }

        currentScreen = screen
        screenFrame = screen.frame
        visibleFrame = screen.visibleFrame

        // Create transparent overlay window
        let win = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.level = .floating
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.orderFront(nil)

        self.window = win

        // Setup root view with layer
        let view = NSView(frame: screenFrame)
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        win.contentView = view

        // Create container layer
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: screenFrame.size)
        container.backgroundColor = .clear
        view.layer?.addSublayer(container)
        self.containerLayer = container

        // Initialize sublayers
        setupPreviewLayer()
        setupActionIndicator()

        print("[FeedbackHUD] Setup complete. Screen: \(screenFrame.width) x \(screenFrame.height)")
    }

    // MARK: - Layer Setup

    private func setupPreviewLayer() {
        let preview = CAShapeLayer()
        preview.strokeColor = HUDConfig.previewBorderColor.cgColor
        preview.fillColor = HUDConfig.previewFillColor.cgColor
        preview.lineWidth = HUDConfig.previewBorderWidth
        preview.lineCap = .round
        preview.lineJoin = .round
        preview.opacity = 0
        containerLayer?.addSublayer(preview)
        self.previewLayer = preview
    }

    private func setupActionIndicator() {
        // Background layer
        let action = CALayer()
        action.backgroundColor = HUDConfig.actionIndicatorBgColor.cgColor
        action.cornerRadius = HUDConfig.actionIndicatorCornerRadius
        action.opacity = 0
        containerLayer?.addSublayer(action)
        self.actionLayer = action

        // Text layer
        let text = CATextLayer()
        text.alignmentMode = .center
        text.foregroundColor = HUDConfig.actionIndicatorTextColor.cgColor
        text.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        text.fontSize = 18
        text.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        text.string = ""
        action.addSublayer(text)
        self.actionTextLayer = text
    }

    // MARK: - Public API (Thread-Safe)

    /// Show snap preview overlay for a direction
    func showSnapPreview(direction: SnapDirection) {
        if Thread.isMainThread {
            showSnapPreviewOnMain(direction: direction)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.showSnapPreviewOnMain(direction: direction)
            }
        }
    }

    private func showSnapPreviewOnMain(direction: SnapDirection) {
        // Update screen in case user moved focus to different monitor
        updateScreenIfNeeded()

        guard let preview = previewLayer else { return }

        // Calculate preview frame based on direction
        let previewRect = calculatePreviewRect(for: direction)

        // Create rounded rect path
        let path = CGPath(
            roundedRect: previewRect,
            cornerWidth: HUDConfig.previewCornerRadius,
            cornerHeight: HUDConfig.previewCornerRadius,
            transform: nil
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.path = path
        CATransaction.commit()

        // Animate in if not already visible
        if !isPreviewVisible {
            isPreviewVisible = true

            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = HUDConfig.previewFadeInDuration
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            preview.add(fadeIn, forKey: "fadeIn")
        }
    }

    /// Hide snap preview
    func hideSnapPreview() {
        if Thread.isMainThread {
            hideSnapPreviewOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hideSnapPreviewOnMain()
            }
        }
    }

    private func hideSnapPreviewOnMain() {
        guard let preview = previewLayer, isPreviewVisible else { return }

        isPreviewVisible = false

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = HUDConfig.previewFadeOutDuration
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        preview.add(fadeOut, forKey: "fadeOut")
    }

    /// Flash action indicator with text
    func flashAction(text: String, icon: String? = nil) {
        if Thread.isMainThread {
            flashActionOnMain(text: text, icon: icon)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.flashActionOnMain(text: text, icon: icon)
            }
        }
    }

    private func flashActionOnMain(text: String, icon: String? = nil) {
        // Update screen in case user moved focus to different monitor
        updateScreenIfNeeded()

        guard let actionLayer = actionLayer, let textLayer = actionTextLayer else { return }

        // Calculate size based on text
        let font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let layerWidth = textWidth + HUDConfig.actionIndicatorPadding * 2

        // Position at center of screen
        let x = (screenFrame.width - layerWidth) / 2
        let y = (screenFrame.height - HUDConfig.actionIndicatorHeight) / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        actionLayer.frame = CGRect(
            x: x,
            y: y,
            width: layerWidth,
            height: HUDConfig.actionIndicatorHeight
        )

        // Add subtle shadow
        actionLayer.shadowColor = NSColor.black.cgColor
        actionLayer.shadowOffset = CGSize(width: 0, height: -2)
        actionLayer.shadowRadius = 12
        actionLayer.shadowOpacity = 0.3

        textLayer.frame = CGRect(
            x: 0,
            y: (HUDConfig.actionIndicatorHeight - 24) / 2,
            width: layerWidth,
            height: 24
        )
        textLayer.font = font
        textLayer.fontSize = 18
        textLayer.string = text

        actionLayer.opacity = 1
        actionLayer.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
        CATransaction.commit()

        // Scale up animation with spring
        let scaleUp = CASpringAnimation(keyPath: "transform.scale")
        scaleUp.fromValue = 0.85
        scaleUp.toValue = 1.0
        scaleUp.damping = 12
        scaleUp.stiffness = 280
        scaleUp.mass = 0.8
        scaleUp.duration = 0.3
        actionLayer.add(scaleUp, forKey: "scaleUp")

        // Fade in
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.1
        actionLayer.add(fadeIn, forKey: "fadeIn")

        // Fade out after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + HUDConfig.actionDisplayDuration) { [weak self] in
            guard let actionLayer = self?.actionLayer else { return }

            // Scale down slightly while fading
            let scaleDown = CABasicAnimation(keyPath: "transform.scale")
            scaleDown.fromValue = 1.0
            scaleDown.toValue = 0.95
            scaleDown.duration = HUDConfig.previewFadeOutDuration

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1.0
            fadeOut.toValue = 0.0
            fadeOut.duration = HUDConfig.previewFadeOutDuration

            let group = CAAnimationGroup()
            group.animations = [scaleDown, fadeOut]
            group.duration = HUDConfig.previewFadeOutDuration
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            actionLayer.add(group, forKey: "dismiss")
        }
    }

    /// Clear all visual feedback
    func clear() {
        if Thread.isMainThread {
            clearOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.clearOnMain()
            }
        }
    }

    /// Show a subtle waiting indicator (for tap sequence waiting)
    func showWaitingIndicator(text: String) {
        if Thread.isMainThread {
            showWaitingOnMain(text: text)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.showWaitingOnMain(text: text)
            }
        }
    }

    private func showWaitingOnMain(text: String) {
        updateScreenIfNeeded()

        guard let actionLayer = actionLayer, let textLayer = actionTextLayer else { return }

        // Calculate size based on text
        let font = NSFont.systemFont(ofSize: 14, weight: .regular)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let layerWidth = textWidth + HUDConfig.actionIndicatorPadding * 2
        let layerHeight: CGFloat = 36

        // Position at center of screen
        let x = (screenFrame.width - layerWidth) / 2
        let y = (screenFrame.height - layerHeight) / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        actionLayer.frame = CGRect(x: x, y: y, width: layerWidth, height: layerHeight)
        actionLayer.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        actionLayer.shadowOpacity = 0.2

        textLayer.frame = CGRect(x: 0, y: (layerHeight - 18) / 2, width: layerWidth, height: 18)
        textLayer.font = font
        textLayer.fontSize = 14
        textLayer.string = text
        textLayer.foregroundColor = NSColor.white.withAlphaComponent(0.9).cgColor

        actionLayer.opacity = 1
        CATransaction.commit()

        // Gentle fade in
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.08
        actionLayer.add(fadeIn, forKey: "fadeIn")
    }

    /// Hide the waiting indicator
    func hideWaitingIndicator() {
        if Thread.isMainThread {
            hideWaitingOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hideWaitingOnMain()
            }
        }
    }

    private func hideWaitingOnMain() {
        guard let actionLayer = actionLayer else { return }

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = actionLayer.opacity
        fadeOut.toValue = 0
        fadeOut.duration = 0.1
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        actionLayer.add(fadeOut, forKey: "fadeOut")

        // Restore default styling
        actionLayer.backgroundColor = HUDConfig.actionIndicatorBgColor.cgColor
        actionTextLayer?.foregroundColor = HUDConfig.actionIndicatorTextColor.cgColor
    }

    private func clearOnMain() {
        hideSnapPreviewOnMain()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        actionLayer?.opacity = 0
        CATransaction.commit()
    }

    // MARK: - Legacy API (No-op for compatibility)

    func showTouchFeedback(touches: [(x: CGFloat, y: CGFloat)], state: Int) {
        // No longer showing touch cursors - this is intentionally empty
    }

    func showGestureFeedback(at point: CGPoint, state: Int) {
        // No longer showing gesture feedback - this is intentionally empty
    }

    func showDirection(_ direction: SnapDirection, at center: CGPoint) {
        // Replaced by showSnapPreview
        showSnapPreview(direction: direction)
    }

    // MARK: - Preview Calculation

    private func calculatePreviewRect(for direction: SnapDirection) -> CGRect {
        // Use visible frame (excludes menu bar and dock)
        // Convert from Cocoa coordinates to layer coordinates
        let x = visibleFrame.origin.x
        let y = visibleFrame.origin.y
        let w = visibleFrame.width
        let h = visibleFrame.height

        // Add small inset for visual clarity
        let inset: CGFloat = 4

        switch direction {
        case .left:
            return CGRect(x: x + inset, y: y + inset, width: w / 2 - inset * 2, height: h - inset * 2)

        case .right:
            return CGRect(x: x + w / 2 + inset, y: y + inset, width: w / 2 - inset * 2, height: h - inset * 2)

        case .top:
            return CGRect(x: x + inset, y: y + h / 2 + inset, width: w - inset * 2, height: h / 2 - inset * 2)

        case .bottom:
            return CGRect(x: x + inset, y: y + inset, width: w - inset * 2, height: h / 2 - inset * 2)

        case .topLeft:
            return CGRect(x: x + inset, y: y + h / 2 + inset, width: w / 2 - inset * 2, height: h / 2 - inset * 2)

        case .topRight:
            return CGRect(x: x + w / 2 + inset, y: y + h / 2 + inset, width: w / 2 - inset * 2, height: h / 2 - inset * 2)

        case .bottomLeft:
            return CGRect(x: x + inset, y: y + inset, width: w / 2 - inset * 2, height: h / 2 - inset * 2)

        case .bottomRight:
            return CGRect(x: x + w / 2 + inset, y: y + inset, width: w / 2 - inset * 2, height: h / 2 - inset * 2)

        case .maximize:
            return CGRect(x: x + inset, y: y + inset, width: w - inset * 2, height: h - inset * 2)

        case .center:
            let centerW = w * 0.7
            let centerH = h * 0.7
            let centerX = x + (w - centerW) / 2
            let centerY = y + (h - centerH) / 2
            return CGRect(x: centerX, y: centerY, width: centerW, height: centerH)

        case .restore:
            // Show smaller centered rectangle
            let restoreW = w * 0.5
            let restoreH = h * 0.5
            let restoreX = x + (w - restoreW) / 2
            let restoreY = y + (h - restoreH) / 2
            return CGRect(x: restoreX, y: restoreY, width: restoreW, height: restoreH)
        }
    }

    // MARK: - Screen Update

    func updateScreenInfo() {
        DispatchQueue.main.async { [weak self] in
            self?.updateScreenInfoOnMain()
        }
    }

    private func updateScreenInfoOnMain() {
        guard let screen = NSScreen.main else { return }
        screenFrame = screen.frame
        visibleFrame = screen.visibleFrame

        // Update window frame
        window?.setFrame(screenFrame, display: true)
        containerLayer?.frame = CGRect(origin: .zero, size: screenFrame.size)
    }
}
