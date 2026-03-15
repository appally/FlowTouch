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

private enum GestureKind {
    case swipe
    case pinch
}

// MARK: - Gesture Engine (Rule-Based)

class GestureEngine {
    static let shared = GestureEngine()

    private let processingQueue = DispatchQueue(label: "FlowTouch.GestureEngine", qos: .userInteractive)
    private let queueKey = DispatchSpecificKey<Void>()
    private let actionQueue = DispatchQueue(label: "FlowTouch.GestureEngine.actions", qos: .userInitiated)

    private init() {
        processingQueue.setSpecific(key: queueKey, value: ())
    }

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
    private var lockedFingerCount: Int = 0
    private var activeGestureKind: GestureKind?
    private var activeDevice: MTDeviceRef?

    // Tracking
    private var initialCentroid: MTVector?
    private var currentCentroid: MTVector?
    private var previousCentroid: MTVector?
    private var lockedDirection: SwipeDirection?
    private var referenceTouchPositions: [MTVector] = []
    private var smoothedTranslation: MTVector?
    private var maxDisplacementFromStart: Float = 0
    private var lastSwipeVector = MTVector(x: 0, y: 0)
    private var lastSwipeDistance: Float = 0
    private var lastResolvedSwipeDirection: SwipeDirection?
    private var lastSwipeExecutionThreshold: Float = 0
    private var didExecuteGestureAction = false

    // Pinch tracking
    private var initialPinchDistance: Float = 0
    private var lastPinchRatio: Float = 1

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
    private var previewDebounceTimer: DispatchSourceTimer?
    private let previewDebounceInterval: TimeInterval = 0.08  // 80ms debounce
    private var releaseDebounceTimer: DispatchSourceTimer?

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
    private var tapTimer: DispatchSourceTimer?
    private var peakTouchingFingers: Int = 0  // Track max fingers during touch
    private var wasAllTouching: Bool = false   // Track if all fingers were touching

    // Constants
    private let gestureStartThreshold: Float = 0.04
    private let gestureCooldown: TimeInterval = 0.25  // Further reduced for taps
    private let gestureTimeout: TimeInterval = 1.5
    private let minSwipeVelocity: Float = 0.3
    private let fastSwipeMultiplier: Float = 0.7
    private let swipeDirectionSmoothingFactor: Float = 0.35
    private let swipeReleaseCompletionRatio: Float = 0.92
    private let pinchReleaseTolerance: Float = 0.04
    private let releaseDebounceInterval: TimeInterval = 0.012

    // Tap constants
    private let tapMovementThreshold: Float = 0.045  // Base threshold for 1–2 finger taps
    private let tapMaxDuration: TimeInterval = 0.40  // Allow slightly longer taps (increased from 0.35)
    private let tapCooldown: TimeInterval = 0.12

    private var tapSequenceTimeout: TimeInterval {
        min(max(config.tapTimeout, 0.18), 0.45)
    }

    /// Movement threshold scaled for multi-finger taps. 3+ fingers cause larger centroid shifts when lifting.
    private func effectiveTapMovementThreshold(for fingerCount: Int) -> Float {
        guard fingerCount >= 3 else { return tapMovementThreshold }
        let scale = 1.0 + Float(fingerCount - 2) * 0.25  // 3F: 1.25x, 4F: 1.5x, 5F: 1.75x
        return tapMovementThreshold * scale
    }

    // Direction unlock constants
    private let directionUnlockAngle: Float = 60  // Degrees: allow direction change if angle diff > this
    private let directionConfirmDistance: Float = 0.06  // Minimum distance before allowing direction update

    // MARK: - Learning Mode API

    /// Enable learning mode - gestures will be recognized but not executed
    /// The callback receives (gestureName, actionName) for each recognized gesture
    func enableLearningMode(callback: @escaping (String, String) -> Void) {
        asyncOnQueue { [weak self] in
            guard let self = self else { return }
            self.isLearningMode = true
            self.learningModeCallback = callback
            #if DEBUG
            print("[GestureEngine] Learning mode enabled")
            #endif
        }
    }

    /// Disable learning mode - return to normal gesture execution
    func disableLearningMode() {
        asyncOnQueue { [weak self] in
            guard let self = self else { return }
            self.isLearningMode = false
            self.learningModeCallback = nil
            #if DEBUG
            print("[GestureEngine] Learning mode disabled")
            #endif
        }
    }

