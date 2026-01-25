import Foundation
import SwiftUI
import Combine
import ApplicationServices

// MARK: - Manager Status

enum ManagerStatus: Equatable {
    case unknown
    case active
    case permissionDenied
    case noDeviceFound
    case accessibilityDenied
}

// MARK: - Error Types

enum FlowTouchError: Error, LocalizedError {
    case noDevicesFound
    case inputMonitoringDenied
    case accessibilityDenied
    case deviceStartFailed(device: String)
    case callbackRegistrationFailed

    var errorDescription: String? {
        switch self {
        case .noDevicesFound:
            return "No multitouch devices found. Ensure a trackpad is connected."
        case .inputMonitoringDenied:
            return "Input Monitoring permission denied. Please grant access in System Settings."
        case .accessibilityDenied:
            return "Accessibility permission denied. Please grant access in System Settings."
        case .deviceStartFailed(let device):
            return "Failed to start device: \(device)"
        case .callbackRegistrationFailed:
            return "Failed to register touch callback."
        }
    }
}

// MARK: - Multitouch Manager

class MultitouchManager: ObservableObject {
    static let shared = MultitouchManager()

    private var devices: [MTDeviceRef] = []
    private var isRunning = false
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private let deviceQueue = DispatchQueue(label: "FlowTouch.DeviceQueue", qos: .userInitiated)

    @Published var status: ManagerStatus = .unknown
    @Published var debugLog: String = ""
    @Published var touchCount: Int = 0
    @Published var lastError: FlowTouchError?

    // Permission states
    @Published var hasInputMonitoring: Bool = false
    @Published var hasAccessibility: Bool = false

    // System gesture conflicts
    @Published var systemGestureConflicts: [SystemGestureConflict] = []

    // MARK: - System Gesture Conflict Detection

    struct SystemGestureConflict: Identifiable {
        let id = UUID()
        let fingerCount: Int
        let systemGesture: String
        let flowTouchGesture: String
        let suggestion: String
    }

    /// Check for conflicts between FlowTouch gestures and system trackpad gestures
    func checkSystemGestureConflicts() {
        var conflicts: [SystemGestureConflict] = []

        // Read system trackpad preferences
        // 3-finger swipe between pages (Safari, Preview, etc.)
        let threeFingerSwipe = readTrackpadBool("com.apple.trackpad.threeFingerHorizSwipeGesture", defaultValue: false)
        // Alternative key used in some macOS versions
        let threeFingerDrag = readTrackpadBool("com.apple.trackpad.threeFingerDrag", defaultValue: false)

        // 4-finger gestures
        let missionControl = readTrackpadInt("TrackpadFourFingerVertSwipeGesture", defaultValue: 2)
        let appExpose = readTrackpadInt("TrackpadFourFingerHorizSwipeGesture", defaultValue: 2)
        let launchpad = readTrackpadBool("TrackpadFourFingerPinchGesture", defaultValue: true)

        // Check FlowTouch rules for conflicts
        let rules = RuleManager.shared.rules.filter { $0.isEnabled }

        // Check 3-finger conflicts
        if threeFingerSwipe || threeFingerDrag {
            let threeFingerRules = rules.filter { rule in
                rule.trigger.type == .swipe && rule.trigger.fingerCount == 3
            }
            if !threeFingerRules.isEmpty {
                conflicts.append(SystemGestureConflict(
                    fingerCount: 3,
                    systemGesture: threeFingerDrag ? "三指拖移" : "三指滑动切换页面",
                    flowTouchGesture: "三指滑动手势",
                    suggestion: "建议在系统偏好设置中关闭三指手势，或使用四指手势"
                ))
            }
        }

        // Check 4-finger vertical conflicts (Mission Control)
        if missionControl > 0 {
            let fourFingerVerticalRules = rules.filter { rule in
                rule.trigger.type == .swipe &&
                rule.trigger.fingerCount == 4 &&
                (rule.trigger.swipeDirection == .up || rule.trigger.swipeDirection == .down)
            }
            if !fourFingerVerticalRules.isEmpty {
                conflicts.append(SystemGestureConflict(
                    fingerCount: 4,
                    systemGesture: "四指上滑调度中心 / 下滑应用窗口",
                    flowTouchGesture: "四指上下滑动手势",
                    suggestion: "建议在系统偏好设置中关闭四指垂直滑动手势"
                ))
            }
        }

        // Check 4-finger horizontal conflicts (Space switching)
        if appExpose > 0 {
            let fourFingerHorizontalRules = rules.filter { rule in
                rule.trigger.type == .swipe &&
                rule.trigger.fingerCount == 4 &&
                (rule.trigger.swipeDirection == .left || rule.trigger.swipeDirection == .right)
            }
            if !fourFingerHorizontalRules.isEmpty {
                conflicts.append(SystemGestureConflict(
                    fingerCount: 4,
                    systemGesture: "四指左右滑动切换桌面空间",
                    flowTouchGesture: "四指左右滑动手势",
                    suggestion: "建议在系统偏好设置中关闭四指水平滑动手势"
                ))
            }
        }

        // Check pinch conflicts (Launchpad)
        if launchpad {
            let pinchRules = rules.filter { rule in
                rule.trigger.type == .pinch
            }
            if !pinchRules.isEmpty {
                conflicts.append(SystemGestureConflict(
                    fingerCount: 2,
                    systemGesture: "捏合显示 Launchpad",
                    flowTouchGesture: "捏合手势",
                    suggestion: "建议在系统偏好设置中关闭 Launchpad 手势"
                ))
            }
        }

        DispatchQueue.main.async {
            self.systemGestureConflicts = conflicts
        }
    }

