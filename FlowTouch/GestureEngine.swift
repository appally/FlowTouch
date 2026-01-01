import Foundation
import QuartzCore

// MARK: - Gesture State

enum GestureState: Int {
    case possible = 0
    case began = 1
    case changed = 2
    case ended = 3
    case cancelled = 4
}

// MARK: - Gesture Engine (Rule-Based)

class GestureEngine {
    static let shared = GestureEngine()

    // Rule Manager (primary source)
    private var ruleManager: RuleManager {
        RuleManager.shared
    }

    // Legacy Configuration (fallback)
    private var config: GestureConfiguration {
        ConfigurationManager.shared.config
    }

    // State
    private var state: GestureState = .possible
    private var fingerCount: Int = 0

    // Tracking
    private var initialCentroid: MTVector?
    private var currentCentroid: MTVector?
    private var previousCentroid: MTVector?
    private var lockedDirection: SwipeDirection?

    // Pinch tracking
    private var initialPinchDistance: Float = 0

    // Velocity tracking
    private var lastFrameTime: Double = 0
    private var velocityX: Float = 0
    private var velocityY: Float = 0

    // Timing
    private var gestureStartTime: Double = 0
    private var lastActionTime: Double = 0

    // Preview state
    private var currentPreviewDirection: SnapDirection?
    private var pendingPreviewDirection: SnapDirection?
    private var previewDebounceTimer: Timer?
    private let previewDebounceInterval: TimeInterval = 0.08  // 80ms debounce

    // Learning mode - shows gesture recognition without executing actions
    private(set) var isLearningMode: Bool = false
    private var learningModeCallback: ((String, String) -> Void)?  // (gesture, action)

    // Tap detection state
    private var tapCount: Int = 0
    private var lastTapTime: Double = 0
    private var lastTapFingerCount: Int = 0
    private var touchDownTime: Double = 0
    private var totalMovement: Float = 0
    private var isTapCandidate: Bool = false
    private var tapTimer: Timer?
    private var peakTouchingFingers: Int = 0  // Track max fingers during touch
    private var wasAllTouching: Bool = false   // Track if all fingers were touching

    // Constants
    private let gestureStartThreshold: Float = 0.04
    private let gestureCooldown: TimeInterval = 0.25  // Further reduced for taps
    private let gestureTimeout: TimeInterval = 1.5
    private let minSwipeVelocity: Float = 0.3
    private let fastSwipeMultiplier: Float = 0.7

    // Tap constants
    private let tapMovementThreshold: Float = 0.045  // More tolerant for multi-finger (increased from 0.035)
    private let tapMaxDuration: TimeInterval = 0.40  // Allow slightly longer taps (increased from 0.35)
    private let tapSequenceTimeout: TimeInterval = 0.30  // Comfortable double-tap interval (increased from 0.18)

    // Direction unlock constants
    private let directionUnlockAngle: Float = 60  // Degrees: allow direction change if angle diff > this
    private let directionConfirmDistance: Float = 0.06  // Minimum distance before allowing direction update

    // MARK: - Learning Mode API

    /// Enable learning mode - gestures will be recognized but not executed
    /// The callback receives (gestureName, actionName) for each recognized gesture
    func enableLearningMode(callback: @escaping (String, String) -> Void) {
        isLearningMode = true
        learningModeCallback = callback
        #if DEBUG
        print("[GestureEngine] Learning mode enabled")
        #endif
    }

    /// Disable learning mode - return to normal gesture execution
    func disableLearningMode() {
        isLearningMode = false
        learningModeCallback = nil
        #if DEBUG
        print("[GestureEngine] Learning mode disabled")
        #endif
    }

    // MARK: - Rule Matching

    /// Find matching rule using RuleManager (supports app-specific rules)
    private func findRule(for trigger: GestureTrigger) -> GestureRule? {
        return ruleManager.findMatchingRule(trigger: trigger)
    }

    /// Get action for a swipe gesture (rule-based with fallback)
    private func getSwipeAction(fingerCount: Int, direction: SwipeDirection) -> WindowAction {
        let trigger = GestureTrigger.swipe(fingers: fingerCount, direction: direction)

        // Try rule-based lookup first
        if let rule = findRule(for: trigger), rule.isEnabled {
            return rule.action
        }

        // Fallback to legacy configuration (for backward compatibility)
        let mapping = config.swipeMapping(for: fingerCount)
        return mapping.action(for: direction)
    }