    // MARK: - Rule Matching

    /// Find matching rule using RuleManager (supports app-specific rules)
    private func findRule(for trigger: GestureTrigger) -> GestureRule? {
        return ruleManager.findMatchingRule(trigger: trigger)
    }

    private typealias ResolvedAction = (action: WindowAction, ruleId: UUID?)

    /// Get action for a swipe gesture (rule-based with fallback)
    private func getSwipeAction(fingerCount: Int, direction: SwipeDirection) -> ResolvedAction {
        let trigger = GestureTrigger.swipe(fingers: fingerCount, direction: direction)

        // Try rule-based lookup first
        if let rule = findRule(for: trigger), rule.isEnabled {
            return (rule.action, rule.id)
        }

        guard shouldUseLegacyConfiguration else {
            return (.none, nil)
        }

        // Fallback to legacy configuration (for backward compatibility)
        let mapping = config.swipeMapping(for: fingerCount)
        return (mapping.action(for: direction), nil)
    }

    /// Get action for a pinch gesture (rule-based with fallback)
    private func getPinchAction(direction: PinchDirection) -> ResolvedAction {
        let trigger = GestureTrigger.pinch(direction: direction)

        // Try rule-based lookup first
        if let rule = findRule(for: trigger), rule.isEnabled {
            return (rule.action, rule.id)
        }

        guard shouldUseLegacyConfiguration else {
            return (.none, nil)
        }

        // Fallback to legacy configuration
        return (config.pinchGestures.action(for: direction), nil)
    }

    /// Get action for a tap gesture (rule-based with fallback)
    /// Returns (action, ruleId) tuple - ruleId is needed for customShortcut actions
    private func getTapAction(fingerCount: Int, tapType: TapType) -> ResolvedAction {
        let trigger = GestureTrigger.tap(fingers: fingerCount, tapType: tapType)

        // Try rule-based lookup first
        if let rule = findRule(for: trigger), rule.isEnabled {
            return (rule.action, rule.id)
        }

        guard shouldUseLegacyConfiguration else {
            return (.none, nil)
        }

        // Fallback to legacy configuration
        let mapping = config.tapMapping(for: fingerCount)
        return (mapping.action(for: tapType), nil)
    }

    /// Legacy configuration should only be used when no rule has been created yet.
    private var shouldUseLegacyConfiguration: Bool {
        ruleManager.rules.isEmpty
    }

    /// Check if tap gestures are enabled (via rules or legacy config)
    private var isTapEnabled: Bool {
        // Check if any tap rules exist
        let hasTapRules = ruleManager.enabledRules.contains { $0.trigger.type == .tap }
        guard shouldUseLegacyConfiguration else { return hasTapRules }
        let hasConfiguredTap = (config.twoFingerTap.configuredCount +
                                config.threeFingerTap.configuredCount +
                                config.fourFingerTap.configuredCount) > 0
        return hasTapRules || config.tapEnabled || hasConfiguredTap
    }

    /// Check if pinch gestures are enabled (via rules or legacy config)
    private var isPinchEnabled: Bool {
        let hasPinchRules = ruleManager.enabledRules.contains { $0.trigger.type == .pinch }
        guard shouldUseLegacyConfiguration else { return hasPinchRules }
        return hasPinchRules || config.pinchEnabled
    }

    /// Check if finger count has any enabled rules
    private func isFingerCountEnabled(_ count: Int) -> Bool {
        let hasRulesForCount = ruleManager.enabledRules.contains { $0.trigger.fingerCount == count }
        if hasRulesForCount { return true }
        guard shouldUseLegacyConfiguration else { return false }
        if config.enabledFingerCounts.contains(count) { return true }
        if config.swipeMapping(for: count).configuredCount > 0 { return true }
        if config.tapMapping(for: count).configuredCount > 0 { return true }
        if count == 2 && isPinchEnabled { return true }
        return false
    }

    private func isSwipeEnabled(for count: Int) -> Bool {
        let hasSwipeRules = ruleManager.enabledRules.contains { $0.trigger.type == .swipe && $0.trigger.fingerCount == count }
        guard shouldUseLegacyConfiguration else { return hasSwipeRules }
        return hasSwipeRules || config.swipeMapping(for: count).configuredCount > 0
    }

