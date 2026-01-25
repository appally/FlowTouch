//
//  FlowTouchApp.swift
//  FlowTouch
//
//  Created by Appally on 2025/12/27.
//

import SwiftUI
import ApplicationServices
import Cocoa
import Combine

// MARK: - Window Controller

/// Manages main window visibility for menu bar app
class MainWindowController: ObservableObject {
    static let shared = MainWindowController()

    @Published var shouldShowWindow = false

    private var observer: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?
    private var fallbackWindow: NSWindow?

    init() {
        // Listen for show window notification from StatusBarManager
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowMainWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showWindow()
        }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.handleWindowClosed(window)
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let closeObserver = closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }

    func showWindow() {
        // Respect user preference for Dock icon visibility
        let policy: NSApplication.ActivationPolicy = AppSettings.shared.showDockIcon ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Try to find and show existing window first
        if bringExistingWindowToFront() {
            return
        }

        // No existing window found, create a fallback window directly
        openOrCreateFallbackWindow()
    }

    @discardableResult
    private func bringExistingWindowToFront() -> Bool {
        // Find the main content window (not status bar, not panels)
        for window in NSApplication.shared.windows {
            // Skip status bar windows and panels
            guard isMainContentWindow(window) else { continue }

            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
            print("[MainWindowController] Brought existing window to front: \(window)")
            return true
        }

        return false
    }

    private func isMainContentWindow(_ window: NSWindow) -> Bool {
        if window.className == "NSStatusBarWindow" { return false }
        if window is NSPanel { return false }
        return window.contentView?.subviews.first(where: { String(describing: type(of: $0)).contains("NSHostingView") }) != nil
    }

    private func hasVisibleMainWindow() -> Bool {
        return NSApplication.shared.windows.contains { window in
            guard isMainContentWindow(window) else { return false }
            return window.isVisible || window.isMiniaturized
        }
    }

    private func handleWindowClosed(_ window: NSWindow) {
        if fallbackWindow === window {
            fallbackWindow = nil
        }

        guard isMainContentWindow(window) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.hasVisibleMainWindow() {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    private func openOrCreateFallbackWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let window = self.fallbackWindow {
                window.collectionBehavior.insert(.moveToActiveSpace)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApplication.shared.activate(ignoringOtherApps: true)
                return
            }

            let hostingView = NSHostingView(rootView: ContentView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unifiedCompact
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 800, height: 600)
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.contentView = hostingView
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)

            self.fallbackWindow = window
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[FlowTouch] Application launched")

        // Setup menu bar icon
        if AppSettings.shared.showMenuBarIcon {
            StatusBarManager.shared.setup()
        }

        // Determine activation policy based on launch context
        let showDockIcon = AppSettings.shared.showDockIcon
        if isLaunchedAtLogin() {
            NSApplication.shared.setActivationPolicy(.accessory)
            print("[FlowTouch] Launched at login - running in background")
        } else {
            NSApplication.shared.setActivationPolicy(showDockIcon ? .regular : .accessory)
            if showDockIcon {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            print("[FlowTouch] Normal launch - showing window")
        }

        // Setup HUD overlay
        FeedbackHUD.shared.setup()

        // Start multitouch engine quickly to reduce perceived startup delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            MultitouchManager.shared.start()
        }

        // Check launch at login status
        LaunchAtLoginManager.shared.checkStatus()

        // Initialize window controller
        _ = MainWindowController.shared
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[FlowTouch] Application terminating")
        MultitouchManager.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show window when dock icon is clicked
        if !flag {
            MainWindowController.shared.showWindow()
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Update status bar when app becomes active
        StatusBarManager.shared.updateStatus()
    }

    // MARK: - Helpers

    private func isLaunchedAtLogin() -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        if let eventID = event?.eventID, eventID == kAEOpenApplication {
            if let descriptor = event?.paramDescriptor(forKeyword: keyAEPropData) {
                return descriptor.stringValue == "true"
            }
        }
        return false
    }
}

// MARK: - Main App

// MARK: - Window Opener Helper View

/// A helper view that can open new windows using the environment
struct WindowOpenerView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNewWindow"))) { _ in
                if #available(macOS 13.0, *) {
                    openWindow(id: "main")
                }
            }
    }
}

@main
struct FlowTouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ZStack {
                ContentView()
                WindowOpenerView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About FlowTouch") {
                    showAboutWindow()
                }
            }

            CommandGroup(after: .appSettings) {
                Button("Check Permissions") {
                    MultitouchManager.shared.checkPermissions()
                    MultitouchManager.shared.checkDevices()
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
            }
        }
    }

    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "FlowTouch"
        alert.informativeText = """
        Version 1.0

        Two-finger window management for macOS.
        Swipe to snap windows. Simple and fast.

        Gesture Reference:
        • Swipe left/right → Half screen
        • Swipe up → Maximize
        • Swipe down → Restore
        • Diagonal swipe → Quarter screen
        • Pinch in → Center
        • Pinch out → Maximize
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
