import SwiftUI
import Carbon

// MARK: - Design System

/// 语义化颜色系统，确保与 macOS 原生风格一致
/// 语义化颜色系统，确保与 macOS 原生风格一致
private enum DS {
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let contentBackground = Color(nsColor: .controlBackgroundColor) // Main content area
}

// MARK: - Navigation Items
enum SidebarItem: String, CaseIterable, Identifiable {
    case all = "所有规则"
    case enabled = "已启用"
    case disabled = "已停用"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .enabled: return "checkmark.circle"
        case .disabled: return "pause.circle"
        }
    }
}


// MARK: - FlowDashboard (规则列表主界面)

struct FlowDashboard: View {
    @ObservedObject private var ruleManager = RuleManager.shared
    @ObservedObject private var multitouchManager = MultitouchManager.shared
    
    @State private var selection: SidebarItem? = .all
    @State private var showingAddRule = false
    @State private var editingRule: GestureRule?
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            Group {
                if ruleManager.rules.isEmpty {
                    EmptyStateView(onAdd: { showingAddRule = true })
                } else {
                    RuleListView(
                        selection: selection ?? .all,
                        searchText: searchText,
                        onEdit: { editingRule = $0 },
                        onAdd: { showingAddRule = true }
                    )
                }
            }
            .navigationTitle(LocalizedStringKey(selection?.rawValue ?? "FlowTouch"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddRule = true }) {
                        Label("添加规则", systemImage: "plus")
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if isSearchVisible {
                        HStack(spacing: 6) {
                            TextField("搜索规则...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 180, maxWidth: 260)
                                .focused($isSearchFocused)
                                .onSubmit {
                                    if searchText.isEmpty {
                                        isSearchVisible = false
                                    }
                                }

                            Button {
                                searchText = ""
                                isSearchVisible = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("关闭搜索")
                        }
                        .onAppear {
                            DispatchQueue.main.async { isSearchFocused = true }
                        }
                    } else {
                        Button {
                            isSearchVisible = true
                            DispatchQueue.main.async { isSearchFocused = true }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .help("搜索")
                    }

                    Button(action: { showingSettings = true }) {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
        }
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
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @ObservedObject private var ruleManager = RuleManager.shared
    @ObservedObject private var multitouchManager = MultitouchManager.shared
    
    var body: some View {
        List(selection: $selection) {
            Section("规则") {
                ForEach(SidebarItem.allCases) { item in
                    NavigationLink(value: item) {
                        SidebarRow(item: item, selection: selection, ruleManager: ruleManager)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            statusPill
        }
    }
    
    // MARK: - Status Pill
    private var statusPill: some View {
        let isActive = multitouchManager.status == .active
        return HStack(spacing: 8) {
            BreathingIndicator(isActive: isActive)
                .frame(width: 6, height: 6)

            Text(LocalizedStringKey(isActive ? "FlowTouch 运行中" : "未激活"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Image(systemName: isActive ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 10))
                .foregroundColor(isActive ? .green.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Sidebar Row
private struct SidebarRow: View {
    let item: SidebarItem
    let selection: SidebarItem?
    let ruleManager: RuleManager
    
    private var count: Int {
        switch item {
        case .all: return ruleManager.rules.count
        case .enabled: return ruleManager.enabledRules.count
        case .disabled: return ruleManager.disabledRules.count
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .font(.system(size: 14))
            Text(LocalizedStringKey(item.rawValue))
                .font(.system(size: 13))
            
            Spacer()
            
            if item != .disabled {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(selection == item ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(selection == item ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Breathing Indicator

struct BreathingIndicator: View {
    let isActive: Bool
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.orange)
            .frame(width: 8, height: 8)
            .shadow(color: isActive ? Color.green.opacity(0.6) : .clear, radius: isActive ? 4 : 0)
            .opacity(isAnimating && isActive ? 1.0 : 0.6)
            .scaleEffect(isAnimating && isActive ? 1.1 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                } else {
                    withAnimation(.default) {
                        isAnimating = false
                    }
                }
            }
    }
}

// MARK: - Rule List View

struct RuleListView: View {
    let selection: SidebarItem
    let searchText: String
    let onEdit: (GestureRule) -> Void
    let onAdd: () -> Void
    
    @ObservedObject private var ruleManager = RuleManager.shared
    
    private var filteredRules: [GestureRule] {
        let rules = ruleManager.rules
        let categoryFiltered: [GestureRule]
        
        switch selection {
        case .all: categoryFiltered = rules
        case .enabled: categoryFiltered = rules.filter { $0.isEnabled }
        case .disabled: categoryFiltered = rules.filter { !$0.isEnabled }
        }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.trigger.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.action.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredRules) { rule in
                RuleRow(rule: rule, onEdit: { onEdit(rule) })
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .contextMenu {
                        Button("编辑") { onEdit(rule) }
                        Button("复制") { ruleManager.duplicateRule(rule) }
                        Divider()
                        Button(role: .destructive) { ruleManager.deleteRule(rule) } label: {
                            Text("删除")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Rule Row

struct RuleRow: View {
    let rule: GestureRule
    let onEdit: () -> Void
    @ObservedObject private var ruleManager = RuleManager.shared
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                categoryColor(for: rule.action).opacity(rule.isEnabled ? 0.15 : 0.05),
                                categoryColor(for: rule.action).opacity(rule.isEnabled ? 0.05 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42) // Slightly larger container
                    .overlay(
                        Circle()
                            .stroke(categoryColor(for: rule.action).opacity(rule.isEnabled ? 0.3 : 0.05), lineWidth: 1)
                    )
                
                Image(systemName: rule.trigger.icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(rule.isEnabled ? categoryColor(for: rule.action) : .secondary)
            }
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.trigger.displayName)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                
                Text(rule.action.displayName)
                    .font(.caption)
                    .foregroundColor(rule.isEnabled ? .secondary : .secondary.opacity(0.6))
            }
            
            Spacer()
            
            // Scope Badge (if applicable, e.g. App icon)
            if case .app(let bundleId, let name) = rule.scope {
                HStack(spacing: 4) {
                    if let appIcon = getAppIcon(bundleId: bundleId) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.caption2)
                    }
                    Text(name)
                        .font(.caption2)
                }
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08)) // Lighter background for better icon contrast
                .cornerRadius(4)
                .opacity(rule.isEnabled ? 1 : 0.4)
            }
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in
                    withAnimation(.spring(response: 0.3)) {
                        ruleManager.toggleRule(rule)
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .opacity(isHovering || !rule.isEnabled ? 1 : 0.6) // Subtle fade when not hovering
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle()) // Make the whole row tappable/hoverable
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hover
            }
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .opacity(rule.isEnabled ? 1.0 : 0.6) // Dim entire row when disabled
        .scaleEffect(isHovering ? 1.005 : 1.0) // Micro scale on hover
    }
    
    private func getAppIcon(bundleId: String) -> NSImage? {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appUrl.path)
        }
        return nil
    }
    
    private func categoryColor(for action: WindowAction) -> Color {
        switch action.category {
        case .layout: return .blue
        case .window: return .purple
        case .multiMonitor: return .orange
        case .desktop: return .green
        case .apps: return .pink
        case .tabs: return .cyan
        case .media: return .pink
        case .screenshot: return .yellow
        case .custom: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("没有相关规则")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button("添加规则") {
                onAdd()
            }
            .controlSize(.large)
        }
        .padding()
    }
}


// MARK: - Add Rule Sheet


// MARK: - Add Rule Sheet

struct AddRuleSheet: View {
    let onDismiss: () -> Void
    @ObservedObject private var ruleManager = RuleManager.shared
    
    @State private var triggerType: GestureTrigger.TriggerType = .swipe
    @State private var fingerCount: Int = 3
    @State private var swipeDirection: SwipeDirection = .left
    @State private var tapType: TapType = .doubleTap
    @State private var pinchDirection: PinchDirection = .pinchOut
    
    @State private var selectedAction: WindowAction = .snapLeft
    @State private var scopeType: ScopeType = .global
    @State private var selectedApp: RunningApp?
    
    // Conflict State
    @State private var conflictingRule: GestureRule?
    
    // Helper ID for custom shortcut recording
    @State private var tempRuleId = UUID()
    
    enum ScopeType: String, CaseIterable, Identifiable {
        case global = "全局"
        case app = "特定应用"
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .global: return "globe"
            case .app: return "app.fill"
            }
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
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Sheet Header (Outside Form)
                SheetHeaderView(
                    title: "添加规则",
                    subtitle: "配置新的手势触发与执行操作",
                    icon: "plus.circle.fill",
                    color: .secondary, // De-emphasized to look non-interactive
                    onBack: { onDismiss() } // Unified back/close button
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                Form {
                    Section("触发条件") {
                    // Compact Gesture Type Row
                    HStack {
                        Text("手势类型")
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(GestureTrigger.TriggerType.allCases) { type in
                                CompactGestureButton(
                                    icon: type.icon,
                                    label: type.displayName,
                                    isSelected: triggerType == type
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        triggerType = type
                                    }
                                }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // Compact Finger Count Row
                    if triggerType != .pinch {
                        HStack {
                            Text("手指数量")
                            Spacer()
                            HStack(spacing: 0) {
                                ForEach([2, 3, 4], id: \.self) { count in
                                    CompactFingerButton(
                                        count: count,
                                        isSelected: fingerCount == count
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            fingerCount = count
                                        }
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    if triggerType == .swipe {
                        Picker("滑动方向", selection: $swipeDirection) {
                            ForEach(SwipeDirection.allCases) { dir in
                                Label(dir.displayName, systemImage: dir.icon).tag(dir)
                            }
                        }
                    } else if triggerType == .tap {
                        Picker("点击类型", selection: $tapType) {
                            ForEach(TapType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon).tag(type)
                            }
                        }
                    } else if triggerType == .pinch {
                        Picker("捏合方向", selection: $pinchDirection) {
                            ForEach(PinchDirection.allCases) { dir in
                                Label(dir.displayName, systemImage: dir.icon).tag(dir)
                            }
                        }
                    }
                }
                
                Section("执行动作") {
                    NavigationLink {
                        ActionSelectionView(selection: $selectedAction)
                    } label: {
                        HStack {
                            Text("选择操作")
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: selectedAction.icon)
                                    .foregroundColor(.secondary)
                                Text(selectedAction.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if selectedAction == .customShortcut {
                        ShortcutRecorderView(ruleId: tempRuleId)
                    }
                }
                
                Section("生效范围") {
                    Picker("应用范围", selection: $scopeType) {
                        ForEach(ScopeType.allCases) { type in
                            Label(LocalizedStringKey(type.rawValue), systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if scopeType == .app {
                        NavigationLink {
                            AppSelectionView(selectedApp: $selectedApp)
                        } label: {
                            HStack {
                                Text("选择应用")
                                Spacer()
                                if let app = selectedApp {
                                    HStack {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                        }
                                        Text(app.name)
                                            .foregroundColor(.secondary)
                                        Text(app.id)
                                            .foregroundColor(.secondary.opacity(0.5))
                                            .font(.caption)
                                    }
                                } else {
                                    Text("未选择")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                if let conflict = conflictingRule {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Text("此手势已用于「\(conflict.action.displayName)」，保存将会替换")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .formStyle(.grouped)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: triggerType)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scopeType)
            .animation(.easeInOut, value: conflictingRule)
            .onChange(of: triggerType) { _, _ in checkForConflict() }
            .onChange(of: fingerCount) { _, _ in checkForConflict() }
            .onChange(of: swipeDirection) { _, _ in checkForConflict() }
            .onChange(of: tapType) { _, _ in checkForConflict() }
            .onChange(of: pinchDirection) { _, _ in checkForConflict() }
            .onChange(of: scopeType) { _, _ in checkForConflict() }
            .onChange(of: selectedApp) { _, _ in checkForConflict() }
            // Custom header used instead
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                        .buttonStyle(.bordered)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createRule()
                    } label: {
                        Text(conflictingRule != nil ? "替换" : "添加")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(conflictingRule != nil ? .orange : .accentColor)
                    .disabled(scopeType == .app && selectedApp == nil)
                }
            }
        }
        }
        .frame(minWidth: 450, minHeight: 600)
        .onAppear { checkForConflict() }
    }
    

    private func checkForConflict() {
        let trigger = currentTrigger
        let scope: RuleScope = (scopeType == .app && selectedApp != nil) ? 
            .app(bundleId: selectedApp!.id, appName: selectedApp!.name) : .global
            
        conflictingRule = ruleManager.checkConflict(trigger: trigger, scope: scope)
    }
    
    private func createRule() {
        // If conflict exists and user clicks Replace, remove old rule first
        if let conflict = conflictingRule {
            ruleManager.deleteRule(conflict)
        }
        
        let ruleId = UUID()
        let scope: RuleScope = (scopeType == .app && selectedApp != nil) ? 
            .app(bundleId: selectedApp!.id, appName: selectedApp!.name) : .global
        
        let rule = GestureRule(
            id: ruleId,
            trigger: currentTrigger,
            action: selectedAction,
            scope: scope
        )
        
        // Migrate shortcut if needed
        if selectedAction == .customShortcut,
           let shortcut = CustomShortcutManager.shared.getShortcut(for: tempRuleId) {
            CustomShortcutManager.shared.setShortcut(shortcut, for: ruleId)
            CustomShortcutManager.shared.removeShortcut(for: tempRuleId)
        }
        
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
    
    @State private var conflictingRule: GestureRule?
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Sheet Header (与 AddRuleSheet 保持一致)
                SheetHeaderView(
                    title: "编辑规则",
                    subtitle: "修改手势触发与执行操作",
                    icon: "pencil.circle.fill",
                    color: .secondary,
                    onBack: { onDismiss() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                Form {
                Section("触发条件") {
                    // Compact Gesture Type Row (与 AddRuleSheet 保持一致)
                    HStack {
                        Text("手势类型")
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(GestureTrigger.TriggerType.allCases) { type in
                                CompactGestureButton(
                                    icon: type.icon,
                                    label: type.displayName,
                                    isSelected: triggerType == type
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        triggerType = type
                                    }
                                }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // Compact Finger Count Row (与 AddRuleSheet 保持一致)
                    if triggerType != .pinch {
                        HStack {
                            Text("手指数量")
                            Spacer()
                            HStack(spacing: 0) {
                                ForEach([2, 3, 4], id: \.self) { count in
                                    CompactFingerButton(
                                        count: count,
                                        isSelected: fingerCount == count
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            fingerCount = count
                                        }
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    if triggerType == .swipe {
                        Picker("滑动方向", selection: $swipeDirection) {
                            ForEach(SwipeDirection.allCases) { dir in
                                Label(dir.displayName, systemImage: dir.icon).tag(dir)
                            }
                        }
                    } else if triggerType == .tap {
                        Picker("点击类型", selection: $tapType) {
                            ForEach(TapType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon).tag(type)
                            }
                        }
                    } else if triggerType == .pinch {
                        Picker("捏合方向", selection: $pinchDirection) {
                            ForEach(PinchDirection.allCases) { dir in
                                Label(dir.displayName, systemImage: dir.icon).tag(dir)
                            }
                        }
                    }
                }
                
                Section("执行动作") {
                    NavigationLink {
                        ActionSelectionView(selection: $selectedAction)
                    } label: {
                        HStack {
                            Text("选择操作")
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: selectedAction.icon)
                                    .foregroundColor(.secondary)
                                Text(selectedAction.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if selectedAction == .customShortcut {
                        ShortcutRecorderView(ruleId: rule.id)
                    }
                }
                
                Section("生效范围") {
                    Picker("应用范围", selection: $scopeType) {
                        ForEach(AddRuleSheet.ScopeType.allCases) { type in
                            Label(LocalizedStringKey(type.rawValue), systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if scopeType == .app {
                        NavigationLink {
                            AppSelectionView(selectedApp: $selectedApp)
                        } label: {
                            HStack {
                                Text("选择应用")
                                Spacer()
                                if let app = selectedApp {
                                    HStack {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                        }
                                        Text(app.name)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("未选择")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                if let conflict = conflictingRule {
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("手势已被占用")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("当前用于\(conflict.action.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("点击「替换」覆盖现有配置")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .formStyle(.grouped)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: triggerType)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scopeType)
            .animation(.easeInOut, value: conflictingRule)
            .onChange(of: triggerType) { _, _ in checkForConflict() }
            .onChange(of: fingerCount) { _, _ in checkForConflict() }
            .onChange(of: swipeDirection) { _, _ in checkForConflict() }
            .onChange(of: tapType) { _, _ in checkForConflict() }
            .onChange(of: pinchDirection) { _, _ in checkForConflict() }
            .onChange(of: scopeType) { _, _ in checkForConflict() }
            .onChange(of: selectedApp) { _, _ in checkForConflict() }
            // 使用自定义 SheetHeaderView，移除原生 navigationTitle
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                        .buttonStyle(.bordered)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveRule()
                    } label: {
                        Text(conflictingRule != nil ? "替换" : "保存")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(conflictingRule != nil ? .orange : .accentColor)
                    .disabled(scopeType == .app && selectedApp == nil)
                }
            }
        }
        }
        .frame(minWidth: 450, minHeight: 600)
        .onAppear { checkForConflict() }
    }
    
    private func checkForConflict() {
        let trigger: GestureTrigger
        switch triggerType {
        case .swipe:
            trigger = .swipe(fingers: fingerCount, direction: swipeDirection)
        case .tap:
            trigger = .tap(fingers: fingerCount, tapType: tapType)
        case .pinch:
            trigger = .pinch(direction: pinchDirection)
        }
        
        let scope: RuleScope = (scopeType == .app && selectedApp != nil) ? 
            .app(bundleId: selectedApp!.id, appName: selectedApp!.name) : .global
            
        conflictingRule = ruleManager.checkConflict(trigger: trigger, scope: scope, excludingRuleId: rule.id)
    }
    
    private func saveRule() {
        if let conflict = conflictingRule {
            ruleManager.deleteRule(conflict)
        }
        
        var updatedRule = rule
        
        let newTrigger: GestureTrigger
        switch triggerType {
        case .swipe:
            newTrigger = .swipe(fingers: fingerCount, direction: swipeDirection)
        case .tap:
            newTrigger = .tap(fingers: fingerCount, tapType: tapType)
        case .pinch:
            newTrigger = .pinch(direction: pinchDirection)
        }
        
        updatedRule.trigger = newTrigger
        updatedRule.action = selectedAction
        
        let scope: RuleScope = (scopeType == .app && selectedApp != nil) ?
            .app(bundleId: selectedApp!.id, appName: selectedApp!.name) : .global
        updatedRule.scope = scope
        
        ruleManager.updateRule(updatedRule)
        onDismiss()
    }
}

// MARK: - Sheet Header View

struct SheetHeaderView: View {
    let title: String
    let subtitle: String
    let icon: String // SF Symbol
    let color: Color
    var onBack: (() -> Void)? = nil // Optional back action
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
            
            // Minimal Icon - no heavy background
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold)) // Slightly smaller, refined weight
                .foregroundColor(color)
                .frame(width: 24) // Fixed width for alignment
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold)) // Reduced from 20pt Bold to 16pt Semibold for elegance
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 11)) // Smaller, crisp subtitle
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 0) // Align strict with content
    }
}

// MARK: - Compact Gesture Button (Native Segmented Style)

struct CompactGestureButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Finger Button (Native Segmented Style)

struct CompactFingerButton: View {
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? Color.white : Color.accentColor)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gesture Type Card


struct GestureTypeCard: View {
    let type: GestureTrigger.TriggerType
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 52, height: 52)
                        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 6 : 2)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary.opacity(0.7))
                        .rotationEffect(.degrees(isHovering && !isSelected ? 10 : 0))
                }
                
                Text(type.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering && !isSelected ? Color.secondary.opacity(0.08) : Color.clear)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.spring(response: 0.2)) {
                isHovering = hover
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Finger Count Card

struct FingerCountCard: View {
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    private var fingerIcon: String {
        switch count {
        case 2: return "hand.point.up.braille"
        case 3: return "hand.raised"
        case 4: return "hand.raised.fill"
        default: return "hand.raised"
        }
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 56, height: 44)
                        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 4 : 1)
                    
                    // Visual finger dots
                    HStack(spacing: 3) {
                        ForEach(0..<count, id: \.self) { i in
                            Circle()
                                .fill(isSelected ? Color.white : Color.accentColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isHovering ? 1.2 : 1.0)
                                .animation(.spring(response: 0.2).delay(Double(i) * 0.05), value: isHovering)
                        }
                    }
                }
                
                Text("\(count)指")
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering && !isSelected ? Color.secondary.opacity(0.08) : Color.clear)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.spring(response: 0.2)) {
                isHovering = hover
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Helper Views

struct ShortcutRecorderView: View {
    let ruleId: UUID
    @State private var isRecording = false
    @State private var currentShortcut: CustomShortcut?
    @State private var displayString: String = "未设置"

    var body: some View {
        HStack {
            Text("快捷键")
            Spacer()
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack(spacing: 4) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 2)
                    }
                    Text(displayString)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if currentShortcut != nil {
                Button(action: clearShortcut) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            loadShortcut()
        }
    }

    private func loadShortcut() {
        if let shortcut = CustomShortcutManager.shared.getShortcut(for: ruleId) {
            currentShortcut = shortcut
            displayString = shortcut.displayString
        }
    }

    private func startRecording() {
        isRecording = true
        displayString = "输入中..."
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecording {
                // Convert NSEvent modifier flags to Carbon modifier format
                var carbonModifiers: UInt32 = 0
                let flags = event.modifierFlags
                
                if flags.contains(.command) {
                    carbonModifiers |= UInt32(cmdKey)
                }
                if flags.contains(.option) {
                    carbonModifiers |= UInt32(optionKey)
                }
                if flags.contains(.control) {
                    carbonModifiers |= UInt32(controlKey)
                }
                if flags.contains(.shift) {
                    carbonModifiers |= UInt32(shiftKey)
                }
                
                let shortcut = CustomShortcut(
                    keyCode: UInt16(event.keyCode),
                    modifiers: carbonModifiers
                )
                
                DispatchQueue.main.async {
                    self.currentShortcut = shortcut
                    self.displayString = shortcut.displayString
                    CustomShortcutManager.shared.setShortcut(shortcut, for: self.ruleId)
                    self.isRecording = false
                }
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if currentShortcut == nil {
            displayString = "未设置"
        }
    }

    private func clearShortcut() {
        currentShortcut = nil
        displayString = "未设置"
        CustomShortcutManager.shared.removeShortcut(for: ruleId)
    }
}

struct AppSelectionView: View {
    @Binding var selectedApp: RunningApp?
    @State private var apps: [RunningApp] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredApps: [RunningApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified Header (V18)
            SheetHeaderView(
                title: "选择应用",
                subtitle: "选择触发规则的目标应用",
                icon: "square.stack.3d.up.fill",
                color: .secondary, // De-emphasized
                onBack: { dismiss() }
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Custom Search Bar (Matches unified style)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("搜索应用...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            List(filteredApps) { app in
                Button {
                    selectedApp = app
                    dismiss()
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app.fill")
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                        }
                        
                        Text(app.name)
                            .font(.body)
                        
                        Spacer()
                        
                        if selectedApp?.id == app.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            apps = RunningApp.getAllApps()
        }
    }
}