    private func cancelTapSequence() {
        tapTimer?.cancel()
        tapTimer = nil
        tapCount = 0
        lastTapTime = 0
        lastTapFingerCount = 0
    }

    // MARK: - Process Frame

    func processFrame(device: MTDeviceRef, timestamp: Double, touches: [MTTouch]) {
        asyncOnQueue { [weak self] in
            self?.processFrameInternal(device: device, timestamp: timestamp, touches: touches)
        }
    }

    private func processFrameInternal(device: MTDeviceRef, timestamp: Double, touches: [MTTouch]) {
        if let activeDevice, activeDevice != device {
            return
        }

        // Handle empty frame (all fingers lifted)
        if touches.isEmpty {
            guard activeDevice != nil else { return }
            scheduleReleaseConfirmation(timestamp: timestamp)
            return
        }

        cancelReleaseConfirmation()

        if activeDevice == nil {
            activeDevice = device
        }

        // Track peak finger count during this touch sequence
        if touches.count > peakTouchingFingers {
            peakTouchingFingers = touches.count
        }

        fingerCount = touches.count

        // Check if this finger count is enabled (tolerate brief count drops)
        let currentEnabled = isFingerCountEnabled(fingerCount)
        let peakEnabled = peakTouchingFingers > 0 && isFingerCountEnabled(peakTouchingFingers)
        guard fingerCount > 0 && (currentEnabled || peakEnabled) else {
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
                let instantaneousX = (centroid.x - prev.x) / dt
                let instantaneousY = (centroid.y - prev.y) / dt
                velocityX = velocityX == 0 ? instantaneousX : (velocityX * 0.65) + (instantaneousX * 0.35)
                velocityY = velocityY == 0 ? instantaneousY : (velocityY * 0.65) + (instantaneousY * 0.35)
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
        let needsRebase = initialCentroid == nil || referenceTouchPositions.count != fingerCount
        if needsRebase {
            rebaseTrackingReference(centroid: centroid, touches: touches, timestamp: timestamp)
            return
        }

        let translation = calculateGestureTranslation(for: touches, fallbackCentroid: centroid)
        let dx = translation.x
        let dy = translation.y
        let distance = sqrt(dx * dx + dy * dy)
        maxDisplacementFromStart = max(maxDisplacementFromStart, distance)

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
            lastPinchRatio = pinchRatio

            if pinchRatio < 0.80 || pinchRatio > 1.25 {
                cancelTapSequence()
                state = .began
                activeGestureKind = .pinch
                lockedFingerCount = fingerCount
                isTapCandidate = false  // Not a tap - it's a pinch
                #if DEBUG
                print("[GestureEngine] Pinch detected, ratio: \(pinchRatio)")
                #endif
                return
            }
        }

        // Check for movement threshold (favor tap if swipe isn't configured)
        let tapThreshold = effectiveTapMovementThreshold(for: max(fingerCount, peakTouchingFingers))
        let dynamicStartThreshold = max(gestureStartThreshold, Float(config.swipeThreshold) * 0.55)
        let swipeStartThreshold = isTapCandidate ? max(dynamicStartThreshold, tapThreshold) : dynamicStartThreshold
        if isSwipeEnabled(for: fingerCount) && distance > swipeStartThreshold {
            cancelTapSequence()
            state = .began
            activeGestureKind = .swipe
            lockedFingerCount = fingerCount
            isTapCandidate = false  // Not a tap - it's a swipe
            lastSwipeVector = translation
            lastSwipeDistance = distance
            lastResolvedSwipeDirection = determineSwipeDirection(dx: dx, dy: dy, fingerCount: lockedFingerCount)
            #if DEBUG
            print("[GestureEngine] Swipe began, direction: \(lastResolvedSwipeDirection?.displayName ?? "unknown"), distance: \(distance)")
            #endif
        }
    }

