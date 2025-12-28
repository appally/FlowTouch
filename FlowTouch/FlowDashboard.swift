import SwiftUI

// MARK: - FlowDashboard (规则列表主界面)

struct FlowDashboard: View {
    @ObservedObject private var ruleManager = RuleManager.shared
    @ObservedObject private var multitouchManager = MultitouchManager.shared
    @State private var showingAddRule = false
    @State private var editingRule: GestureRule?
    @State private var showingSettings = false
    @State private var searchText = ""

    private var filteredRules: [GestureRule] {
        if searchText.isEmpty {
            return ruleManager.rules
        }
        return ruleManager.rules.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.trigger.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.action.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var enabledRules: [GestureRule] {
        filteredRules.filter { $0.isEnabled }
    }

    private var disabledRules: [GestureRule] {
        filteredRules.filter { !$0.isEnabled }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            DashboardHeader(
                isActive: multitouchManager.status == .active,
                ruleCount: ruleManager.enabledRules.count,
                onSettings: { showingSettings = true }
            )

            Divider()

            // Content
            if ruleManager.rules.isEmpty {
                EmptyRulesView(
                    onAddRule: { showingAddRule = true },
                    onApplyPreset: { preset in
                        switch preset {
                        case .starter:
                            ruleManager.applyStarterPreset()
                        case .full:
                            ruleManager.applyFullPreset()
                        }
                    }
                )
            } else {
                VStack(spacing: 0) {
                    // Search and Add
                    SearchAndAddBar(
                        searchText: $searchText,
                        onAdd: { showingAddRule = true }
                    )

                    // Rules List
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // Enabled Rules
                            if !enabledRules.isEmpty {
                                RuleSection(
                                    title: "已启用",
                                    count: enabledRules.count,
                                    color: .green
                                ) {
                                    ForEach(enabledRules) { rule in
                                        RuleCard(
                                            rule: rule,
                                            onToggle: { ruleManager.toggleRule(rule) },
                                            onEdit: { editingRule = rule },
                                            onDelete: { ruleManager.deleteRule(rule) },
                                            onDuplicate: { ruleManager.duplicateRule(rule) },
                                            onTest: { testRule(rule) }
                                        )
                                    }
                                }
                            }

                            // Disabled Rules
                            if !disabledRules.isEmpty {
                                RuleSection(
                                    title: "已停用",
                                    count: disabledRules.count,
                                    color: .gray
                                ) {
                                    ForEach(disabledRules) { rule in
                                        RuleCard(
                                            rule: rule,
                                            onToggle: { ruleManager.toggleRule(rule) },
                                            onEdit: { editingRule = rule },
                                            onDelete: { ruleManager.deleteRule(rule) },
                                            onDuplicate: { ruleManager.duplicateRule(rule) },
                                            onTest: { testRule(rule) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddRule) {
            AddRuleSheet(onDismiss: { showingAddRule = false })
        }
        .sheet(item: $editingRule) { rule in
            EditRuleSheet(rule: rule, onDismiss: { editingRule = nil })
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func testRule(_ rule: GestureRule) {
        let action = rule.action
        if let snapDir = action.snapDirection {
            WindowManager.shared.snapFocusedWindow(direction: snapDir)
        } else if action == .minimize {
            WindowManager.shared.minimizeFocusedWindow()
        } else if action == .close {
            WindowManager.shared.closeFocusedWindow()
        } else if action == .fullscreen {
            WindowManager.shared.toggleFullscreen()
        }
        FeedbackHUD.shared.flashAction(text: action.shortName)
    }
}

// MARK: - Dashboard Header

struct DashboardHeader: View {
    let isActive: Bool
    let ruleCount: Int
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .shadow(color: isActive ? .green.opacity(0.5) : .clear, radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("FlowTouch")
                        .font(.headline)

                    Text(isActive ? "\(ruleCount) 条规则生效中" : "未激活")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Settings Button
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Search and Add Bar

struct SearchAndAddBar: View {
    @Binding var searchText: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("搜索规则...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Add Button
            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("添加规则")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}

// MARK: - Rule Section

struct RuleSection<Content: View>: View {
    let title: String
    let count: Int
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            content
        } header: {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

// MARK: - Rule Card

struct RuleCard: View {
    let rule: GestureRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onTest: () -> Void

    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 16) {
            // Trigger Icon
            TriggerIconView(trigger: rule.trigger, isEnabled: rule.isEnabled)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Trigger → Action
                HStack(spacing: 6) {
                    Text(rule.trigger.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(rule.action.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(rule.isEnabled ? .blue : .secondary)
                }

                // Scope Badge
                ScopeBadge(scope: rule.scope)
            }

            Spacer()

            // Actions (visible on hover or always on touch)
            HStack(spacing: 8) {
                if isHovered {
                    // Test Button
                    IconButton(icon: "play.fill", color: .green, tooltip: "测试") {
                        onTest()
                    }

                    // Edit Button
                    IconButton(icon: "pencil", color: .orange, tooltip: "编辑") {
                        onEdit()
                    }

                    // Delete Button
                    IconButton(icon: "trash", color: .red, tooltip: "删除") {
                        showDeleteConfirm = true
                    }
                }

                // Toggle
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rule.isEnabled
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    rule.isEnabled ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1),
                    lineWidth: 1
                )
        )
        .opacity(rule.isEnabled ? 1 : 0.7)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button { onTest() } label: {
                Label("测试规则", systemImage: "play.fill")
            }
            Button { onEdit() } label: {
                Label("编辑规则", systemImage: "pencil")
            }
            Button { onDuplicate() } label: {
                Label("复制规则", systemImage: "doc.on.doc")
            }
            Divider()
            Button { onToggle() } label: {
                Label(rule.isEnabled ? "停用规则" : "启用规则",
                      systemImage: rule.isEnabled ? "pause.circle" : "play.circle")
            }
            Divider()
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("删除规则", systemImage: "trash")
            }
        }
        .confirmationDialog("确定删除这条规则？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) { onDelete() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("\(rule.trigger.displayName) → \(rule.action.displayName)")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Trigger Icon View

struct TriggerIconView: View {
    let trigger: GestureTrigger
    let isEnabled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isEnabled ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                .frame(width: 50, height: 50)

            VStack(spacing: 4) {
                Image(systemName: trigger.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isEnabled ? .blue : .gray)

                // Finger dots
                if trigger.type != .pinch {
                    HStack(spacing: 2) {
                        ForEach(0..<trigger.fingerCount, id: \.self) { _ in
                            Circle()
                                .fill(isEnabled ? Color.blue : Color.gray)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Scope Badge

struct ScopeBadge: View {
    let scope: RuleScope

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scope.icon)
                .font(.system(size: 10))

            Text(scope.displayName)
                .font(.system(size: 11))
        }
        .foregroundColor(scope.isGlobal ? .secondary : .purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(scope.isGlobal ? Color.gray.opacity(0.1) : Color.purple.opacity(0.1))
        )
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let color: Color
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Empty Rules View

enum RulePreset {
    case starter
    case full
}

struct EmptyRulesView: View {
    let onAddRule: () -> Void
    let onApplyPreset: (RulePreset) -> Void

    @State private var animateHand = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Hero Animation
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 140)

                Image(systemName: "hand.draw")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(animateHand ? -8 : 8))
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animateHand)
            }
            .onAppear { animateHand = true }

            // Title
            VStack(spacing: 10) {
                Text("创建你的第一条规则")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("定义一个手势，然后选择它触发的动作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Quick Presets
            VStack(spacing: 14) {
                PresetButton(
                    title: "极简模式",
                    subtitle: "3 条核心规则，快速上手",
                    items: ["3指左滑 → 左半屏", "3指右滑 → 右半屏", "3指上滑 → 最大化"],
                    isRecommended: true
                ) {
                    onApplyPreset(.starter)
                }

                PresetButton(
                    title: "完整模式",
                    subtitle: "8 条规则，覆盖所有方向",
                    items: ["包含四角、四边全部 8 个方向"],
                    isRecommended: false
                ) {
                    onApplyPreset(.full)
                }
            }
            .frame(maxWidth: 420)

            // Or create custom
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                Text("或者")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
            }
            .frame(maxWidth: 300)

            Button(action: onAddRule) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("自定义规则")
                }
                .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(32)
    }
}

struct PresetButton: View {
    let title: String
    let subtitle: String
    let items: [String]
    let isRecommended: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)

                        if isRecommended {
                            Text("推荐")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items, id: \.self) { item in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text(item)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHovered ? Color.gray.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isRecommended ? Color.blue.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: isRecommended ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Add Rule Sheet

struct AddRuleSheet: View {
    let onDismiss: () -> Void

    @ObservedObject private var ruleManager = RuleManager.shared
    @State private var step: Int = 1

    // Step 1: Trigger
    @State private var triggerType: GestureTrigger.TriggerType = .swipe
    @State private var fingerCount: Int = 3
    @State private var swipeDirection: SwipeDirection = .left
    @State private var tapType: TapType = .doubleTap
    @State private var pinchDirection: PinchDirection = .pinchOut

    // Step 2: Action
    @State private var selectedAction: WindowAction = .snapLeft

    // Step 3: Scope
    @State private var scopeType: ScopeType = .global
    @State private var selectedApp: RunningApp?

    enum ScopeType {
        case global
        case app
    }

    private var currentTrigger: GestureTrigger {
        switch triggerType {
        case .swipe:
            return .swipe(fingers: fingerCount, direction: swipeDirection)
        case .tap:
            return .tap(fingers: fingerCount, tapType: tapType)
        case .pinch:
            return .pinch(direction: pinchDirection)
        }
    }

    private var conflictRule: GestureRule? {
        let scope: RuleScope = scopeType == .global ? .global :
            (selectedApp.map { .app(bundleId: $0.id, appName: $0.name) } ?? .global)
        return ruleManager.checkConflict(trigger: currentTrigger, scope: scope)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader(
                title: "添加规则",
                step: step,
                totalSteps: 3,
                onCancel: onDismiss
            )

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 28) {
                    switch step {
                    case 1:
                        TriggerStepView(
                            triggerType: $triggerType,
                            fingerCount: $fingerCount,
                            swipeDirection: $swipeDirection,
                            tapType: $tapType,
                            pinchDirection: $pinchDirection
                        )
                    case 2:
                        ActionStepView(selectedAction: $selectedAction)
                    case 3:
                        ScopeStepView(
                            scopeType: $scopeType,
                            selectedApp: $selectedApp
                        )
                    default:
                        EmptyView()
                    }

                    // Conflict Warning
                    if let conflict = conflictRule {
                        ConflictWarning(existingRule: conflict)
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            SheetFooter(
                step: step,
                totalSteps: 3,
                canProceed: true,
                onBack: { step -= 1 },
                onNext: { step += 1 },
                onFinish: createRule
            )
        }
        .frame(width: 480, height: 560)
    }

    private func createRule() {
        let trigger = currentTrigger
        let scope: RuleScope = scopeType == .global ? .global :
            (selectedApp.map { .app(bundleId: $0.id, appName: $0.name) } ?? .global)

        let rule = GestureRule(
            trigger: trigger,
            action: selectedAction,
            scope: scope
        )

        ruleManager.addRule(rule)
        onDismiss()
    }
}

// MARK: - Edit Rule Sheet

struct EditRuleSheet: View {
    let rule: GestureRule
    let onDismiss: () -> Void

    @ObservedObject private var ruleManager = RuleManager.shared

    @State private var triggerType: GestureTrigger.TriggerType
    @State private var fingerCount: Int
    @State private var swipeDirection: SwipeDirection
    @State private var tapType: TapType
    @State private var pinchDirection: PinchDirection
    @State private var selectedAction: WindowAction
    @State private var scopeType: AddRuleSheet.ScopeType
    @State private var selectedApp: RunningApp?

    init(rule: GestureRule, onDismiss: @escaping () -> Void) {
        self.rule = rule
        self.onDismiss = onDismiss

        _triggerType = State(initialValue: rule.trigger.type)
        _fingerCount = State(initialValue: rule.trigger.fingerCount)
        _swipeDirection = State(initialValue: rule.trigger.swipeDirection ?? .left)
        _tapType = State(initialValue: rule.trigger.tapType ?? .doubleTap)
        _pinchDirection = State(initialValue: rule.trigger.pinchDirection ?? .pinchOut)
        _selectedAction = State(initialValue: rule.action)

        switch rule.scope {
        case .global:
            _scopeType = State(initialValue: .global)
            _selectedApp = State(initialValue: nil)
        case .app(let bundleId, let appName):
            _scopeType = State(initialValue: .app)
            _selectedApp = State(initialValue: RunningApp(id: bundleId, name: appName, icon: nil))
        }
    }

    private var currentTrigger: GestureTrigger {
        switch triggerType {
        case .swipe:
            return .swipe(fingers: fingerCount, direction: swipeDirection)
        case .tap:
            return .tap(fingers: fingerCount, tapType: tapType)
        case .pinch:
            return .pinch(direction: pinchDirection)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("取消") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                Spacer()

                Text("编辑规则")
                    .font(.headline)

                Spacer()

                Button("保存") { saveRule() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Trigger
                    GroupBox("手势触发器") {
                        TriggerStepView(
                            triggerType: $triggerType,
                            fingerCount: $fingerCount,
                            swipeDirection: $swipeDirection,
                            tapType: $tapType,
                            pinchDirection: $pinchDirection
                        )
                    }

                    // Action
                    GroupBox("执行动作") {
                        ActionStepView(selectedAction: $selectedAction)
                    }

                    // Scope
                    GroupBox("作用域") {
                        ScopeStepView(
                            scopeType: $scopeType,
                            selectedApp: $selectedApp
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 620)
    }

    private func saveRule() {
        let trigger = currentTrigger
        let scope: RuleScope = scopeType == .global ? .global :
            (selectedApp.map { .app(bundleId: $0.id, appName: $0.name) } ?? .global)

        var updatedRule = rule
        updatedRule.trigger = trigger
        updatedRule.action = selectedAction
        updatedRule.scope = scope

        ruleManager.updateRule(updatedRule)
        onDismiss()
    }
}

// MARK: - Sheet Components

struct SheetHeader: View {
    let title: String
    let step: Int
    let totalSteps: Int
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("取消") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                Spacer()

                Text(title)
                    .font(.headline)

                Spacer()

                // Placeholder for alignment
                Text("取消").opacity(0)
            }

            // Step Indicator
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { s in
                    Circle()
                        .fill(s <= step ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)

                    if s < totalSteps {
                        Rectangle()
                            .fill(s < step ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 2)
                    }
                }
            }
        }
        .padding()
    }
}

struct SheetFooter: View {
    let step: Int
    let totalSteps: Int
    let canProceed: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack {
            if step > 1 {
                Button("上一步") { onBack() }
                    .buttonStyle(.bordered)
            }

            Spacer()

            if step < totalSteps {
                Button("下一步") { onNext() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
            } else {
                Button("创建规则") { onFinish() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
            }
        }
        .padding()
    }
}

// MARK: - Step Views

struct TriggerStepView: View {
    @Binding var triggerType: GestureTrigger.TriggerType
    @Binding var fingerCount: Int
    @Binding var swipeDirection: SwipeDirection
    @Binding var tapType: TapType
    @Binding var pinchDirection: PinchDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Step Title
            VStack(alignment: .leading, spacing: 6) {
                Text("选择手势")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("当你执行这个手势时触发规则")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 1. Finger Count (first)
            VStack(alignment: .leading, spacing: 10) {
                Text("手指数量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    ForEach([2, 3, 4], id: \.self) { count in
                        FingerCountCard(
                            count: count,
                            isSelected: fingerCount == count,
                            action: { fingerCount = count }
                        )
                    }
                }
            }

            // 2. Gesture Type (second)
            VStack(alignment: .leading, spacing: 10) {
                Text("手势类型")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ForEach(GestureTrigger.TriggerType.allCases, id: \.self) { type in
                        GestureTypeCard(
                            type: type,
                            isSelected: triggerType == type,
                            action: { triggerType = type }
                        )
                    }
                }
            }

            // 3. Type-specific options (direction/tap type)
            switch triggerType {
            case .swipe:
                SwipeDirectionSection(direction: $swipeDirection)
            case .tap:
                TapTypeSection(tapType: $tapType)
            case .pinch:
                PinchOptionsSection(direction: $pinchDirection)
            }
        }
    }
}

struct GestureTypeCard: View {
    let type: GestureTrigger.TriggerType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 26))
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct SwipeDirectionSection: View {
    @Binding var direction: SwipeDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("滑动方向")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            DirectionGrid(selected: $direction)
        }
    }
}

struct FingerCountCard: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.white : Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                Text("\(count)指")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct DirectionGrid: View {
    @Binding var selected: SwipeDirection

    private let grid: [[SwipeDirection?]] = [
        [.topLeft, .up, .topRight],
        [.left, nil, .right],
        [.bottomLeft, .down, .bottomRight]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        if let dir = grid[row][col] {
                            DirectionCell(
                                direction: dir,
                                isSelected: selected == dir,
                                action: { selected = dir }
                            )
                        } else {
                            CenterCell()
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

struct DirectionCell: View {
    let direction: SwipeDirection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

struct CenterCell: View {
    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.1))
            .frame(width: 52, height: 52)
            .overlay(
                Image(systemName: "hand.point.up.fill")
                    .foregroundColor(.blue.opacity(0.5))
            )
    }
}

struct TapTypeSection: View {
    @Binding var tapType: TapType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("点击次数")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(TapType.allCases) { type in
                    TapTypeCard(
                        type: type,
                        isSelected: tapType == type,
                        action: { tapType = type }
                    )
                }
            }
        }
    }
}

struct TapTypeCard: View {
    let type: TapType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<type.tapCount, id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.white : Color.purple)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.purple : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct PinchOptionsSection: View {
    @Binding var direction: PinchDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("捏合方向")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(PinchDirection.allCases) { dir in
                    PinchDirectionCard(
                        direction: dir,
                        isSelected: direction == dir,
                        action: { direction = dir }
                    )
                }
            }
        }
    }
}

struct PinchDirectionCard: View {
    let direction: PinchDirection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: direction.icon)
                    .font(.system(size: 28))
                Text(direction.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Step View (Redesigned)

struct ActionStepView: View {
    @Binding var selectedAction: WindowAction

    // Track expanded sections
    @State private var expandedSections: Set<WindowAction.ActionCategory> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Step Title
            VStack(alignment: .leading, spacing: 6) {
                Text("选择动作")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("当手势触发时执行什么操作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Layout Section - Visual Grid
            ActionLayoutSection(
                selectedAction: $selectedAction
            )

            // Window Control Section
            ActionWindowControlSection(
                selectedAction: $selectedAction
            )

            Divider()

            // Collapsible sections for other categories
            ForEach(collapsibleCategories, id: \.self) { category in
                ActionCollapsibleSection(
                    category: category,
                    selectedAction: $selectedAction,
                    isExpanded: expandedSections.contains(category),
                    onToggle: { toggleSection(category) }
                )
            }
        }
    }

    private var collapsibleCategories: [WindowAction.ActionCategory] {
        [.multiMonitor, .desktop, .apps, .custom]
    }

    private func toggleSection(_ category: WindowAction.ActionCategory) {
        if expandedSections.contains(category) {
            expandedSections.remove(category)
        } else {
            expandedSections.insert(category)
        }
    }
}

// MARK: - Action Layout Section

struct ActionLayoutSection: View {
    @Binding var selectedAction: WindowAction

    private let halfScreenActions: [WindowAction] = [.snapLeft, .snapRight, .snapTop, .snapBottom]
    private let quarterScreenActions: [WindowAction] = [.snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("窗口布局")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            // Half screen row
            VStack(alignment: .leading, spacing: 6) {
                Text("半屏")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    ForEach(halfScreenActions) { action in
                        ActionGridCell(
                            action: action,
                            isSelected: selectedAction == action,
                            color: .blue,
                            onSelect: { selectedAction = action }
                        )
                    }
                }
            }

            // Quarter screen row
            VStack(alignment: .leading, spacing: 6) {
                Text("四分屏")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    ForEach(quarterScreenActions) { action in
                        ActionGridCell(
                            action: action,
                            isSelected: selectedAction == action,
                            color: .blue,
                            onSelect: { selectedAction = action }
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Action Window Control Section

struct ActionWindowControlSection: View {
    @Binding var selectedAction: WindowAction

    private let primaryActions: [WindowAction] = [.maximize, .center, .restore, .minimize]
    private let secondaryActions: [WindowAction] = [.close, .fullscreen, .maximizeHeight, .maximizeWidth]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "macwindow")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)
                Text("窗口控制")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            // Primary actions row
            HStack(spacing: 8) {
                ForEach(primaryActions) { action in
                    ActionGridCell(
                        action: action,
                        isSelected: selectedAction == action,
                        color: .purple,
                        onSelect: { selectedAction = action }
                    )
                }
            }

            // Secondary actions row
            HStack(spacing: 8) {
                ForEach(secondaryActions) { action in
                    ActionGridCell(
                        action: action,
                        isSelected: selectedAction == action,
                        color: .purple,
                        onSelect: { selectedAction = action }
                    )
                }
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Action Grid Cell

struct ActionGridCell: View {
    let action: WindowAction
    let isSelected: Bool
    let color: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : color)

                Text(action.shortName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : (isHovered ? color.opacity(0.1) : Color.gray.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Action Collapsible Section

struct ActionCollapsibleSection: View {
    let category: WindowAction.ActionCategory
    @Binding var selectedAction: WindowAction
    let isExpanded: Bool
    let onToggle: () -> Void

    private var actions: [WindowAction] {
        category.actions
    }

    private var categoryColor: Color {
        switch category {
        case .layout: return .blue
        case .window: return .purple
        case .multiMonitor: return .orange
        case .desktop: return .green
        case .apps: return .red
        case .custom: return .indigo
        case .other: return .gray
        }
    }

    private var hasSelectedAction: Bool {
        actions.contains(selectedAction)
    }

    var body: some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Collapsible header
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 12)

                        Image(systemName: category.icon)
                            .font(.system(size: 12))
                            .foregroundColor(categoryColor)

                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)

                        if hasSelectedAction {
                            Circle()
                                .fill(categoryColor)
                                .frame(width: 6, height: 6)
                        }

                        Spacer()

                        Text("\(actions.count)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Expanded content
                if isExpanded {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(actions) { action in
                            ActionGridCell(
                                action: action,
                                isSelected: action == selectedAction,
                                color: categoryColor,
                                onSelect: { selectedAction = action }
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

// MARK: - Legacy Action Cell (kept for compatibility)

struct ActionCell: View {
    let action: WindowAction
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 18))

                Text(action.shortName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scope Step View

struct ScopeStepView: View {
    @Binding var scopeType: AddRuleSheet.ScopeType
    @Binding var selectedApp: RunningApp?

    @State private var availableApps: [RunningApp] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Step Title
            VStack(alignment: .leading, spacing: 6) {
                Text("设置作用域")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("规则在什么情况下生效")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Scope Type Selection
            VStack(spacing: 12) {
                ScopeOptionCard(
                    title: "全局",
                    subtitle: "在所有应用中生效",
                    icon: "globe",
                    isSelected: scopeType == .global,
                    action: { scopeType = .global }
                )

                ScopeOptionCard(
                    title: "特定应用",
                    subtitle: "仅在选定的应用中生效",
                    icon: "app.fill",
                    isSelected: scopeType == .app,
                    action: { scopeType = .app }
                )
            }

            // App Selection (if app scope)
            if scopeType == .app {
                VStack(alignment: .leading, spacing: 10) {
                    Text("选择应用")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(availableApps) { app in
                                AppSelectionRow(
                                    app: app,
                                    isSelected: selectedApp?.id == app.id,
                                    action: { selectedApp = app }
                                )
                            }
                        }
                    }
                    .frame(height: 180)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
        .onAppear {
            availableApps = RunningApp.getRunningApps()
        }
    }
}

struct ScopeOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AppSelectionRow: View {
    let app: RunningApp
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                }

                Text(app.name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conflict Warning

struct ConflictWarning: View {
    let existingRule: GestureRule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("手势冲突")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("此手势已用于「\(existingRule.action.displayName)」")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("创建后将替换原有规则")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}
