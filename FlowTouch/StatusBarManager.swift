import Cocoa
import SwiftUI
import ServiceManagement
import Combine

// MARK: - Status Bar Manager

class StatusBarManager: NSObject {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var didRegisterLanguageObserver = false
    private let menuIconSize = NSSize(width: 18, height: 18)

    private func L(_ key: String) -> String {
        LocalizationManager.shared.localizedString(key)
    }

    // MARK: - Setup

    func setup() {
        guard statusItem == nil else {
            updateStatus()
            return
        }
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let image = loadMenuBarImage(named: "brush-ai-fill") {
                button.image = image
            } else if let image = NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: "FlowTouch") {
                image.isTemplate = true
                image.size = menuIconSize
                button.image = image
            } else {
                button.title = "FT"
            }
            button.toolTip = L("FlowTouch - Two-Finger Window Control")
        }

        // Create menu
        setupMenu()

        statusItem?.menu = menu

        if !didRegisterLanguageObserver {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleLanguageChanged),
                name: .languageChanged,
                object: nil
            )
            didRegisterLanguageObserver = true
        }

        print("[StatusBar] Menu bar icon created")
    }

    // MARK: - Menu Setup

    private func setupMenu() {
        menu = NSMenu()

        // Status header
        let statusItem = NSMenuItem(title: "FlowTouch", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu?.addItem(statusItem)

        // Status indicator (dot + text, single line)
        let statusIndicator = NSMenuItem(title: getStatusText(), action: nil, keyEquivalent: "")
        statusIndicator.isEnabled = false
        statusIndicator.tag = 100
        statusIndicator.attributedTitle = statusAttributedText()
        menu?.addItem(statusIndicator)

        menu?.addItem(NSMenuItem.separator())

        // Launch at Login
        let launchItem = NSMenuItem(title: L("登录时启动"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        launchItem.tag = 200
        menu?.addItem(launchItem)

        menu?.addItem(NSMenuItem.separator())

        // Show Window
        let showWindowItem = NSMenuItem(title: L("显示主窗口"), action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        showWindowItem.keyEquivalentModifierMask = [.command]
        showWindowItem.keyEquivalent = ","
        menu?.addItem(showWindowItem)

        // Permissions
        let permissionsItem = NSMenuItem(title: L("检查权限"), action: #selector(checkPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu?.addItem(permissionsItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: L("退出 FlowTouch"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)

        // Update menu before showing
        menu?.delegate = self
    }

    private func getStatusText() -> String {
        let manager = MultitouchManager.shared
        switch manager.status {
        case .active:
            return L("运行中")
        case .awaitingTouch:
            return L("等待首次触摸")
        case .permissionDenied:
            return L("需要输入监控权限")
        case .noDeviceFound:
            return L("未检测到触控板")
        case .accessibilityDenied:
            return L("需要辅助功能权限")
        case .unknown:
            return L("正在启动...")
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
            statusItem.attributedTitle = statusAttributedText()
        }
    }

    @objc private func quitApp() {
        MultitouchManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status Updates

    func updateStatus() {
        if let statusItem = menu?.item(withTag: 100) {
            statusItem.attributedTitle = statusAttributedText()
        }

        // Update icon appearance
        if let button = statusItem?.button {
            let manager = MultitouchManager.shared
            button.appearsDisabled = manager.status != .active
        }
    }

    @objc private func handleLanguageChanged() {
        setupMenu()
        statusItem?.menu = menu
        updateStatus()
    }

    func applyMenuBarIconPreference(enabled: Bool) {
        let apply = {
            if enabled {
                self.setup()
            } else if let item = self.statusItem {
                NSStatusBar.system.removeStatusItem(item)
                self.statusItem = nil
                self.menu = nil
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func loadMenuBarImage(named name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.size = menuIconSize
        return image
    }
}

// MARK: - NSMenuDelegate

extension StatusBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let statusItem = menu.item(withTag: 100) {
            statusItem.attributedTitle = statusAttributedText()
        }
        if let launchItem = menu.item(withTag: 200) {
            launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        }

    }

    private func statusDotColor() -> NSColor {
        let manager = MultitouchManager.shared
        switch manager.status {
        case .active:
            return .systemGreen
        case .awaitingTouch:
            return .systemYellow
        case .permissionDenied, .accessibilityDenied:
            return .systemOrange
        case .noDeviceFound:
            return .systemRed
        case .unknown:
            return .systemGray
        }
    }

    private func statusAttributedText() -> NSAttributedString {
        let dotAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: statusDotColor(),
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let result = NSMutableAttributedString(string: "●", attributes: dotAttributes)
        result.append(NSAttributedString(string: " " + getStatusText(), attributes: textAttributes))
        return result
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

    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon")
            applyDockIconPreference()
        }
    }

    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon")
            StatusBarManager.shared.applyMenuBarIconPreference(enabled: showMenuBarIcon)
        }
    }

    private init() {
        self.swipeSensitivity = UserDefaults.standard.object(forKey: "swipeSensitivity") as? Double ?? 1.0
        self.showDockIcon = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
        self.showMenuBarIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
    }

    func resetToDefaults() {
        swipeSensitivity = 1.0
        showDockIcon = true
        showMenuBarIcon = true
    }

    func applyDockIconPreference() {
        let apply = {
            let policy: NSApplication.ActivationPolicy = self.showDockIcon ? .regular : .accessory
            NSApplication.shared.setActivationPolicy(policy)
            if self.showDockIcon {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}