    /// Get action for a pinch gesture (rule-based with fallback)
    private func getPinchAction(direction: PinchDirection) -> WindowAction {
        let trigger = GestureTrigger.pinch(direction: direction)

        // Try rule-based lookup first
        if let rule = findRule(for: trigger), rule.isEnabled {
            return rule.action
        }

        // Fallback to legacy configuration
        return config.pinchGestures.action(for: direction)
    }

    /// Get action for a tap gesture (rule-based with fallback)
    private func getTapAction(fingerCount: Int, tapType: TapType) -> WindowAction {
        let trigger = GestureTrigger.tap(fingers: fingerCount, tapType: tapType)

        // Try rule-based lookup first
        if let rule = findRule(for: trigger), rule.isEnabled {
            return rule.action
        }

        // Fallback to legacy configuration
        let mapping = config.tapMapping(for: fingerCount)
        return mapping.action(for: tapType)
    }

    /// Check if there are any enabled rules
    private var hasEnabledRules: Bool {
        return !ruleManager.enabledRules.isEmpty
    }

    /// Check if tap gestures are enabled (via rules or legacy config)
    private var isTapEnabled: Bool {
        // Check if any tap rules exist
        let hasTapRules = ruleManager.enabledRules.contains { $0.trigger.type == .tap }
        return hasTapRules || config.tapEnabled
    }

    /// Check if pinch gestures are enabled (via rules or legacy config)
    private var isPinchEnabled: Bool {
        let hasPinchRules = ruleManager.enabledRules.contains { $0.trigger.type == .pinch }
        return hasPinchRules || config.pinchEnabled
    }

    /// Check if finger count has any enabled rules
    private func isFingerCountEnabled(_ count: Int) -> Bool {
        let hasRulesForCount = ruleManager.enabledRules.contains { $0.trigger.fingerCount == count }
        return hasRulesForCount || config.enabledFingerCounts.contains(count)
    }

    // MARK: - Process Frame

    func processFrame(timestamp: Double, touches: [MTTouch]) {
        // Handle empty frame (all fingers lifted)
        if touches.isEmpty {
            if state == .began || state == .changed {
                finalizeGesture()
            } else if isTapCandidate && isTapEnabled && peakTouchingFingers > 0 {
                // Check if this was a tap (minimal movement, short duration)
                let touchDuration = timestamp - touchDownTime
                if totalMovement < tapMovementThreshold && touchDuration < tapMaxDuration {
                    // Use peak finger count for tap detection
                    fingerCount = peakTouchingFingers
                    #if DEBUG
                    print("[GestureEngine] Tap candidate: \(fingerCount)F, duration: \(String(format: "%.3f", touchDuration))s, movement: \(totalMovement)")
                    #endif
                    handleTapDetected(timestamp: timestamp)
                }
            }
            resetState()
            return
        }

        // Track peak finger count during this touch sequence
        if touches.count > peakTouchingFingers {
            peakTouchingFingers = touches.count
        }

        fingerCount = touches.count

        // Check if this finger count is enabled
        guard fingerCount > 0 && isFingerCountEnabled(fingerCount) else {
            // Silently ignore - let system handle it
            if state != .possible {
                resetState()
            }
            return
        }

        // Calculate centroid
        let centroid = calculateCentroid(touches)
        previousCentroid = currentCentroid
        currentCentroid = centroid

        // Calculate velocity
        if lastFrameTime > 0 {
            let dt = Float(timestamp - lastFrameTime)
            if dt > 0, let prev = previousCentroid {
                velocityX = (centroid.x - prev.x) / dt
                velocityY = (centroid.y - prev.y) / dt
            }
        }
        lastFrameTime = timestamp

        // State machine
        switch state {
        case .possible:
            handlePossibleState(centroid: centroid, touches: touches, timestamp: timestamp)

        case .began, .changed:
            handleActiveState(centroid: centroid, touches: touches, timestamp: timestamp)

        case .ended, .cancelled:
            break
        }
    }

    // MARK: - State Handlers