    private func handleActiveState(centroid: MTVector, touches: [MTTouch], timestamp: Double) {
        state = .changed

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

        let gestureFingerCount = lockedFingerCount > 0 ? lockedFingerCount : fingerCount
        let translation = calculateGestureTranslation(for: touches, fallbackCentroid: centroid)
        let smoothed = smoothSwipeTranslation(translation)
        let dx = translation.x
        let dy = translation.y
        let distance = sqrt(dx * dx + dy * dy)
        lastSwipeVector = translation
        lastSwipeDistance = distance

        // Get threshold from config
        let baseThreshold = Float(config.swipeThreshold)

        // Calculate effective threshold based on velocity
        let velocity = sqrt(velocityX * velocityX + velocityY * velocityY)
        let effectiveThreshold = velocity > minSwipeVelocity
            ? baseThreshold * fastSwipeMultiplier
            : baseThreshold
        lastSwipeExecutionThreshold = effectiveThreshold

        if activeGestureKind == .pinch && gestureFingerCount == 2 && isPinchEnabled && initialPinchDistance > 0 {
            let currentDistance = calculateAverageDistance(touches)
            let pinchRatio = currentDistance / initialPinchDistance
            lastPinchRatio = pinchRatio

            // Pinch in
            if pinchRatio < Float(config.pinchInThreshold) {
                cancelTapSequence()
                let action = getPinchAction(direction: .pinchIn)
                #if DEBUG
                print("[GestureEngine] Pinch in triggered, ratio: \(pinchRatio), action: \(action.action)")
                #endif
                executeAction(action.action, timestamp: timestamp, ruleId: action.ruleId, gestureName: "捏合")
                return
            }

            // Pinch out
            if pinchRatio > Float(config.pinchOutThreshold) {
                cancelTapSequence()
                let action = getPinchAction(direction: .pinchOut)
                #if DEBUG
                print("[GestureEngine] Pinch out triggered, ratio: \(pinchRatio), action: \(action.action)")
                #endif
                executeAction(action.action, timestamp: timestamp, ruleId: action.ruleId, gestureName: "张开")
                return
            }

            return
        }

        // Check for swipe
        guard activeGestureKind != .pinch else { return }
        if isSwipeEnabled(for: gestureFingerCount) && distance > effectiveThreshold * 0.55 {
            // Determine current direction
            let currentDirection = determineSwipeDirection(
                dx: smoothed.x,
                dy: smoothed.y,
                fingerCount: gestureFingerCount
            )
            lastResolvedSwipeDirection = currentDirection

            if lockedDirection == nil && distance >= directionConfirmDistance {
                lockedDirection = currentDirection
            }

            // Direction unlock: allow updating locked direction if user significantly changed direction
            if let locked = lockedDirection, distance > directionConfirmDistance {
                let angleDiff = angleDifference(from: locked, to: currentDirection)
                let lockedAction = getSwipeAction(fingerCount: gestureFingerCount, direction: locked)
                let currentAction = getSwipeAction(fingerCount: gestureFingerCount, direction: currentDirection)
                let shouldUnlock = angleDiff > directionUnlockAngle ||
                    (lockedAction.action == .none && currentAction.action != .none)
                if shouldUnlock {
                    lockedDirection = currentDirection
                    #if DEBUG
                    print("[GestureEngine] Direction unlocked: \(locked.displayName) -> \(currentDirection.displayName), angleDiff: \(angleDiff)°")
                    #endif
                }
            }

            // Use locked direction if available, otherwise use current
            let direction = lockedDirection ?? currentDirection
            let action = getSwipeAction(fingerCount: gestureFingerCount, direction: direction)

            if let snapDir = action.action.snapDirection {
                showPreview(for: snapDir)
            } else {
                hidePreview()
            }

            // Execute when threshold fully met
            if distance > effectiveThreshold {
                let gestureName = String(
                    format: L("gesture_swipe_format"),
                    gestureFingerCount,
                    direction.displayName
                )
                #if DEBUG
                print("[GestureEngine] Swipe executed: \(gestureFingerCount)F \(direction.displayName) -> \(action.action), distance: \(distance), threshold: \(effectiveThreshold)")
                #endif
                executeAction(action.action, timestamp: timestamp, ruleId: action.ruleId, gestureName: gestureName)
            }
        }
    }

    // MARK: - Direction Detection

