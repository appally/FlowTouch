import Cocoa
import SwiftUI
import ServiceManagement
import Combine

// MARK: - Status Bar Manager

class StatusBarManager: NSObject {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    // MARK: - Setup

    func setup() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for the icon
            if let image = NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: "FlowTouch") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "FT"
            }
            button.toolTip = "FlowTouch - Two-Finger Window Control"
        }

        // Create menu
        setupMenu()

        statusItem?.menu = menu

        print("[StatusBar] Menu bar icon created")
    }

    // MARK: - Menu Setup

    private func setupMenu() {
        menu = NSMenu()

        // Status header
        let statusItem = NSMenuItem(title: "FlowTouch", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu?.addItem(statusItem)

        // Status indicator
        let statusIndicator = NSMenuItem(title: getStatusText(), action: nil, keyEquivalent: "")
        statusIndicator.isEnabled = false
        statusIndicator.tag = 100
        menu?.addItem(statusIndicator)

        menu?.addItem(NSMenuItem.separator())

        // Quick window actions
        let snapMenu = NSMenu()

        let snapLeft = NSMenuItem(title: "← Left Half", action: #selector(snapLeft), keyEquivalent: "")
        snapLeft.target = self
        snapMenu.addItem(snapLeft)

        let snapRight = NSMenuItem(title: "Right Half →", action: #selector(snapRight), keyEquivalent: "")
        snapRight.target = self
        snapMenu.addItem(snapRight)

        snapMenu.addItem(NSMenuItem.separator())

        let maximize = NSMenuItem(title: "↑ Maximize", action: #selector(maximize), keyEquivalent: "")
        maximize.target = self
        snapMenu.addItem(maximize)

        let center = NSMenuItem(title: "◎ Center", action: #selector(centerWindow), keyEquivalent: "")
        center.target = self
        snapMenu.addItem(center)

        let actionsItem = NSMenuItem(title: "Snap Window", action: nil, keyEquivalent: "")
        actionsItem.submenu = snapMenu
        menu?.addItem(actionsItem)

        menu?.addItem(NSMenuItem.separator())

        // Launch at Login
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        launchItem.tag = 200
        menu?.addItem(launchItem)

        menu?.addItem(NSMenuItem.separator())

        // Show Window
        let showWindowItem = NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        menu?.addItem(showWindowItem)

        // Permissions
        let permissionsItem = NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu?.addItem(permissionsItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit FlowTouch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)

        // Update menu before showing
        menu?.delegate = self
    }

    private func getStatusText() -> String {
        let manager = MultitouchManager.shared
        switch manager.status {
        case .active:
            return "● Active"
        case .permissionDenied:
            return "○ Permission Needed"
        case .noDeviceFound:
            return "○ No Trackpad"
        case .accessibilityDenied:
            return "○ Accessibility Needed"
        case .unknown:
            return "○ Starting..."
        }
    }

    // MARK: - Menu Actions

    @objc private func snapLeft() {
        WindowManager.shared.snapFocusedWindow(direction: .left)
    }

    @objc private func snapRight() {
        WindowManager.shared.snapFocusedWindow(direction: .right)
    }

    @objc private func maximize() {
        WindowManager.shared.snapFocusedWindow(direction: .maximize)
    }

    @objc private func centerWindow() {
        WindowManager.shared.snapFocusedWindow(direction: .center)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.shared.toggle()
        if let menuItem = menu?.item(withTag: 200) {
            menuItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        }
    }

    @objc private func showMainWindow() {
        // Use the centralized MainWindowController
        MainWindowController.shared.showWindow()
    }

    @objc private func checkPermissions() {
        MultitouchManager.shared.checkPermissions()
        MultitouchManager.shared.checkDevices()

        if let statusItem = menu?.item(withTag: 100) {
            statusItem.title = getStatusText()
        }
    }

    @objc private func quitApp() {
        MultitouchManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status Updates

    func updateStatus() {
        if let statusItem = menu?.item(withTag: 100) {
            statusItem.title = getStatusText()
        }

        // Update icon appearance
        if let button = statusItem?.button {
            let manager = MultitouchManager.shared
            button.appearsDisabled = manager.status != .active
        }
    }
}

// MARK: - NSMenuDelegate

extension StatusBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let statusItem = menu.item(withTag: 100) {
            statusItem.title = getStatusText()
        }
        if let launchItem = menu.item(withTag: 200) {
            launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        }
    }
}

// MARK: - Launch at Login Manager

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let launchAtLoginKey = "launchAtLogin"

    var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
            updateSystemSetting(enabled: newValue)
        }
    }

    func toggle() {
        isEnabled = !isEnabled
        print("[LaunchAtLogin] Toggled to: \(isEnabled)")
    }

    private func updateSystemSetting(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("[LaunchAtLogin] Registered")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("[LaunchAtLogin] Unregistered")
                }
            } catch {
                print("[LaunchAtLogin] ERROR: \(error.localizedDescription)")
            }
        } else {
            let identifier = Bundle.main.bundleIdentifier ?? "com.NEX.FlowTouch"
            SMLoginItemSetEnabled(identifier as CFString, enabled)
        }
    }

    func checkStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                print("[LaunchAtLogin] Status: Enabled")
            case .notRegistered:
                print("[LaunchAtLogin] Status: Not Registered")
            case .requiresApproval:
                print("[LaunchAtLogin] Status: Requires Approval")
            case .notFound:
                print("[LaunchAtLogin] Status: Not Found")
            @unknown default:
                print("[LaunchAtLogin] Status: Unknown")
            }
        }
    }
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Sensitivity
    @Published var swipeSensitivity: Double {
        didSet { UserDefaults.standard.set(swipeSensitivity, forKey: "swipeSensitivity") }
    }

    private init() {
        self.swipeSensitivity = UserDefaults.standard.object(forKey: "swipeSensitivity") as? Double ?? 1.0
    }

    func resetToDefaults() {
        swipeSensitivity = 1.0
    }
}