    private func handlePossibleState(centroid: MTVector, touches: [MTTouch], timestamp: Double) {
        // Initialize tracking
        if initialCentroid == nil {
            initialCentroid = centroid
            gestureStartTime = timestamp
            touchDownTime = timestamp
            totalMovement = 0
            isTapCandidate = true

            // Calculate initial pinch distance (only for 2 fingers)
            if fingerCount == 2 && isPinchEnabled {
                initialPinchDistance = calculateAverageDistance(touches)
            }
        }

        guard let start = initialCentroid else { return }

        let dx = centroid.x - start.x
        let dy = centroid.y - start.y
        let distance = sqrt(dx * dx + dy * dy)

        // Track total movement for tap detection
        if let prev = previousCentroid {
            let moveDx = centroid.x - prev.x
            let moveDy = centroid.y - prev.y
            totalMovement += sqrt(moveDx * moveDx + moveDy * moveDy)
        }

        // Check for pinch change (2 fingers only, using touching fingers)
        if fingerCount == 2 && isPinchEnabled && initialPinchDistance > 0 {
            let currentDistance = calculateAverageDistance(touches)
            let pinchRatio = currentDistance / initialPinchDistance

            if pinchRatio < 0.80 || pinchRatio > 1.25 {
                state = .began
                isTapCandidate = false  // Not a tap - it's a pinch
                #if DEBUG
                print("[GestureEngine] Pinch detected, ratio: \(pinchRatio)")
                #endif
                return
            }
        }

        // Check for movement threshold
        if distance > gestureStartThreshold {
            state = .began
            isTapCandidate = false  // Not a tap - it's a swipe
            lockedDirection = determineSwipeDirection(dx: dx, dy: dy)
            #if DEBUG
            print("[GestureEngine] Swipe began, direction: \(lockedDirection?.displayName ?? "unknown"), distance: \(distance)")
            #endif
        }
    }

    private func handleActiveState(centroid: MTVector, touches: [MTTouch], timestamp: Double) {
        state = .changed

        guard let start = initialCentroid else { return }

        // Check gesture timeout
        if timestamp - gestureStartTime > gestureTimeout {
            #if DEBUG
            print("[GestureEngine] Gesture timeout, resetting")
            #endif
            resetState()
            return
        }

        // Check cooldown
        if timestamp - lastActionTime < gestureCooldown {
            return
        }

        let dx = centroid.x - start.x
        let dy = centroid.y - start.y
        let distance = sqrt(dx * dx + dy * dy)

        // Get threshold from config
        let baseThreshold = Float(config.swipeThreshold)

        // Calculate effective threshold based on velocity
        let velocity = sqrt(velocityX * velocityX + velocityY * velocityY)
        let effectiveThreshold = velocity > minSwipeVelocity
            ? baseThreshold * fastSwipeMultiplier
            : baseThreshold

        // Check for pinch gesture first (2 fingers only)
        if fingerCount == 2 && isPinchEnabled && initialPinchDistance > 0 {
            let currentDistance = calculateAverageDistance(touches)
            let pinchRatio = currentDistance / initialPinchDistance

            // Pinch in
            if pinchRatio < Float(config.pinchInThreshold) {
                let action = getPinchAction(direction: .pinchIn)
                #if DEBUG
                print("[GestureEngine] Pinch in triggered, ratio: \(pinchRatio), action: \(action)")
                #endif
                executeAction(action, timestamp: timestamp, gestureName: "捏合")
                return
            }

            // Pinch out
            if pinchRatio > Float(config.pinchOutThreshold) {
                let action = getPinchAction(direction: .pinchOut)
                #if DEBUG
                print("[GestureEngine] Pinch out triggered, ratio: \(pinchRatio), action: \(action)")
                #endif
                executeAction(action, timestamp: timestamp, gestureName: "张开")
                return
            }
        }

        // Check for swipe
        if distance > effectiveThreshold * 0.6 {
            // Determine current direction
            let currentDirection = determineSwipeDirection(dx: dx, dy: dy)

            // Direction unlock: allow updating locked direction if user significantly changed direction
            if let locked = lockedDirection, distance > directionConfirmDistance {
                let angleDiff = angleDifference(from: locked, to: currentDirection)
                if angleDiff > directionUnlockAngle {
                    lockedDirection = currentDirection
                    #if DEBUG
                    print("[GestureEngine] Direction unlocked: \(locked.displayName) -> \(currentDirection.displayName), angleDiff: \(angleDiff)°")
                    #endif
                }
            }

            // Use locked direction if available, otherwise use current
            let direction = lockedDirection ?? currentDirection
            let action = getSwipeAction(fingerCount: fingerCount, direction: direction)

            if let snapDir = action.snapDirection {
                showPreview(for: snapDir)
            }

            // Execute when threshold fully met
            if distance > effectiveThreshold {
                let gestureName = "\(fingerCount)指\(direction.displayName)滑"
                #if DEBUG
                print("[GestureEngine] Swipe executed: \(fingerCount)F \(direction.displayName) -> \(action), distance: \(distance), threshold: \(effectiveThreshold)")
                #endif
                executeAction(action, timestamp: timestamp, gestureName: gestureName)
            }
        }
    }

