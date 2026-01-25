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
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func showWindow() {
        // First, ensure we're in regular mode to show dock icon and allow windows
        NSApplication.shared.setActivationPolicy(.regular)
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
            if window.className == "NSStatusBarWindow" { continue }
            if window is NSPanel { continue }

            // Check if this is our main content window (has NSHostingView which hosts SwiftUI)
            if window.contentView?.subviews.first(where: { String(describing: type(of: $0)).contains("NSHostingView") }) != nil {
                window.makeKeyAndOrderFront(nil)
                print("[MainWindowController] Brought existing window to front: \(window)")
                return true
            }
        }

        return false
    }

    private func openOrCreateFallbackWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let window = self.fallbackWindow {
                window.makeKeyAndOrderFront(nil)
                return
            }

            let hostingView = NSHostingView(rootView: ContentView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 800, height: 600)
            window.contentView = hostingView
            window.center()
            window.makeKeyAndOrderFront(nil)

            self.fallbackWindow = window
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[FlowTouch] Application launched")

        // Setup menu bar icon
        StatusBarManager.shared.setup()

        // Determine activation policy based on launch context
        if isLaunchedAtLogin() {
            NSApplication.shared.setActivationPolicy(.accessory)
            print("[FlowTouch] Launched at login - running in background")
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            print("[FlowTouch] Normal launch - showing window")
        }

        // Setup HUD overlay
        FeedbackHUD.shared.setup()

        // Start multitouch engine after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
