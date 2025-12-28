import SwiftUI
import ApplicationServices

struct PermissionGuidanceView: View {
    @ObservedObject var manager = MultitouchManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Image(systemName: "hand.raised.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)

                Text("Permissions Required")
                    .font(.title)
                    .bold()

                Text("FlowTouch needs system permissions to monitor trackpad input and control windows.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Permission Cards
                VStack(spacing: 12) {
                    PermissionCard(
                        title: "Input Monitoring",
                        description: "Required to detect trackpad gestures",
                        isGranted: manager.hasInputMonitoring,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                    )

                    PermissionCard(
                        title: "Accessibility",
                        description: "Required to move and resize windows",
                        isGranted: manager.hasAccessibility,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    )
                }

                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Setup Instructions")
                        .font(.headline)
                        .padding(.bottom, 4)

                    InstructionRow(number: 1, text: "Open System Settings > Privacy & Security")
                    InstructionRow(number: 2, text: "Select 'Input Monitoring' and enable FlowTouch")
                    InstructionRow(number: 3, text: "Select 'Accessibility' and enable FlowTouch")
                    InstructionRow(number: 4, text: "Restart the app if needed")

                    Divider()
                        .padding(.vertical, 8)

                    // Xcode Warning
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Developer Note")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Rebuilding in Xcode invalidates permissions. Remove the app from the list and re-add it after each rebuild.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    // Hardware Tip
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Ensure a Magic Trackpad is connected or you're using a MacBook with built-in trackpad.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: openInputMonitoringSettings) {
                        Label("Input Monitoring", systemImage: "hand.tap")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: openAccessibilitySettings) {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }

                HStack(spacing: 12) {
                    Button("Retry") {
                        manager.checkPermissions()
                        manager.checkDevices()
                    }
                    .buttonStyle(.bordered)

                    Button("Request Accessibility") {
                        requestAccessibility()
                    }
                    .buttonStyle(.bordered)
                }

                // Debug Log
                DebugLogView(log: manager.debugLog)
            }
            .padding()
        }
        .frame(width: 450, height: 600)
    }

    // MARK: - Actions

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        // Refresh state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            manager.checkPermissions()
        }
    }
}

// MARK: - Supporting Views

struct PermissionCard: View {
    let title: String
    let description: String
    let isGranted: Bool
    let settingsURL: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(isGranted ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
                .foregroundColor(.white)

            Text(text)
                .font(.callout)
        }
    }
}

struct DebugLogView: View {
    let log: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "terminal")
                    Text("Debug Log")
                        .font(.caption)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    Text(log.isEmpty ? "No logs yet..." : log)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .padding(8)
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    PermissionGuidanceView()
}