    /// Open System Preferences to Trackpad settings
    func openTrackpadSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Logging

    func log(_ msg: String, level: LogLevel = .info) {
        let prefix: String
        switch level {
        case .info: prefix = "[INFO]"
        case .warning: prefix = "[WARN]"
        case .error: prefix = "[ERROR]"
        case .debug: prefix = "[DEBUG]"
        }
        let message = "\(prefix) \(msg)"
        print(message)
        DispatchQueue.main.async {
            self.debugLog += "\n" + message
            // Keep log size manageable
            if self.debugLog.count > 5000 {
                self.debugLog = String(self.debugLog.suffix(3000))
            }
        }
    }

    enum LogLevel {
        case info, warning, error, debug
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else {
            log("Manager already running", level: .warning)
            return
        }

        log("Starting FlowTouch Manager...")

        // 1. Check and request permissions
        checkPermissions()

        // 2. Request Input Monitoring (triggers system dialog)
        requestInputMonitoring()

        // 3. Start Multitouch Engine as soon as possible (off main thread)
        deviceQueue.async { [weak self] in
            self?.checkDevices()
        }
    }

    func stop() {
        guard isRunning else { return }

        log("Stopping FlowTouch Manager...")
        for device in devices {
            MTDeviceStop(device)
        }
        devices.removeAll()
        isRunning = false

        DispatchQueue.main.async {
            self.status = .unknown
        }
        cleanupEventTap()
    }

    // MARK: - Permission Handling

    func checkPermissions() {
        // Check Accessibility
        hasAccessibility = AXIsProcessTrusted()
        log("Accessibility permission: \(hasAccessibility ? "Granted" : "Denied")")

        if !hasAccessibility {
            log("Accessibility permission required for window management", level: .warning)
            if status != .permissionDenied {
                status = .accessibilityDenied
            }
        } else if status == .accessibilityDenied {
            status = isRunning ? .active : .unknown
        }

        // Input Monitoring is harder to check directly - we infer from device access
    }

    func requestAccessibilityPermission() {
        log("Requesting Accessibility permission...")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
        hasAccessibility = result
        log("Accessibility permission after request: \(result ? "Granted" : "Denied")")
    }

    func requestInputMonitoringPermission() {
        requestInputMonitoring()
    }

