import SwiftUI
import ApplicationServices

struct PermissionGuidanceView: View {
    @ObservedObject private var manager = MultitouchManager.shared

    private var permissionRequirements: [PermissionRequirement] {
        [
            PermissionRequirement(
                id: "input-monitoring",
                icon: "hand.tap",
                title: L("Input Monitoring"),
                description: L("Required to detect trackpad gestures"),
                isGranted: manager.hasInputMonitoring,
                primaryActionTitle: L("授权"),
                primaryAction: { manager.requestInputMonitoringPermission() },
                settingsAction: openInputMonitoringSettings
            ),
            PermissionRequirement(
                id: "accessibility",
                icon: "accessibility",
                title: L("Accessibility"),
                description: L("Required to move and resize windows"),
                isGranted: manager.hasAccessibility,
                primaryActionTitle: L("授权"),
                primaryAction: requestAccessibility,
                settingsAction: openAccessibilitySettings
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                permissionStatusPanel
                guidancePanel
                diagnosticsPanel
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 52, height: 52)
                .background(.orange.opacity(0.12), in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 10) {
                Text(L("Permissions Required"))
                    .font(.system(size: 30, weight: .semibold))

                Text(L("FlowTouch needs system permissions to monitor trackpad input and control windows."))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L("完成授权后回到应用，FlowTouch 会自动重新检查。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    PermissionSummaryChip(
                        title: L("Input Monitoring"),
                        isGranted: manager.hasInputMonitoring
                    )
                    PermissionSummaryChip(
                        title: L("Accessibility"),
                        isGranted: manager.hasAccessibility
                    )
                }
            }

            Spacer(minLength: 16)

            Button(action: refreshPermissions) {
                Label(L("Retry"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var permissionStatusPanel: some View {
        SettingsPanel(title: L("权限状态")) {
            VStack(spacing: 0) {
                ForEach(Array(permissionRequirements.enumerated()), id: \.element.id) { index, requirement in
                    PermissionRequirementRow(requirement: requirement)

                    if index < permissionRequirements.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
        }
    }

    private var guidancePanel: some View {
        SettingsPanel(
            title: L("Setup Instructions"),
            subtitle: L("如果系统没有弹出授权窗口，请使用每一项右侧的“打开设置”。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                StepRow(number: 1, text: L("Open System Settings > Privacy & Security"))
                StepRow(number: 2, text: L("Select 'Input Monitoring' and enable FlowTouch"))
                StepRow(number: 3, text: L("Select 'Accessibility' and enable FlowTouch"))
                StepRow(number: 4, text: L("Restart the app if needed"))

                Divider()
                    .padding(.vertical, 4)

                NoteRow(
                    icon: "info.circle",
                    title: L("Developer Note"),
                    text: L("Rebuilding in Xcode invalidates permissions. Remove the app from the list and re-add it after each rebuild."),
                    tint: .blue
                )

                NoteRow(
                    icon: "exclamationmark.triangle",
                    title: nil,
                    text: L("Ensure a Magic Trackpad is connected or you're using a MacBook with built-in trackpad."),
                    tint: .orange
                )
            }
        }
    }

    private var diagnosticsPanel: some View {
        SettingsPanel(title: L("Debug Log")) {
            DebugLogView(log: manager.debugLog)
        }
    }

    private func refreshPermissions() {
        manager.checkPermissions()
        manager.checkDevices()
    }

    private func openInputMonitoringSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func openAccessibilitySettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshPermissions()
        }
    }
}

private struct PermissionRequirement {
    let id: String
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let settingsAction: () -> Void
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PermissionSummaryChip: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .imageScale(.small)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(isGranted ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isGranted ? Color.green : Color.orange).opacity(0.12), in: .capsule)
    }
}

private struct PermissionRequirementRow: View {
    let requirement: PermissionRequirement

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: requirement.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(requirement.isGranted ? .green : .orange)
                .frame(width: 34, height: 34)
                .background(
                    (requirement.isGranted ? Color.green : Color.orange).opacity(0.12),
                    in: .rect(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(requirement.title)
                        .font(.headline)

                    PermissionStateBadge(isGranted: requirement.isGranted)
                }

                Text(requirement.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 8) {
                if !requirement.isGranted {
                    Button(requirement.primaryActionTitle, action: requirement.primaryAction)
                        .buttonStyle(.borderedProminent)
                }

                Button(L("打开设置"), action: requirement.settingsAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.regular)
        }
        .padding(.vertical, 12)
    }
}

private struct PermissionStateBadge: View {
    let isGranted: Bool

    var body: some View {
        Text(isGranted ? L("已授权") : L("待授权"))
            .font(.caption.weight(.medium))
            .foregroundStyle(isGranted ? .green : .orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isGranted ? Color.green : Color.orange).opacity(0.1), in: .capsule)
    }
}

private struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 15, weight: .semibold))

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NoteRow: View {
    let icon: String
    let title: String?
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct DebugLogView: View {
    let log: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView {
                Text(log.isEmpty ? L("No logs yet...") : log)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(minHeight: 96, maxHeight: 160)
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
            .padding(.top, 8)
        } label: {
            Label(L("Debug Log"), systemImage: "terminal")
                .font(.subheadline)
        }
    }
}

#Preview {
    PermissionGuidanceView()
}
