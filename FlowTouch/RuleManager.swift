import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - Rule Scope (规则作用域)

enum RuleScope: Codable, Equatable, Hashable {
    case global
    case app(bundleId: String, appName: String)

    var displayName: String {
        switch self {
        case .global:
            return L("全局")
        case .app(_, let appName):
            return appName
        }
    }

    var icon: String {
        switch self {
        case .global:
            return "globe"
        case .app:
            return "app.fill"
        }
    }

    var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }
}

// MARK: - Gesture Trigger (手势触发器)

struct GestureTrigger: Codable, Equatable, Hashable {
    enum TriggerType: String, Codable, CaseIterable, Identifiable {
        var id: String { rawValue }

        case swipe = "swipe"
        case tap = "tap"
        case pinch = "pinch"

        var displayName: String {
            switch self {
            case .swipe: return L("滑动")
            case .tap: return L("点击")
            case .pinch: return L("捏合")
            }
        }

        var icon: String {
            switch self {
            case .swipe: return "hand.draw"
            case .tap: return "hand.tap"
            case .pinch: return "hand.pinch"
            }
        }
    }

    let type: TriggerType
    let fingerCount: Int
    let swipeDirection: SwipeDirection?
    let tapType: TapType?
    let pinchDirection: PinchDirection?

    // 便捷构造器
    static func swipe(fingers: Int, direction: SwipeDirection) -> GestureTrigger {
        GestureTrigger(
            type: .swipe,
            fingerCount: fingers,
            swipeDirection: direction,
            tapType: nil,
            pinchDirection: nil
        )
    }

    static func tap(fingers: Int, tapType: TapType) -> GestureTrigger {
        GestureTrigger(
            type: .tap,
            fingerCount: fingers,
            swipeDirection: nil,
            tapType: tapType,
            pinchDirection: nil
        )
    }

    static func pinch(direction: PinchDirection) -> GestureTrigger {
        GestureTrigger(
            type: .pinch,
            fingerCount: 2,
            swipeDirection: nil,
            tapType: nil,
            pinchDirection: direction
        )
    }

    var displayName: String {
        switch type {
        case .swipe:
            guard let dir = swipeDirection else { return "" }
            return String(
                format: L("gesture_swipe_format"),
                fingerCount,
                dir.displayName
            )
        case .tap:
            guard let tap = tapType else { return "" }
            return String(
                format: L("gesture_tap_format"),
                fingerCount,
                tap.displayName
            )
        case .pinch:
            guard let pinch = pinchDirection else { return "" }
            return pinch.displayName
        }
    }

    var shortName: String {
        switch type {
        case .swipe:
            guard let dir = swipeDirection else { return "" }
            return "\(fingerCount)F \(dir.displayName)"
        case .tap:
            guard let tap = tapType else { return "" }
            return "\(fingerCount)F \(tap.shortName)"
        case .pinch:
            guard let pinch = pinchDirection else { return "" }
            return pinch.displayName
        }
    }

    var icon: String {
        switch type {
        case .swipe:
            return swipeDirection?.icon ?? "hand.draw"
        case .tap:
            return "hand.tap"
        case .pinch:
            return pinchDirection?.icon ?? "hand.pinch"
        }
    }
}

// MARK: - Gesture Rule (手势规则)

struct GestureRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String?
    var trigger: GestureTrigger
    var action: WindowAction
    var scope: RuleScope
    var isEnabled: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String? = nil,
        trigger: GestureTrigger,
        action: WindowAction,
        scope: RuleScope = .global,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.action = action
        self.scope = scope
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "\(trigger.displayName) → \(action.displayName)"
    }

    var triggerDescription: String {
        trigger.displayName
    }

    var actionDescription: String {
        action.displayName
    }
}

// MARK: - Rule Manager

class RuleManager: ObservableObject {
    static let shared = RuleManager()

    private let storageKey = "GestureRules_v2"

    // Cache for current app rules to avoid repeated filtering
    private var cachedBundleId: String?
    private var cachedRules: [GestureRule]?
    private var cacheTimestamp: Date?
    private let cacheTimeout: TimeInterval = 0.5  // Cache valid for 500ms

    @Published var rules: [GestureRule] = [] {
        didSet {
            save()
            invalidateCache()  // Invalidate cache when rules change
        }
    }

    private init() {
        load()
        migrateLegacyConfigurationIfNeeded()
        setupAppSwitchObserver()
    }

    /// Invalidate the rule cache
    private func invalidateCache() {
        cachedBundleId = nil
        cachedRules = nil
        cacheTimestamp = nil
    }