    // MARK: - Direction Detection

    private func determineSwipeDirection(dx: Float, dy: Float) -> SwipeDirection {
        let absDx = abs(dx)
        let absDy = abs(dy)

        guard max(absDx, absDy) > 0 else { return .right }

        // Calculate angle for precise detection
        let angle = atan2(dy, dx) * 180 / .pi  // -180 to 180

        // 8-direction detection based on angle sectors (45° each)
        if angle >= -22.5 && angle < 22.5 {
            return .right
        } else if angle >= 22.5 && angle < 67.5 {
            return .topRight
        } else if angle >= 67.5 && angle < 112.5 {
            return .up
        } else if angle >= 112.5 && angle < 157.5 {
            return .topLeft
        } else if angle >= 157.5 || angle < -157.5 {
            return .left
        } else if angle >= -157.5 && angle < -112.5 {
            return .bottomLeft
        } else if angle >= -112.5 && angle < -67.5 {
            return .down
        } else {
            return .bottomRight
        }
    }

    /// Get the angle (in degrees) for a SwipeDirection
    private func angleForDirection(_ direction: SwipeDirection) -> Float {
        switch direction {
        case .right: return 0
        case .topRight: return 45
        case .up: return 90
        case .topLeft: return 135
        case .left: return 180
        case .bottomLeft: return -135
        case .down: return -90
        case .bottomRight: return -45
        }
    }

    /// Calculate the absolute angle difference between two directions (0-180)
    private func angleDifference(from dir1: SwipeDirection, to dir2: SwipeDirection) -> Float {
        let angle1 = angleForDirection(dir1)
        let angle2 = angleForDirection(dir2)
        var diff = abs(angle1 - angle2)
        if diff > 180 {
            diff = 360 - diff
        }
        return diff
    }

    // MARK: - Preview

