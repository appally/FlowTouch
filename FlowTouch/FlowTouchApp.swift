//
//  FlowTouchApp.swift
//  FlowTouch
//
//  Created by Appally on 2025/12/27.
//

import SwiftUI
import ApplicationServices
import Cocoa

// MARK: - Window Controller

/// Manages main window visibility for menu bar app
@MainActor
final class MainWindowController: NSObject {
    static let shared = MainWindowController()

    private let mainWindowIdentifier = NSUserInterfaceItemIdentifier("FlowTouchMainWindow")
    private let windowDelegate = MainAppWindowDelegate()
    private weak var mainWindow: NSWindow?

    private override init() {
        super.init()
        windowDelegate.controller = self
    }

    func showWindow() {
        applyPreferredActivationPolicy(activate: true)
        _ = bringExistingWindowToFront()
    }

    func register(window: NSWindow) {
        guard mainWindow !== window else { return }

        window.identifier = mainWindowIdentifier
        window.isReleasedWhenClosed = false
        window.delegate = windowDelegate
        window.collectionBehavior.insert(.moveToActiveSpace)
        mainWindow = window
    }

    func prepareForTermination() {
        windowDelegate.allowsClose = true
    }

    fileprivate func hideWindow(_ window: NSWindow) {
        window.orderOut(nil)
        applyPreferredActivationPolicy(activate: false)
    }

    @discardableResult
    private func bringExistingWindowToFront() -> Bool {
        guard let window = resolveMainWindow() else { return false }

        window.collectionBehavior.insert(.moveToActiveSpace)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
        print("[MainWindowController] Brought main window to front: \(window)")
        return true
    }

    private func resolveMainWindow() -> NSWindow? {
        if let mainWindow, mainWindow.identifier == mainWindowIdentifier {
            return mainWindow
        }

        let window = NSApplication.shared.windows.first { $0.identifier == mainWindowIdentifier }
        mainWindow = window
        return window
    }

    private func applyPreferredActivationPolicy(activate: Bool) {
        let policy: NSApplication.ActivationPolicy = AppSettings.shared.showDockIcon ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)
        if activate {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

private final class MainAppWindowDelegate: NSObject, NSWindowDelegate {
    weak var controller: MainWindowController?
    var allowsClose = false

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !allowsClose else { return true }

        controller?.hideWindow(sender)
        return false
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowTrackingView {
        WindowTrackingView()
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
    }
}

private final class WindowTrackingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else { return }
        MainWindowController.shared.register(window: window)
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
        MainWindowController.shared.prepareForTermination()
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

@main
struct FlowTouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var localization = LocalizationManager.shared

    var body: some Scene {
        Window("FlowTouch", id: "main") {
            ContentView()
                .background(MainWindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L("About FlowTouch")) {
                    showAboutWindow()
                }
            }

            CommandGroup(after: .appSettings) {
                Button(L("检查权限")) {
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
        alert.informativeText = L("about_informative_text")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("确定"))
        alert.runModal()
    }
}
