//
//  ContentView.swift
//  FlowTouch
//
//  Created by Appally on 2025/12/27.
//

import SwiftUI
import UniformTypeIdentifiers



// MARK: - Content View

struct ContentView: View {
    @ObservedObject var manager = MultitouchManager.shared
    @ObservedObject var localization = LocalizationManager.shared

    var body: some View {
        Group {
            switch manager.status {
            case .active, .awaitingTouch:
                MainView()

            case .permissionDenied, .accessibilityDenied:
                PermissionGuidanceView()

            case .noDeviceFound:
                NoDeviceView()

            case .unknown:
                InitializingView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.locale, localization.locale)
    }
}

// MARK: - Main View

struct MainView: View {
    var body: some View {
        FlowDashboard()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var configManager = ConfigurationManager.shared
    @ObservedObject var ruleManager = RuleManager.shared
    @ObservedObject var multitouchManager = MultitouchManager.shared
    @ObservedObject var appSettings = AppSettings.shared
    @ObservedObject var localization = LocalizationManager.shared

    @State private var showingExportSuccess = false
    @State private var showingImportPicker = false
    @State private var showingResetConfirmation = false
    @State private var showingLearningMode = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("设置"))
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Text(L("完成"))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section {
                    Picker(selection: $localization.language, label: Text(L("语言"))) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(L("语言"))
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { LaunchAtLoginManager.shared.isEnabled },
                        set: { LaunchAtLoginManager.shared.isEnabled = $0 }
                    )) {
                        Text(L("登录时启动"))
                    }
                } header: {
                    Text(L("启动"))
                }

                Section {
                    Toggle(isOn: $appSettings.showDockIcon) {
                        Text(L("在程序坞中显示图标"))
                    }
                    Toggle(isOn: $appSettings.showMenuBarIcon) {
                        Text(L("在菜单中显示图标"))
                    }
                } header: {
                    Text(L("程序坞"))
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L("滑动阈值"))
                            Spacer()
                            Text(String(format: "%.2f", configManager.config.swipeThreshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $configManager.config.swipeThreshold, in: 0.06...0.25, step: 0.01)
                    }
                } header: {
                    Text(L("灵敏度"))
                }

                Section {
                    HStack {
                        Text(L("输入监控"))
                        Spacer()
                        if multitouchManager.hasInputMonitoring {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(L("已授权"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(action: { multitouchManager.requestInputMonitoringPermission() }) {
                                Text(L("授权"))
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    HStack {
                        Text(L("辅助功能"))
                        Spacer()
                        if multitouchManager.hasAccessibility {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(L("已授权"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(action: { multitouchManager.requestAccessibilityPermission() }) {
                                Text(L("授权"))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    Text(L("权限状态"))
                }

                // System gesture conflicts warning
                if !multitouchManager.systemGestureConflicts.isEmpty {
                    Section {
                        ForEach(multitouchManager.systemGestureConflicts) { conflict in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                    Text(L("手势冲突"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                Text(String(format: L("system_gesture_conflict_format"), conflict.systemGesture, conflict.flowTouchGesture))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(conflict.suggestion)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 4)
                        }

                        Button(action: {
                            multitouchManager.openTrackpadSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text(L("打开触控板设置"))
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(L("系统手势冲突"))
                        }
                    }
                }

                Section {
                    HStack {
                        Text(L("当前规则数"))
                        Spacer()
                        Text("\(ruleManager.rules.count) \(L("条"))")
                            .foregroundColor(.secondary)
                    }

                    Button(action: exportRules) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(L("导出规则"))
                        }
                    }

                    Button(action: { showingImportPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text(L("导入规则"))
                        }
                    }
                } header: {
                    Text(L("规则管理"))
                }

                Section {
                    Button(L("重置规则为默认"), role: .destructive) {
                        showingResetConfirmation = true
                    }
                } header: {
                    Text(L("数据"))
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 480)
        .alert(L("导出成功"), isPresented: $showingExportSuccess) {
            Button(L("确定"), role: .cancel) { }
        } message: {
            Text(L("规则已成功导出"))
        }
        .alert(L("导入失败"), isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button(L("确定"), role: .cancel) { }
        } message: {
            Text(importError ?? "")
        }
        .confirmationDialog(L("确定要重置所有规则吗？"), isPresented: $showingResetConfirmation) {
            Button(L("重置"), role: .destructive) {
                ruleManager.clearAllRules()
            }
            Button(L("取消"), role: .cancel) { }
        } message: {
            Text(L("这将删除所有自定义规则。"))
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        if ruleManager.importRules(from: data, replace: false) {
                            // Success
                        } else {
                            importError = L("无效的规则文件格式")
                        }
                    } catch {
                        importError = "\(L("读取文件失败")): \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                importError = "\(L("选择文件失败")): \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showingLearningMode) {
            GestureLearningView()
        }
        .onAppear {
            // Check for system gesture conflicts when settings open
            multitouchManager.checkSystemGestureConflicts()
        }
    }

    private func exportRules() {
        guard let data = ruleManager.exportRules() else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "FlowTouch_Rules_\(dateString).json"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.title = L("导出规则")

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                DispatchQueue.main.async {
                    self.showingExportSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.importError = "\(L("导出失败")): \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Gesture Learning View

struct GestureLearningView: View {
    @Environment(\.dismiss) var dismiss
    @State private var recognizedGestures: [(gesture: String, action: String, time: Date)] = []
    @State private var isActive = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("手势学习模式")
                        .font(.headline)
                    Text("在触控板上尝试手势，查看识别结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("完成") {
                    stopLearning()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Status indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(isActive ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .shadow(color: isActive ? .green.opacity(0.5) : .clear, radius: 4)

                Text(isActive ? L("学习模式已启用 - 手势不会执行动作") : L("正在启动..."))
                    .font(.subheadline)
                    .foregroundColor(isActive ? .primary : .secondary)

                Spacer()

                if !recognizedGestures.isEmpty {
                    Button("清空记录") {
                        recognizedGestures.removeAll()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.05))

            // Gesture history
            if recognizedGestures.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "hand.draw")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("在触控板上尝试手势")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("支持滑动、点击、捏合手势")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
            } else {
                List {
                    ForEach(recognizedGestures.reversed().indices, id: \.self) { index in
                        let item = recognizedGestures.reversed()[index]
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.gesture)
                                    .font(.system(.body, weight: .medium))
                                Text("→ \(item.action)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatTime(item.time))
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 400, height: 450)
        .onAppear {
            startLearning()
        }
        .onDisappear {
            stopLearning()
        }
    }

    private func startLearning() {
        GestureEngine.shared.enableLearningMode { gesture, action in
            DispatchQueue.main.async {
                recognizedGestures.append((gesture: gesture, action: action, time: Date()))
            }
        }
        isActive = true
    }

    private func stopLearning() {
        GestureEngine.shared.disableLearningMode()
        isActive = false
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct NoDeviceView: View {
    @ObservedObject var manager = MultitouchManager.shared
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("未找到触控板")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("请连接 Magic Trackpad 或使用 MacBook 内置触控板")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: retryConnection) {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isRetrying ? L("正在检测...") : L("重新检测"))
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrying)

                // Permission check hint
                if !manager.hasInputMonitoring {
                    VStack(spacing: 4) {
                        Text("可能是权限问题")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Button("检查输入监控权限") {
                            manager.requestInputMonitoringPermission()
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private func retryConnection() {
        isRetrying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MultitouchManager.shared.checkDevices()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isRetrying = false
            }
        }
    }
}

struct InitializingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("正在启动...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