    private func showPreview(for direction: SnapDirection) {
        // If same as current, nothing to do
        guard direction != currentPreviewDirection else {
            pendingPreviewDirection = nil
            previewDebounceTimer?.invalidate()
            return
        }

        // If same as pending, let the timer continue
        if direction == pendingPreviewDirection {
            return
        }

        // Set pending direction and start debounce timer
        pendingPreviewDirection = direction
        previewDebounceTimer?.invalidate()

        // Use main thread for timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.previewDebounceTimer = Timer.scheduledTimer(withTimeInterval: self.previewDebounceInterval, repeats: false) { [weak self] _ in
                guard let self = self,
                      let pending = self.pendingPreviewDirection else { return }

                self.currentPreviewDirection = pending
                self.pendingPreviewDirection = nil
                FeedbackHUD.shared.showSnapPreview(direction: pending)
            }
        }
    }

    private func hidePreview() {
        previewDebounceTimer?.invalidate()
        previewDebounceTimer = nil
        pendingPreviewDirection = nil
        currentPreviewDirection = nil
        FeedbackHUD.shared.hideSnapPreview()
    }

    // MARK: - Action Execution

    private func executeAction(_ action: WindowAction, timestamp: Double, ruleId: UUID? = nil, gestureName: String? = nil) {
        guard action != .none else { return }

        // Hide preview
        hidePreview()

        // Learning mode: show feedback but don't execute
        if isLearningMode {
            let gesture = gestureName ?? "手势"
            let actionName = action.displayName
            learningModeCallback?(gesture, actionName)
            FeedbackHUD.shared.flashAction(text: "✓ \(gesture) → \(actionName)")
            lastActionTime = timestamp
            resetState()
            return
        }

        // Show action feedback
        FeedbackHUD.shared.flashAction(text: action.shortName)

        // Execute the action based on category
        switch action {
        // Window Layout actions - use WindowManager
        case .snapLeft, .snapRight, .snapTop, .snapBottom,
             .snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight,
             .maximize, .center, .restore:
            if let direction = action.snapDirection {
                WindowManager.shared.snapFocusedWindow(direction: direction)
            }

        // Basic window control - use WindowManager
        case .minimize:
            WindowManager.shared.minimizeFocusedWindow()

        case .close:
            WindowManager.shared.closeFocusedWindow()

        case .fullscreen:
            WindowManager.shared.toggleFullscreen()

        case .undo:
            WindowManager.shared.undoLastOperation()

        // Extended window control - use SystemActionsManager
        case .maximizeHeight, .maximizeWidth, .minimizeAll, .restoreAllMinimized:
            SystemActionsManager.shared.execute(action)

        // Multi-monitor & Spaces
        case .moveToNextScreen:
            WindowManager.shared.moveToNextScreen()

        case .moveToPrevScreen:
            WindowManager.shared.moveToPrevScreen()

        case .spaceLeft, .spaceRight, .moveToNextSpace, .moveToPrevSpace:
            SystemActionsManager.shared.execute(action)

        // Desktop & System actions - use SystemActionsManager
        case .missionControl, .showDesktop, .appExpose, .launchpad,
             .spotlight, .lockScreen, .startScreensaver:
            SystemActionsManager.shared.execute(action)

        // Application control - use SystemActionsManager
        case .quitApp, .hideApp, .hideOthers, .switchApp, .previousApp:
            SystemActionsManager.shared.execute(action)

        // Tab control - use SystemActionsManager
        case .newTab, .closeTab, .nextTab, .prevTab:
            SystemActionsManager.shared.execute(action)

        // Media control - use SystemActionsManager
        case .playPause, .nextTrack, .prevTrack, .volumeUp, .volumeDown, .volumeMute:
            SystemActionsManager.shared.execute(action)

        // Brightness control - use SystemActionsManager
        case .brightnessUp, .brightnessDown:
            SystemActionsManager.shared.execute(action)

        // Screenshot - use SystemActionsManager
        case .screenshot, .screenshotArea, .screenshotWindow:
            SystemActionsManager.shared.execute(action)

        // Custom shortcut - use SystemActionsManager with ruleId
        case .customShortcut:
            SystemActionsManager.shared.execute(action, ruleId: ruleId)

        case .none:
            break
        }

        lastActionTime = timestamp
        finalizeGesture()
    }

    // MARK: - Tap Detection

    private func handleTapDetected(timestamp: Double) {
        #if DEBUG
        let detectTime = CACurrentMediaTime()
        #endif

        // Check if this tap continues a sequence (same finger count, within timeout)
        if fingerCount == lastTapFingerCount &&
           timestamp - lastTapTime < tapSequenceTimeout {
            tapCount += 1
        } else {
            // New tap sequence
            tapCount = 1
        }

        lastTapTime = timestamp
        lastTapFingerCount = fingerCount

        // Cancel any pending tap timer
        tapTimer?.invalidate()
        tapTimer = nil

        // Get actions for all tap types to determine execution strategy
        let singleTapAction = getTapAction(fingerCount: fingerCount, tapType: .singleTap)
        let doubleTapAction = getTapAction(fingerCount: fingerCount, tapType: .doubleTap)
        let tripleTapAction = getTapAction(fingerCount: fingerCount, tapType: .tripleTap)

        #if DEBUG
        print("[GestureEngine] Tap detected: \(fingerCount)F, count=\(tapCount), actions: single=\(singleTapAction), double=\(doubleTapAction), triple=\(tripleTapAction)")
        #endif

        switch tapCount {
        case 1:
            // Single tap: check if we need to wait for double/triple
            if doubleTapAction == .none && tripleTapAction == .none {
                // No multi-tap configured, execute immediately
                executeTapAction(for: .singleTap, timestamp: timestamp)
                tapCount = 0
            } else {
                // Wait for potential follow-up
                scheduleTapExecution(tapType: .singleTap, fingerCount: fingerCount, timestamp: timestamp)
            }

        case 2:
            // Double tap: check if we need to wait for triple
            if tripleTapAction == .none {
                // No triple-tap configured, execute double-tap immediately
                #if DEBUG
                print("[GestureEngine] Executing double-tap immediately (no triple configured)")
                #endif
                executeTapAction(for: .doubleTap, timestamp: timestamp)
                tapCount = 0
            } else {
                // Wait for potential third tap
                scheduleTapExecution(tapType: .doubleTap, fingerCount: fingerCount, timestamp: timestamp)
            }

        case 3:
            // Triple tap: execute immediately
            executeTapAction(for: .tripleTap, timestamp: timestamp)
            tapCount = 0

        default:
            // Beyond triple, treat as triple
            executeTapAction(for: .tripleTap, timestamp: timestamp)
            tapCount = 0
        }

        #if DEBUG
        let endTime = CACurrentMediaTime()
        print("[GestureEngine] Tap handling took \(String(format: "%.2f", (endTime - detectTime) * 1000))ms")
        #endif
    }

    private func scheduleTapExecution(tapType: TapType, fingerCount: Int, timestamp: Double) {
        tapTimer?.invalidate()
        tapTimer = nil

        let capturedTapCount = tapCount
        let capturedFingerCount = fingerCount

        // Show waiting indicator if there might be more taps coming
        // Only show if double/triple tap actions are configured
        let hasDoubleTapAction = getTapAction(fingerCount: fingerCount, tapType: .doubleTap) != .none
        let hasTripleTapAction = getTapAction(fingerCount: fingerCount, tapType: .tripleTap) != .none

        if (capturedTapCount == 1 && hasDoubleTapAction) || (capturedTapCount == 2 && hasTripleTapAction) {
            let waitingText = capturedTapCount == 1 ? "等待更多点击..." : "等待第三次点击..."
            FeedbackHUD.shared.showWaitingIndicator(text: waitingText)
        }

        // Timer must be scheduled on main thread to work reliably
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.tapTimer = Timer.scheduledTimer(withTimeInterval: self.tapSequenceTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                // Hide waiting indicator
                FeedbackHUD.shared.hideWaitingIndicator()

                #if DEBUG
                print("[GestureEngine] Tap timer fired, executing tap count: \(capturedTapCount)")
                #endif

                // Execute the highest completed tap type
                let finalTapType: TapType
                switch capturedTapCount {
                case 3:
                    finalTapType = .tripleTap
                case 2:
                    finalTapType = .doubleTap
                default:
                    finalTapType = .singleTap
                }

                self.lastTapFingerCount = capturedFingerCount
                self.executeTapAction(for: finalTapType, timestamp: CACurrentMediaTime())
                self.tapCount = 0
            }
        }
    }

    private func executeTapAction(for tapType: TapType, timestamp: Double) {
        let action = getTapAction(fingerCount: lastTapFingerCount, tapType: tapType)

        guard action != .none else { return }

        // Check cooldown
        guard timestamp - lastActionTime >= gestureCooldown else { return }

        // Build gesture name for learning mode
        let gestureName = "\(lastTapFingerCount)指\(tapType.displayName)"

        // Show feedback
        FeedbackHUD.shared.flashAction(text: "\(lastTapFingerCount)F \(tapType.shortName)")

        // Execute action
        executeAction(action, timestamp: timestamp, gestureName: gestureName)
    }

    // MARK: - Utility

    private func calculateCentroid(_ touches: [MTTouch]) -> MTVector {
        var sumX: Float = 0
        var sumY: Float = 0

        for touch in touches {
            sumX += touch.normalizedVector.x
            sumY += touch.normalizedVector.y
        }

        let count = Float(touches.count)
        return MTVector(x: sumX / count, y: sumY / count)
    }

    private func calculateAverageDistance(_ touches: [MTTouch]) -> Float {
        guard touches.count >= 2 else { return 0 }

        var totalDistance: Float = 0
        var pairs = 0

        for i in 0..<touches.count {
            for j in (i+1)..<touches.count {
                let dx = touches[i].normalizedVector.x - touches[j].normalizedVector.x
                let dy = touches[i].normalizedVector.y - touches[j].normalizedVector.y
                totalDistance += sqrt(dx * dx + dy * dy)
                pairs += 1
            }
        }

        return pairs > 0 ? totalDistance / Float(pairs) : 0
    }

    private func finalizeGesture() {
        state = .ended
        hidePreview()
    }

    private func resetState() {
        state = .possible
        initialCentroid = nil
        currentCentroid = nil
        previousCentroid = nil
        lockedDirection = nil
        initialPinchDistance = 0
        fingerCount = 0
        velocityX = 0
        velocityY = 0
        currentPreviewDirection = nil

        // Reset tap candidate state (but not tap sequence tracking)
        isTapCandidate = false
        totalMovement = 0
        peakTouchingFingers = 0
        wasAllTouching = false

        FeedbackHUD.shared.clear()
    }

    // MARK: - Public API

    func reset() {
        tapTimer?.invalidate()
        tapTimer = nil
        tapCount = 0
        resetState()
    }

    var isActive: Bool {
        return state == .began || state == .changed
    }
}