    private func determineSwipeDirection(dx: Float, dy: Float, fingerCount: Int) -> SwipeDirection {
        let absDx = abs(dx)
        let absDy = abs(dy)

        guard max(absDx, absDy) > 0 else { return .right }

        // Calculate angle for precise detection
        let angle = atan2(dy, dx) * 180 / .pi  // -180 to 180
        let candidates = availableSwipeDirections(for: fingerCount)
        return candidates.min {
            angularDifference(from: angle, to: angleForDirection($0)) <
                angularDifference(from: angle, to: angleForDirection($1))
        } ?? .right
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
        return angularDifference(from: angle1, to: angle2)
    }

    private func angularDifference(from angle1: Float, to angle2: Float) -> Float {
        var diff = abs(angle1 - angle2)
        if diff > 180 {
            diff = 360 - diff
        }
        return diff
    }

    private func availableSwipeDirections(for fingerCount: Int) -> [SwipeDirection] {
        let configuredDirections = SwipeDirection.allCases.filter {
            getSwipeAction(fingerCount: fingerCount, direction: $0).action != .none
        }
        return configuredDirections.isEmpty ? SwipeDirection.allCases : configuredDirections
    }

    // MARK: - Preview

    private func showPreview(for direction: SnapDirection) {
        // If same as current, nothing to do
        guard direction != currentPreviewDirection else {
            pendingPreviewDirection = nil
            previewDebounceTimer?.cancel()
            return
        }

        // If same as pending, let the timer continue
        if direction == pendingPreviewDirection {
            return
        }

        // Set pending direction and start debounce timer
        pendingPreviewDirection = direction
        previewDebounceTimer?.cancel()
        previewDebounceTimer = nil

        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + previewDebounceInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self,
                  let pending = self.pendingPreviewDirection else { return }

            self.currentPreviewDirection = pending
            self.pendingPreviewDirection = nil
            DispatchQueue.main.async {
                FeedbackHUD.shared.showSnapPreview(direction: pending)
            }
        }
        previewDebounceTimer = timer
        timer.resume()
    }

    private func hidePreview() {
        previewDebounceTimer?.cancel()
        previewDebounceTimer = nil
        pendingPreviewDirection = nil
        currentPreviewDirection = nil
        DispatchQueue.main.async {
            FeedbackHUD.shared.hideSnapPreview()
        }
    }

    // MARK: - Action Execution

    private func executeAction(_ action: WindowAction, timestamp: Double, ruleId: UUID? = nil, gestureName: String? = nil) {
        guard action != .none else { return }
        didExecuteGestureAction = true

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

        let actionToExecute = action
        let ruleIdToExecute = ruleId
        actionQueue.async {
            let success: Bool

            // Execute the action based on category
            switch actionToExecute {
            // Window Layout actions - use WindowManager
            case .snapLeft, .snapRight, .snapTop, .snapBottom,
                 .snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight,
                 .maximize, .center, .restore:
                if let direction = actionToExecute.snapDirection {
                    success = WindowManager.shared.snapFocusedWindow(direction: direction)
                } else {
                    success = false
                }

            // Basic window control - use WindowManager
            case .minimize:
                success = WindowManager.shared.minimizeFocusedWindow()

            case .close:
                success = WindowManager.shared.closeFocusedWindow()

            case .fullscreen:
                success = WindowManager.shared.toggleFullscreen()

            case .undo:
                success = WindowManager.shared.undoLastOperation()

            // Extended window control - use SystemActionsManager
            case .maximizeHeight, .maximizeWidth, .minimizeAll, .restoreAllMinimized:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Multi-monitor & Spaces
            case .moveToNextScreen:
                success = WindowManager.shared.moveToNextScreen()

            case .moveToPrevScreen:
                success = WindowManager.shared.moveToPrevScreen()

            case .spaceLeft, .spaceRight, .moveToNextSpace, .moveToPrevSpace:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Desktop & System actions - use SystemActionsManager
            case .missionControl, .showDesktop, .appExpose, .launchpad,
                 .spotlight, .lockScreen, .startScreensaver:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Application control - use SystemActionsManager
            case .quitApp, .hideApp, .hideOthers, .switchApp, .previousApp:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Tab control - use SystemActionsManager
            case .newTab, .closeTab, .nextTab, .prevTab:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Media control - use SystemActionsManager
            case .playPause, .nextTrack, .prevTrack, .volumeUp, .volumeDown, .volumeMute:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Brightness control - use SystemActionsManager
            case .brightnessUp, .brightnessDown:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Screenshot - use SystemActionsManager
            case .screenshot, .screenshotArea, .screenshotWindow:
                success = SystemActionsManager.shared.execute(actionToExecute)

            // Custom shortcut - use SystemActionsManager with ruleId
            case .customShortcut:
                success = SystemActionsManager.shared.execute(actionToExecute, ruleId: ruleIdToExecute)

            case .none:
                success = false
            }

            DispatchQueue.main.async {
                let text = success
                    ? actionToExecute.shortName
                    : String(format: L("action_failed_format"), actionToExecute.displayName)
                FeedbackHUD.shared.flashAction(text: text)
            }
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
        tapTimer?.cancel()
        tapTimer = nil

        // Get actions for all tap types to determine execution strategy
        let singleTapResult = getTapAction(fingerCount: fingerCount, tapType: .singleTap)
        let doubleTapResult = getTapAction(fingerCount: fingerCount, tapType: .doubleTap)
        let tripleTapResult = getTapAction(fingerCount: fingerCount, tapType: .tripleTap)

        #if DEBUG
        print("[GestureEngine] Tap detected: \(fingerCount)F, count=\(tapCount), actions: single=\(singleTapResult.action), double=\(doubleTapResult.action), triple=\(tripleTapResult.action)")
        #endif

        switch tapCount {
        case 1:
            // Single tap: check if we need to wait for double/triple
            if doubleTapResult.action == .none && tripleTapResult.action == .none {
                // No multi-tap configured, execute immediately
                executeTapAction(for: .singleTap, timestamp: timestamp)
                tapCount = 0
            } else {
                // Wait for potential follow-up
                scheduleTapExecution(tapType: .singleTap, fingerCount: fingerCount, timestamp: timestamp)
            }

        case 2:
            // Double tap: check if we need to wait for triple
            if tripleTapResult.action == .none {
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
        tapTimer?.cancel()
        tapTimer = nil

        let capturedTapCount = tapCount
        let capturedFingerCount = fingerCount

        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + tapSequenceTimeout)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            FeedbackHUD.shared.hideWaitingIndicator()

            #if DEBUG
            print("[GestureEngine] Tap timer fired, executing tap count: \(capturedTapCount)")
            #endif

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
        tapTimer = timer
        timer.resume()
    }

    private func executeTapAction(for tapType: TapType, timestamp: Double) {
        let result = getTapAction(fingerCount: lastTapFingerCount, tapType: tapType)

        guard result.action != .none else { return }

        // Check cooldown
        guard timestamp - lastActionTime >= tapCooldown else { return }

        // Build gesture name for learning mode
        let gestureName = String(
            format: L("gesture_tap_format"),
            lastTapFingerCount,
            tapType.displayName
        )

        // Execute action with ruleId (needed for customShortcut actions)
        executeAction(result.action, timestamp: timestamp, ruleId: result.ruleId, gestureName: gestureName)
    }

    // MARK: - Utility

    private func rebaseTrackingReference(centroid: MTVector, touches: [MTTouch], timestamp: Double) {
        initialCentroid = centroid
        currentCentroid = centroid
        previousCentroid = centroid
        referenceTouchPositions = touches.map(\.normalizedVector)
        smoothedTranslation = nil
        lockedDirection = nil
        activeGestureKind = nil
        lockedFingerCount = 0
        lastSwipeVector = MTVector(x: 0, y: 0)
        lastSwipeDistance = 0
        lastResolvedSwipeDirection = nil
        lastSwipeExecutionThreshold = 0
        lastPinchRatio = 1
        didExecuteGestureAction = false
        gestureStartTime = timestamp
        touchDownTime = timestamp
        totalMovement = 0
        maxDisplacementFromStart = 0
        isTapCandidate = true
        initialPinchDistance = (fingerCount == 2 && isPinchEnabled) ? calculateAverageDistance(touches) : 0
    }

    private func calculateGestureTranslation(for touches: [MTTouch], fallbackCentroid: MTVector) -> MTVector {
        guard !referenceTouchPositions.isEmpty else {
            guard let start = initialCentroid else {
                return MTVector(x: 0, y: 0)
            }
            return MTVector(x: fallbackCentroid.x - start.x, y: fallbackCentroid.y - start.y)
        }

        let pairs = pairTouchPositions(reference: referenceTouchPositions, current: touches.map(\.normalizedVector))
        guard !pairs.isEmpty else {
            guard let start = initialCentroid else {
                return MTVector(x: 0, y: 0)
            }
            return MTVector(x: fallbackCentroid.x - start.x, y: fallbackCentroid.y - start.y)
        }

        var sumDx: Float = 0
        var sumDy: Float = 0

        for pair in pairs {
            sumDx += pair.current.x - pair.reference.x
            sumDy += pair.current.y - pair.reference.y
        }

        let count = Float(pairs.count)
        return MTVector(x: sumDx / count, y: sumDy / count)
    }

    private func pairTouchPositions(reference: [MTVector], current: [MTVector]) -> [(reference: MTVector, current: MTVector)] {
        guard !reference.isEmpty, !current.isEmpty else { return [] }

        var remainingReference = reference
        var remainingCurrent = current
        var pairs: [(reference: MTVector, current: MTVector)] = []
        pairs.reserveCapacity(min(reference.count, current.count))

        while !remainingReference.isEmpty && !remainingCurrent.isEmpty {
            var bestReferenceIndex = 0
            var bestCurrentIndex = 0
            var bestDistance = Float.greatestFiniteMagnitude

            for (referenceIndex, referenceTouch) in remainingReference.enumerated() {
                for (currentIndex, currentTouch) in remainingCurrent.enumerated() {
                    let dx = currentTouch.x - referenceTouch.x
                    let dy = currentTouch.y - referenceTouch.y
                    let distance = (dx * dx) + (dy * dy)
                    if distance < bestDistance {
                        bestDistance = distance
                        bestReferenceIndex = referenceIndex
                        bestCurrentIndex = currentIndex
                    }
                }
            }

            let matchedReference = remainingReference.remove(at: bestReferenceIndex)
            let matchedCurrent = remainingCurrent.remove(at: bestCurrentIndex)
            pairs.append((reference: matchedReference, current: matchedCurrent))
        }

        return pairs
    }

    private func smoothSwipeTranslation(_ translation: MTVector) -> MTVector {
        guard let smoothedTranslation else {
            smoothedTranslation = translation
            return translation
        }

        let blended = MTVector(
            x: (smoothedTranslation.x * (1 - swipeDirectionSmoothingFactor)) + (translation.x * swipeDirectionSmoothingFactor),
            y: (smoothedTranslation.y * (1 - swipeDirectionSmoothingFactor)) + (translation.y * swipeDirectionSmoothingFactor)
        )
        self.smoothedTranslation = blended
        return blended
    }

    private func scheduleReleaseConfirmation(timestamp: Double) {
        guard releaseDebounceTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + releaseDebounceInterval)
        timer.setEventHandler { [weak self] in
            self?.releaseDebounceTimer?.cancel()
            self?.releaseDebounceTimer = nil
            self?.handleConfirmedRelease(timestamp: timestamp)
        }
        releaseDebounceTimer = timer
        timer.resume()
    }

    private func cancelReleaseConfirmation() {
        releaseDebounceTimer?.cancel()
        releaseDebounceTimer = nil
    }

    private func handleConfirmedRelease(timestamp: Double) {
        if state == .began || state == .changed {
            tryFinalizeGestureOnRelease(timestamp: timestamp)
            finalizeGesture()
        } else if isTapCandidate && isTapEnabled && peakTouchingFingers > 0 {
            let touchDuration = timestamp - touchDownTime
            let effectiveThreshold = effectiveTapMovementThreshold(for: peakTouchingFingers)
            let movementBudget = effectiveThreshold * 2.2
            if maxDisplacementFromStart < effectiveThreshold &&
                totalMovement < movementBudget &&
                touchDuration < tapMaxDuration {
                fingerCount = peakTouchingFingers
                #if DEBUG
                print("[GestureEngine] Tap candidate: \(fingerCount)F, duration: \(String(format: "%.3f", touchDuration))s, displacement: \(maxDisplacementFromStart)")
                #endif
                handleTapDetected(timestamp: timestamp)
            } else {
                #if DEBUG
                if isFingerCountEnabled(peakTouchingFingers) {
                    let reason: String
                    if maxDisplacementFromStart >= effectiveThreshold {
                        reason = "displacement \(String(format: "%.4f", maxDisplacementFromStart)) >= \(String(format: "%.4f", effectiveThreshold))"
                    } else if totalMovement >= movementBudget {
                        reason = "path \(String(format: "%.4f", totalMovement)) >= \(String(format: "%.4f", movementBudget))"
                    } else {
                        reason = "duration \(String(format: "%.3f", touchDuration))s >= \(tapMaxDuration)s"
                    }
                    print("[GestureEngine] Tap rejected: \(peakTouchingFingers)F, \(reason)")
                }
                #endif
            }
        }

        resetState()
    }

    private func tryFinalizeGestureOnRelease(timestamp: Double) {
        guard !didExecuteGestureAction else { return }

        let gestureFingerCount = lockedFingerCount > 0 ? lockedFingerCount : max(fingerCount, peakTouchingFingers)

        switch activeGestureKind {
        case .pinch:
            guard gestureFingerCount == 2, isPinchEnabled else { return }
            if lastPinchRatio <= Float(config.pinchInThreshold) + pinchReleaseTolerance {
                let action = getPinchAction(direction: .pinchIn)
                executeAction(action.action, timestamp: timestamp, ruleId: action.ruleId, gestureName: "捏合")
            } else if lastPinchRatio >= Float(config.pinchOutThreshold) - pinchReleaseTolerance {
                let action = getPinchAction(direction: .pinchOut)
                executeAction(action.action, timestamp: timestamp, ruleId: action.ruleId, gestureName: "张开")
            }

        case .swipe, .none:
            guard isSwipeEnabled(for: gestureFingerCount) else { return }
            let completionThreshold = max(lastSwipeExecutionThreshold, Float(config.swipeThreshold)) * swipeReleaseCompletionRatio
            guard lastSwipeDistance >= completionThreshold else { return }
            guard let direction = lockedDirection ?? lastResolvedSwipeDirection else { return }

            let gestureName = String(
                format: L("gesture_swipe_format"),
                gestureFingerCount,
                direction.displayName
            )
            let action = getSwipeAction(fingerCount: gestureFingerCount, direction: direction)
            executeAction(action.action, timestamp: timestamp, ruleId: action.ruleId, gestureName: gestureName)
        }
    }

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
        cancelReleaseConfirmation()
        state = .possible
        initialCentroid = nil
        currentCentroid = nil
        previousCentroid = nil
        lockedDirection = nil
        referenceTouchPositions.removeAll(keepingCapacity: true)
        smoothedTranslation = nil
        initialPinchDistance = 0
        lastPinchRatio = 1
        fingerCount = 0
        lockedFingerCount = 0
        activeGestureKind = nil
        activeDevice = nil
        velocityX = 0
        velocityY = 0
        lastFrameTime = 0
        currentPreviewDirection = nil
        lastSwipeVector = MTVector(x: 0, y: 0)
        lastSwipeDistance = 0
        lastResolvedSwipeDirection = nil
        lastSwipeExecutionThreshold = 0
        didExecuteGestureAction = false

        // Reset tap candidate state (but not tap sequence tracking)
        isTapCandidate = false
        totalMovement = 0
        maxDisplacementFromStart = 0
        peakTouchingFingers = 0
        wasAllTouching = false

        FeedbackHUD.shared.clear()
    }

    // MARK: - Public API

    func reset() {
        asyncOnQueue { [weak self] in
            guard let self = self else { return }
            self.tapTimer?.cancel()
            self.tapTimer = nil
            self.tapCount = 0
            self.resetState()
        }
    }

    var isActive: Bool {
        return syncOnQueue {
            state == .began || state == .changed
        }
    }

    private var isOnProcessingQueue: Bool {
        DispatchQueue.getSpecific(key: queueKey) != nil
    }

    private func asyncOnQueue(_ block: @escaping () -> Void) {
        if isOnProcessingQueue {
            block()
        } else {
            processingQueue.async(execute: block)
        }
    }

    private func syncOnQueue<T>(_ block: () -> T) -> T {
        if isOnProcessingQueue {
            return block()
        }
        return processingQueue.sync(execute: block)
    }
}