    func requestInputMonitoring() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.requestInputMonitoring()
            }
            return
        }

        if eventTap != nil {
            return
        }

        log("Attempting to trigger Input Monitoring permission dialog...")

        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, _ in
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            log("Failed to create Event Tap. Input Monitoring may be denied.", level: .warning)
            hasInputMonitoring = false
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.eventTapSource = runLoopSource

        hasInputMonitoring = true
        log("Event Tap created successfully. Input Monitoring appears to be granted.")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.cleanupEventTap()
        }
    }

    // MARK: - Device Management

    func checkDevices() {
        log("Checking for multitouch devices...")

        var foundDevices: [MTDeviceRef] = []

        // Method 1: Try getting device list
        if let list = MTDeviceCreateList() {
            let refs = list.takeUnretainedValue() as NSArray
            if let typed = refs as? [MTDeviceRef], !typed.isEmpty {
                foundDevices.append(contentsOf: typed)
                log("MTDeviceCreateList found \(typed.count) device(s)")
            } else {
                log("MTDeviceCreateList returned empty or invalid array", level: .debug)
            }
        } else {
            log("MTDeviceCreateList returned nil", level: .debug)
        }

        // Method 2: Fallback to default device
        if foundDevices.isEmpty {
            log("Trying MTDeviceCreateDefault as fallback...")
            if let defaultDevice = MTDeviceCreateDefault() {
                foundDevices.append(defaultDevice)
                log("MTDeviceCreateDefault found a device")
            } else {
                log("MTDeviceCreateDefault returned nil", level: .debug)
            }
        }

        // Check result
        guard !foundDevices.isEmpty else {
            log("No multitouch devices found!", level: .error)
            lastError = .noDevicesFound

            // Determine if this is a permission issue or hardware issue
            DispatchQueue.main.async {
                // If we couldn't create event tap earlier, likely permission issue
                if !self.hasInputMonitoring {
                    self.status = .permissionDenied
                } else {
                    self.status = .noDeviceFound
                }
            }
            return
        }

        // Store and start devices
        self.devices = foundDevices
        startDevices()
    }

    private func startDevices() {
        let allStarted = true

        for (index, device) in devices.enumerated() {
            log("Starting device \(index + 1)/\(devices.count): \(device)")

            // Register callback first
            MTRegisterContactFrameCallback(device, globalTouchCallback)

            // Start the device
            MTDeviceStart(device, 0)

            log("Device \(index + 1) started successfully")
        }

        isRunning = true

        DispatchQueue.main.async {
            if allStarted {
                if self.hasAccessibility {
                    self.status = .active
                    self.log("All devices started. FlowTouch is active!")
                } else {
                    self.status = .accessibilityDenied
                    self.log("Accessibility permission not yet granted. Window management may not work.", level: .warning)
                }
            }
        }
    }

    // MARK: - Status Helpers

    var statusDescription: String {
        switch status {
        case .unknown:
            return "Initializing..."
        case .active:
            return "Active"
        case .permissionDenied:
            return "Permission Denied"
        case .noDeviceFound:
            return "No Trackpad Found"
        case .accessibilityDenied:
            return "Accessibility Denied"
        }
    }

    var needsPermissionSetup: Bool {
        return status == .permissionDenied || status == .accessibilityDenied
    }

    // MARK: - Trackpad Preferences

    private let trackpadPreferenceDomains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]

    private func readTrackpadPreference(_ key: String) -> Any? {
        for domain in trackpadPreferenceDomains {
            if let value = CFPreferencesCopyValue(
                key as CFString,
                domain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) {
                return value
            }
        }
        return nil
    }

    private func readTrackpadBool(_ key: String, defaultValue: Bool) -> Bool {
        if let value = readTrackpadPreference(key) {
            if let boolValue = value as? Bool {
                return boolValue
            }
            if let number = value as? NSNumber {
                return number.boolValue
            }
        }
        return defaultValue
    }

    private func readTrackpadInt(_ key: String, defaultValue: Int) -> Int {
        if let value = readTrackpadPreference(key) {
            if let number = value as? NSNumber {
                return number.intValue
            }
        }
        return defaultValue
    }

    private func cleanupEventTap() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.cleanupEventTap()
            }
            return
        }

        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            eventTapSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }
}

// MARK: - Global Touch Callback

/// Global C-Convention Callback for touch events
/// Signature: (MTDeviceRef, MTTouch*, Int32 numFingers, Double timestamp, Int32 frameId)
func globalTouchCallback(
    device: MTDeviceRef,
    fingersPtr: UnsafeMutableRawPointer?,
    numFingers: Int32,
    timestamp: Double,
    frameId: Int32
) {
    // Heartbeat logging (every ~0.5s at 120Hz)
    #if DEBUG
    if frameId % 60 == 0 {
        print("[Callback] Frame \(frameId) - Device: \(device) - Fingers: \(numFingers)")
    }
    #endif

    // Handle empty frame (all fingers lifted)
    guard let fingersPtr = fingersPtr else {
        GestureEngine.shared.processFrame(timestamp: timestamp, touches: [])
        return
    }

    let count = Int(numFingers)

    if count > 0 {
        // Bind memory to MTTouch array
        let fingers = fingersPtr.bindMemory(to: MTTouch.self, capacity: count)

        // Convert to Swift array
        var touchArray: [MTTouch] = []
        touchArray.reserveCapacity(count)

        for i in 0..<count {
            touchArray.append(fingers[i])
        }

        // Feed to Gesture Engine
        GestureEngine.shared.processFrame(timestamp: timestamp, touches: touchArray)

        // Update UI touch counter (throttled)
        if frameId % 10 == 0 {
            DispatchQueue.main.async {
                MultitouchManager.shared.touchCount += 1
                if MultitouchManager.shared.touchCount == 1 {
                    MultitouchManager.shared.log("First touch received! Engine is active.")
                }
            }
        }
    } else {
        // Empty touch frame
        GestureEngine.shared.processFrame(timestamp: timestamp, touches: [])
    }
}