    /// Setup observer for app activation changes
    private func setupAppSwitchObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
    }

    // MARK: - CRUD Operations

    func addRule(_ rule: GestureRule) {
        rules.append(normalizeRule(rule))
    }

    func updateRule(_ rule: GestureRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = normalizeRule(rule)
        }
    }

    func deleteRule(_ rule: GestureRule) {
        rules.removeAll { $0.id == rule.id }
    }

    func deleteRule(at indexSet: IndexSet) {
        rules.remove(atOffsets: indexSet)
    }

    func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
    }

    func toggleRule(_ rule: GestureRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
        }
    }

    func duplicateRule(_ rule: GestureRule) {
        var newRule = rule
        newRule = GestureRule(
            name: (rule.name ?? rule.displayName) + L(" (副本)"),
            trigger: rule.trigger,
            action: rule.action,
            scope: rule.scope,
            isEnabled: false,
            createdAt: Date()
        )
        rules.append(newRule)
    }

    // MARK: - Query

    var enabledRules: [GestureRule] {
        rules.filter { $0.isEnabled }
    }

    var disabledRules: [GestureRule] {
        rules.filter { !$0.isEnabled }
    }

    func rules(for scope: RuleScope) -> [GestureRule] {
        rules.filter { $0.scope == scope }
    }

    func rulesForCurrentApp() -> [GestureRule] {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return rules.filter { $0.scope.isGlobal && $0.isEnabled }
        }

        // Check cache validity
        if let cached = cachedRules,
           let cachedId = cachedBundleId,
           let timestamp = cacheTimestamp,
           cachedId == bundleId,
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            return cached
        }

        // Rebuild cache
        let applicableRules = rules.filter { rule in
            guard rule.isEnabled else { return false }

            switch rule.scope {
            case .global:
                return true
            case .app(let ruleBundleId, _):
                return ruleBundleId == bundleId
            }
        }

        // Store in cache
        cachedBundleId = bundleId
        cachedRules = applicableRules
        cacheTimestamp = Date()

        return applicableRules
    }

    /// 查找匹配的规则（用于手势引擎）- 使用缓存优化
    func findMatchingRule(trigger: GestureTrigger) -> GestureRule? {
        let applicableRules = rulesForCurrentApp()

        // 优先匹配应用特定规则
        if let appRule = applicableRules.first(where: {
            !$0.scope.isGlobal && $0.trigger == trigger
        }) {
            return appRule
        }

        // 其次匹配全局规则
        return applicableRules.first(where: {
            $0.scope.isGlobal && $0.trigger == trigger
        })
    }

    /// 检查是否存在冲突（相同触发器）
    func checkConflict(trigger: GestureTrigger, scope: RuleScope, excludingRuleId: UUID? = nil) -> GestureRule? {
        return rules.first { rule in
            guard rule.id != excludingRuleId else { return false }
            guard rule.trigger == trigger else { return false }

            // 检查作用域冲突
            switch (rule.scope, scope) {
            case (.global, .global):
                return true
            case (.app(let id1, _), .app(let id2, _)):
                return id1 == id2
            case (.global, .app), (.app, .global):
                // 全局和应用特定不冲突，应用特定优先级更高
                return false
            }
        }
    }

    // MARK: - Presets

    func applyStarterPreset() {
        rules.removeAll()
        rules = [
            GestureRule(
                trigger: .swipe(fingers: 3, direction: .left),
                action: .snapLeft
            ),
            GestureRule(
                trigger: .swipe(fingers: 3, direction: .right),
                action: .snapRight
            ),
            GestureRule(
                trigger: .swipe(fingers: 3, direction: .up),
                action: .maximize
            )
        ]
    }

    func applyFullPreset() {
        rules.removeAll()
        rules = [
            GestureRule(trigger: .swipe(fingers: 3, direction: .left), action: .snapLeft),
            GestureRule(trigger: .swipe(fingers: 3, direction: .right), action: .snapRight),
            GestureRule(trigger: .swipe(fingers: 3, direction: .up), action: .maximize),
            GestureRule(trigger: .swipe(fingers: 3, direction: .down), action: .restore),
            GestureRule(trigger: .swipe(fingers: 3, direction: .topLeft), action: .snapTopLeft),
            GestureRule(trigger: .swipe(fingers: 3, direction: .topRight), action: .snapTopRight),
            GestureRule(trigger: .swipe(fingers: 3, direction: .bottomLeft), action: .snapBottomLeft),
            GestureRule(trigger: .swipe(fingers: 3, direction: .bottomRight), action: .snapBottomRight)
        ]
    }

    func clearAllRules() {
        rules.removeAll()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let savedRules = try? JSONDecoder().decode([GestureRule].self, from: data) else {
            return
        }
        rules = savedRules.map(normalizeRule)
    }

    // MARK: - Export/Import

    func exportRules() -> Data? {
        try? JSONEncoder().encode(rules)
    }

    func importRules(from data: Data, replace: Bool = false) -> Bool {
        guard let importedRules = try? JSONDecoder().decode([GestureRule].self, from: data) else {
            return false
        }

        let normalizedRules = importedRules.map(normalizeRule)

        if replace {
            rules = normalizedRules
        } else {
            rules.append(contentsOf: normalizedRules)
        }
        return true
    }

    private func normalizeRule(_ rule: GestureRule) -> GestureRule {
        var normalizedRule = rule

        switch normalizedRule.action {
        case .moveToNextSpace:
            normalizedRule.action = .spaceRight
        case .moveToPrevSpace:
            normalizedRule.action = .spaceLeft
        default:
            break
        }

        return normalizedRule
    }

    private func migrateLegacyConfigurationIfNeeded() {
        let configManager = ConfigurationManager.shared
        let legacyRules = buildLegacyRules(from: configManager.config)
        guard !legacyRules.isEmpty else { return }

        let migratedRules = legacyRules
            .map(normalizeRule)
            .filter { checkConflict(trigger: $0.trigger, scope: $0.scope) == nil }

        if !migratedRules.isEmpty {
            rules.append(contentsOf: migratedRules)
        }

        configManager.clearLegacyGestureMappings()

        #if DEBUG
        print("[RuleManager] Migrated \(migratedRules.count) legacy gesture rule(s) and cleared legacy configuration")
        #endif
    }

    private func buildLegacyRules(from config: GestureConfiguration) -> [GestureRule] {
        var legacyRules: [GestureRule] = []

        for fingerCount in [2, 3, 4] {
            appendLegacySwipeRules(
                from: config.swipeMapping(for: fingerCount),
                fingerCount: fingerCount,
                to: &legacyRules
            )
            appendLegacyTapRules(
                from: config.tapMapping(for: fingerCount),
                fingerCount: fingerCount,
                to: &legacyRules
            )
        }

        if config.pinchEnabled {
            appendLegacyPinchRules(from: config.pinchGestures, to: &legacyRules)
        }

        return legacyRules
    }

    private func appendLegacySwipeRules(
        from mapping: SwipeMapping,
        fingerCount: Int,
        to rules: inout [GestureRule]
    ) {
        for direction in SwipeDirection.allCases {
            let action = mapping.action(for: direction)
            guard action != .none else { continue }

            rules.append(
                GestureRule(
                    trigger: .swipe(fingers: fingerCount, direction: direction),
                    action: action
                )
            )
        }
    }

    private func appendLegacyTapRules(
        from mapping: TapMapping,
        fingerCount: Int,
        to rules: inout [GestureRule]
    ) {
        for tapType in TapType.allCases {
            let action = mapping.action(for: tapType)
            guard action != .none else { continue }

            rules.append(
                GestureRule(
                    trigger: .tap(fingers: fingerCount, tapType: tapType),
                    action: action
                )
            )
        }
    }

    private func appendLegacyPinchRules(
        from mapping: PinchMapping,
        to rules: inout [GestureRule]
    ) {
        for direction in PinchDirection.allCases {
            let action = mapping.action(for: direction)
            guard action != .none else { continue }

            rules.append(
                GestureRule(
                    trigger: .pinch(direction: direction),
                    action: action
                )
            )
        }
    }
}

// MARK: - Running Apps Helper

struct RunningApp: Identifiable, Hashable {
    let id: String // bundleIdentifier
    let name: String
    let icon: NSImage?

    static func getRunningApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else {
                    return nil
                }
                return RunningApp(id: bundleId, name: name, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }

    static func getInstalledApps() -> [RunningApp] {
        let fileManager = FileManager.default
        let appDirs = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        var apps: [RunningApp] = []

        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }

            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(dir)/\(item)"
                if let bundle = Bundle(path: appPath),
                   let bundleId = bundle.bundleIdentifier {
                    let name = (item as NSString).deletingPathExtension
                    let icon = NSWorkspace.shared.icon(forFile: appPath)
                    apps.append(RunningApp(id: bundleId, name: name, icon: icon))
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    static func getAllApps() -> [RunningApp] {
        let runningApps = getRunningApps()
        let installedApps = getInstalledApps()
        
        var seen = Set<String>()
        var combined: [RunningApp] = []
        
        for app in runningApps {
            if !seen.contains(app.id) {
                seen.insert(app.id)
                combined.append(app)
            }
        }
        
        for app in installedApps {
            if !seen.contains(app.id) {
                seen.insert(app.id)
                combined.append(app)
            }
        }
        
        return combined.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
