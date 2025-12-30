import Foundation
import Combine

// MARK: - Window Action Types

/// All possible actions that can be triggered by gestures
enum WindowAction: String, Codable, CaseIterable, Identifiable {
    // ============================================
    // MARK: Window Layout - Half Screen
    // ============================================
    case snapLeft = "snap_left"
    case snapRight = "snap_right"
    case snapTop = "snap_top"
    case snapBottom = "snap_bottom"

    // ============================================
    // MARK: Window Layout - Quarter Screen
    // ============================================
    case snapTopLeft = "snap_top_left"
    case snapTopRight = "snap_top_right"
    case snapBottomLeft = "snap_bottom_left"
    case snapBottomRight = "snap_bottom_right"

    // ============================================
    // MARK: Window Control
    // ============================================
    case maximize = "maximize"
    case center = "center"
    case restore = "restore"
    case minimize = "minimize"
    case close = "close"
    case fullscreen = "fullscreen"
    case undo = "undo"  // Undo last window operation

    // Extended window control
    case maximizeHeight = "maximize_height"
    case maximizeWidth = "maximize_width"
    case minimizeAll = "minimize_all"
    case restoreAllMinimized = "restore_all_minimized"

    // ============================================
    // MARK: Multi-Monitor & Spaces
    // ============================================
    case moveToNextScreen = "move_next_screen"
    case moveToPrevScreen = "move_prev_screen"
    case moveToNextSpace = "move_next_space"
    case moveToPrevSpace = "move_prev_space"
    case spaceLeft = "space_left"
    case spaceRight = "space_right"

    // ============================================
    // MARK: Desktop & System
    // ============================================
    case missionControl = "mission_control"
    case showDesktop = "show_desktop"
    case appExpose = "app_expose"
    case launchpad = "launchpad"
    case spotlight = "spotlight"
    case lockScreen = "lock_screen"
    case startScreensaver = "start_screensaver"

    // ============================================
    // MARK: Application Control
    // ============================================
    case quitApp = "quit_app"
    case hideApp = "hide_app"
    case hideOthers = "hide_others"
    case switchApp = "switch_app"
    case previousApp = "previous_app"

    // ============================================
    // MARK: Custom
    // ============================================
    case customShortcut = "custom_shortcut"

    // ============================================
    // MARK: None
    // ============================================
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        // Layout - Half
        case .snapLeft: return "左半屏"
        case .snapRight: return "右半屏"
        case .snapTop: return "上半屏"
        case .snapBottom: return "下半屏"
        // Layout - Quarter
        case .snapTopLeft: return "左上角"
        case .snapTopRight: return "右上角"
        case .snapBottomLeft: return "左下角"
        case .snapBottomRight: return "右下角"
        // Window Control
        case .maximize: return "最大化"
        case .center: return "居中"
        case .restore: return "还原"
        case .minimize: return "最小化"
        case .close: return "关闭"
        case .fullscreen: return "全屏"
        case .undo: return "撤销"
        case .maximizeHeight: return "垂直最大化"
        case .maximizeWidth: return "水平最大化"
        case .minimizeAll: return "全部最小化"
        case .restoreAllMinimized: return "恢复全部"
        // Multi-Monitor & Spaces
        case .moveToNextScreen: return "移至下个屏幕"
        case .moveToPrevScreen: return "移至上个屏幕"
        case .moveToNextSpace: return "移至下个空间"
        case .moveToPrevSpace: return "移至上个空间"
        case .spaceLeft: return "切换左空间"
        case .spaceRight: return "切换右空间"
        // Desktop & System
        case .missionControl: return "调度中心"
        case .showDesktop: return "显示桌面"
        case .appExpose: return "应用窗口"
        case .launchpad: return "启动台"
        case .spotlight: return "聚焦搜索"
        case .lockScreen: return "锁定屏幕"
        case .startScreensaver: return "屏幕保护"
        // Application
        case .quitApp: return "退出应用"
        case .hideApp: return "隐藏应用"
        case .hideOthers: return "隐藏其他"
        case .switchApp: return "切换应用"
        case .previousApp: return "上个应用"
        // Custom
        case .customShortcut: return "自定义快捷键"
        // None
        case .none: return "未设置"
        }
    }

    var shortName: String {
        switch self {
        // Layout
        case .snapLeft: return "左"
        case .snapRight: return "右"
        case .snapTop: return "上"
        case .snapBottom: return "下"
        case .snapTopLeft: return "左上"
        case .snapTopRight: return "右上"
        case .snapBottomLeft: return "左下"
        case .snapBottomRight: return "右下"
        // Window
        case .maximize: return "最大化"
        case .center: return "居中"
        case .restore: return "还原"
        case .minimize: return "最小化"
        case .close: return "关闭"
        case .fullscreen: return "全屏"
        case .undo: return "撤销"
        case .maximizeHeight: return "↕最大"
        case .maximizeWidth: return "↔最大"
        case .minimizeAll: return "全最小"
        case .restoreAllMinimized: return "恢复全部"
        // Multi-Monitor
        case .moveToNextScreen: return "→屏幕"
        case .moveToPrevScreen: return "←屏幕"
        case .moveToNextSpace: return "→空间"
        case .moveToPrevSpace: return "←空间"
        case .spaceLeft: return "空间←"
        case .spaceRight: return "空间→"
        // Desktop
        case .missionControl: return "调度"
        case .showDesktop: return "桌面"
        case .appExpose: return "窗口"
        case .launchpad: return "启动台"
        case .spotlight: return "搜索"
        case .lockScreen: return "锁屏"
        case .startScreensaver: return "屏保"
        // Application
        case .quitApp: return "退出"
        case .hideApp: return "隐藏"
        case .hideOthers: return "隐藏其他"
        case .switchApp: return "切换"
        case .previousApp: return "上个"
        // Custom
        case .customShortcut: return "快捷键"
        // None
        case .none: return "添加"
        }
    }

    var icon: String {
        switch self {
        // Layout - Half
        case .snapLeft: return "arrow.left.to.line"
        case .snapRight: return "arrow.right.to.line"
        case .snapTop: return "arrow.up.to.line"
        case .snapBottom: return "arrow.down.to.line"
        // Layout - Quarter
        case .snapTopLeft: return "arrow.up.left"
        case .snapTopRight: return "arrow.up.right"
        case .snapBottomLeft: return "arrow.down.left"
        case .snapBottomRight: return "arrow.down.right"
        // Window Control
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .center: return "viewfinder"
        case .restore: return "arrow.down.right.and.arrow.up.left"
        case .minimize: return "minus"
        case .close: return "xmark"
        case .fullscreen: return "arrow.up.forward.and.arrow.down.backward"
        case .undo: return "arrow.uturn.backward"
        case .maximizeHeight: return "arrow.up.and.down"
        case .maximizeWidth: return "arrow.left.and.right"
        case .minimizeAll: return "menubar.dock.rectangle"
        case .restoreAllMinimized: return "menubar.dock.rectangle.badge.record"
        // Multi-Monitor & Spaces
        case .moveToNextScreen: return "rectangle.righthalf.inset.filled.arrow.right"
        case .moveToPrevScreen: return "rectangle.lefthalf.inset.filled.arrow.left"
        case .moveToNextSpace: return "chevron.right.2"
        case .moveToPrevSpace: return "chevron.left.2"
        case .spaceLeft: return "chevron.compact.left"
        case .spaceRight: return "chevron.compact.right"
        // Desktop & System
        case .missionControl: return "rectangle.3.group"
        case .showDesktop: return "menubar.dock.rectangle"
        case .appExpose: return "rectangle.stack"
        case .launchpad: return "square.grid.3x3"
        case .spotlight: return "magnifyingglass"
        case .lockScreen: return "lock"
        case .startScreensaver: return "sparkles.tv"
        // Application
        case .quitApp: return "power"
        case .hideApp: return "eye.slash"
        case .hideOthers: return "eye.trianglebadge.exclamationmark"
        case .switchApp: return "arrow.left.arrow.right"
        case .previousApp: return "arrow.uturn.left"
        // Custom
        case .customShortcut: return "command"
        // None
        case .none: return "plus"
        }
    }

    var snapDirection: SnapDirection? {
        switch self {
        case .snapLeft: return .left
        case .snapRight: return .right
        case .snapTop: return .top
        case .snapBottom: return .bottom
        case .snapTopLeft: return .topLeft
        case .snapTopRight: return .topRight
        case .snapBottomLeft: return .bottomLeft
        case .snapBottomRight: return .bottomRight
        case .maximize: return .maximize
        case .center: return .center
        case .restore: return .restore
        default: return nil
        }
    }

    /// Whether this action requires additional configuration (e.g., custom shortcut)
    var requiresConfiguration: Bool {
        switch self {
        case .customShortcut:
            return true
        default:
            return false
        }
    }

    /// Group for UI organization
    var category: ActionCategory {
        switch self {
        case .snapLeft, .snapRight, .snapTop, .snapBottom,
             .snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight:
            return .layout
        case .maximize, .center, .restore, .minimize, .close, .fullscreen, .undo,
             .maximizeHeight, .maximizeWidth, .minimizeAll, .restoreAllMinimized:
            return .window
        case .moveToNextScreen, .moveToPrevScreen, .moveToNextSpace, .moveToPrevSpace,
             .spaceLeft, .spaceRight:
            return .multiMonitor
        case .missionControl, .showDesktop, .appExpose, .launchpad, .spotlight,
             .lockScreen, .startScreensaver:
            return .desktop
        case .quitApp, .hideApp, .hideOthers, .switchApp, .previousApp:
            return .apps
        case .customShortcut:
            return .custom
        case .none:
            return .other
        }
    }

    enum ActionCategory: String, CaseIterable {
        case layout = "窗口布局"
        case window = "窗口控制"
        case multiMonitor = "屏幕与空间"
        case desktop = "桌面与系统"
        case apps = "应用程序"
        case custom = "自定义"
        case other = "其他"

        var icon: String {
            switch self {
            case .layout: return "rectangle.split.2x2"
            case .window: return "macwindow"
            case .multiMonitor: return "display.2"
            case .desktop: return "desktopcomputer"
            case .apps: return "app.badge"
            case .custom: return "keyboard"
            case .other: return "ellipsis.circle"
            }
        }

        var color: String {
            switch self {
            case .layout: return "blue"
            case .window: return "purple"
            case .multiMonitor: return "orange"
            case .desktop: return "green"
            case .apps: return "red"
            case .custom: return "indigo"
            case .other: return "gray"
            }
        }

        /// Order for display in UI
        var displayOrder: Int {
            switch self {
            case .layout: return 0
            case .window: return 1
            case .multiMonitor: return 2
            case .desktop: return 3
            case .apps: return 4
            case .custom: return 5
            case .other: return 6
            }
        }

        /// Actions in this category (excluding none)
        var actions: [WindowAction] {
            WindowAction.allCases.filter { $0.category == self && $0 != .none }
        }
    }
}

// MARK: - Gesture Type

enum GestureType: String, CaseIterable, Identifiable {
    case swipe = "滑动"
    case tap = "点击"
    case pinch = "捏合"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .swipe: return "hand.draw"
        case .tap: return "hand.tap"
        case .pinch: return "hand.pinch"
        }
    }

    var description: String {
        switch self {
        case .swipe: return "在触控板上滑动手指"
        case .tap: return "快速点击手指"
        case .pinch: return "捏合或张开手指"
        }
    }
}

// MARK: - Tap Type

enum TapType: String, Codable, CaseIterable, Identifiable {
    case singleTap = "single_tap"
    case doubleTap = "double_tap"
    case tripleTap = "triple_tap"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .singleTap: return "单击"
        case .doubleTap: return "双击"
        case .tripleTap: return "三击"
        }
    }

    var shortName: String {
        switch self {
        case .singleTap: return "1次点击"
        case .doubleTap: return "2次点击"
        case .tripleTap: return "3次点击"
        }
    }

    var icon: String {
        switch self {
        case .singleTap: return "hand.tap"
        case .doubleTap: return "hand.tap"
        case .tripleTap: return "hand.tap"
        }
    }

    var tapCount: Int {
        switch self {
        case .singleTap: return 1
        case .doubleTap: return 2
        case .tripleTap: return 3
        }
    }
}

// MARK: - Swipe Direction

enum SwipeDirection: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    case up
    case down
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "左"
        case .right: return "右"
        case .up: return "上"
        case .down: return "下"
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        }
    }

    var icon: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .topLeft: return "arrow.up.left"
        case .topRight: return "arrow.up.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottomRight: return "arrow.down.right"
        }
    }

    /// Grid position (row, col) for 3x3 grid display
    var gridPosition: (row: Int, col: Int) {
        switch self {
        case .topLeft: return (0, 0)
        case .up: return (0, 1)
        case .topRight: return (0, 2)
        case .left: return (1, 0)
        case .right: return (1, 2)
        case .bottomLeft: return (2, 0)
        case .down: return (2, 1)
        case .bottomRight: return (2, 2)
        }
    }

    /// Is this a cardinal direction (main axis)
    var isCardinal: Bool {
        switch self {
        case .left, .right, .up, .down: return true
        default: return false
        }
    }
}

// MARK: - Pinch Direction

enum PinchDirection: String, Codable, CaseIterable, Identifiable {
    case pinchIn = "pinch_in"
    case pinchOut = "pinch_out"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pinchIn: return "捏合"
        case .pinchOut: return "张开"
        }
    }

    var icon: String {
        switch self {
        case .pinchIn: return "arrow.down.forward.and.arrow.up.backward"
        case .pinchOut: return "arrow.up.backward.and.arrow.down.forward"
        }
    }
}

// MARK: - Gesture Mappings

/// Empty swipe mapping - user must configure
struct SwipeMapping: Codable, Equatable {
    var left: WindowAction = .none
    var right: WindowAction = .none
    var up: WindowAction = .none
    var down: WindowAction = .none
    var topLeft: WindowAction = .none
    var topRight: WindowAction = .none
    var bottomLeft: WindowAction = .none
    var bottomRight: WindowAction = .none

    func action(for direction: SwipeDirection) -> WindowAction {
        switch direction {
        case .left: return left
        case .right: return right
        case .up: return up
        case .down: return down
        case .topLeft: return topLeft
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        }
    }

    mutating func setAction(_ action: WindowAction, for direction: SwipeDirection) {
        switch direction {
        case .left: left = action
        case .right: right = action
        case .up: up = action
        case .down: down = action
        case .topLeft: topLeft = action
        case .topRight: topRight = action
        case .bottomLeft: bottomLeft = action
        case .bottomRight: bottomRight = action
        }
    }

    /// Count of configured (non-none) actions
    var configuredCount: Int {
        [left, right, up, down, topLeft, topRight, bottomLeft, bottomRight]
            .filter { $0 != .none }.count
    }

    /// Minimal starter preset - just left/right split
    static var minimalPreset: SwipeMapping {
        SwipeMapping(
            left: .snapLeft,
            right: .snapRight,
            up: .maximize,
            down: .none,
            topLeft: .none,
            topRight: .none,
            bottomLeft: .none,
            bottomRight: .none
        )
    }
}

struct TapMapping: Codable, Equatable {
    var singleTap: WindowAction = .none
    var doubleTap: WindowAction = .none
    var tripleTap: WindowAction = .none

    func action(for tapType: TapType) -> WindowAction {
        switch tapType {
        case .singleTap: return singleTap
        case .doubleTap: return doubleTap
        case .tripleTap: return tripleTap
        }
    }

    mutating func setAction(_ action: WindowAction, for tapType: TapType) {
        switch tapType {
        case .singleTap: singleTap = action
        case .doubleTap: doubleTap = action
        case .tripleTap: tripleTap = action
        }
    }

    /// Count of configured (non-none) actions
    var configuredCount: Int {
        [singleTap, doubleTap, tripleTap].filter { $0 != .none }.count
    }
}

struct PinchMapping: Codable, Equatable {
    var pinchIn: WindowAction = .none
    var pinchOut: WindowAction = .none

    func action(for direction: PinchDirection) -> WindowAction {
        switch direction {
        case .pinchIn: return pinchIn
        case .pinchOut: return pinchOut
        }
    }

    mutating func setAction(_ action: WindowAction, for direction: PinchDirection) {
        switch direction {
        case .pinchIn: pinchIn = action
        case .pinchOut: pinchOut = action
        }
    }

    /// Count of configured (non-none) actions
    var configuredCount: Int {
        [pinchIn, pinchOut].filter { $0 != .none }.count
    }
}

// MARK: - Gesture Configuration

struct GestureConfiguration: Codable, Equatable {
    // Enabled finger counts - default to 3 fingers (avoids system 2-finger scroll conflict)
    var enabledFingerCounts: Set<Int> = [3]

    // Per-finger-count swipe mappings - all empty by default
    var twoFingerSwipe: SwipeMapping = SwipeMapping()
    var threeFingerSwipe: SwipeMapping = SwipeMapping()
    var fourFingerSwipe: SwipeMapping = SwipeMapping()

    // Per-finger-count tap mappings - all empty by default
    var twoFingerTap: TapMapping = TapMapping()
    var threeFingerTap: TapMapping = TapMapping()
    var fourFingerTap: TapMapping = TapMapping()

    // Pinch gestures - disabled by default (conflicts with system zoom)
    var pinchGestures: PinchMapping = PinchMapping()
    var pinchEnabled: Bool = false

    // Tap gestures - disabled by default (let user opt-in)
    var tapEnabled: Bool = false

    // Sensitivity settings
    var swipeThreshold: Double = 0.12
    var pinchInThreshold: Double = 0.70   // Symmetric: requires 30% reduction (was 0.60 = 40%)
    var pinchOutThreshold: Double = 1.40  // Symmetric: requires 40% expansion (was 1.50 = 50%)
    var tapTimeout: Double = 0.3

    // Get swipe mapping for finger count
    func swipeMapping(for fingerCount: Int) -> SwipeMapping {
        switch fingerCount {
        case 2: return twoFingerSwipe
        case 3: return threeFingerSwipe
        case 4: return fourFingerSwipe
        default: return twoFingerSwipe
        }
    }

    mutating func setSwipeMapping(_ mapping: SwipeMapping, for fingerCount: Int) {
        switch fingerCount {
        case 2: twoFingerSwipe = mapping
        case 3: threeFingerSwipe = mapping
        case 4: fourFingerSwipe = mapping
        default: break
        }
    }

    // Get tap mapping for finger count
    func tapMapping(for fingerCount: Int) -> TapMapping {
        switch fingerCount {
        case 2: return twoFingerTap
        case 3: return threeFingerTap
        case 4: return fourFingerTap
        default: return twoFingerTap
        }
    }

    mutating func setTapMapping(_ mapping: TapMapping, for fingerCount: Int) {
        switch fingerCount {
        case 2: twoFingerTap = mapping
        case 3: threeFingerTap = mapping
        case 4: fourFingerTap = mapping
        default: break
        }
    }

    // Count configured gestures for a type
    func configuredCount(for gestureType: GestureType, fingerCount: Int) -> Int {
        switch gestureType {
        case .swipe:
            return swipeMapping(for: fingerCount).configuredCount
        case .tap:
            return tapMapping(for: fingerCount).configuredCount
        case .pinch:
            return pinchGestures.configuredCount
        }
    }

    // Default configuration - minimal, clean slate
    static let `default` = GestureConfiguration()

    // Starter preset - basic window snapping for new users
    static var starterPreset: GestureConfiguration {
        var config = GestureConfiguration()
        config.enabledFingerCounts = [3]
        // Only configure the 3 most useful actions
        config.threeFingerSwipe = SwipeMapping(
            left: .snapLeft,
            right: .snapRight,
            up: .maximize,
            down: .none,
            topLeft: .none,
            topRight: .none,
            bottomLeft: .none,
            bottomRight: .none
        )
        config.pinchEnabled = false
        config.tapEnabled = false
        return config
    }

    // Full preset - all directions configured (for power users)
    static var fullPreset: GestureConfiguration {
        var config = GestureConfiguration()
        config.enabledFingerCounts = [3]
        config.threeFingerSwipe = SwipeMapping(
            left: .snapLeft,
            right: .snapRight,
            up: .maximize,
            down: .restore,
            topLeft: .snapTopLeft,
            topRight: .snapTopRight,
            bottomLeft: .snapBottomLeft,
            bottomRight: .snapBottomRight
        )
        config.pinchEnabled = false
        config.tapEnabled = false
        return config
    }
}

// MARK: - Configuration Manager

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    private let configKey = "GestureConfiguration"

    @Published var config: GestureConfiguration {
        didSet {
            save()
        }
    }

    private init() {
        self.config = Self.load() ?? .default
    }

    private static func load() -> GestureConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "GestureConfiguration") else {
            return nil
        }
        return try? JSONDecoder().decode(GestureConfiguration.self, from: data)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    func resetToDefault() {
        config = .default
    }

    func applyStarterPreset() {
        config = .starterPreset
    }

    func applyFullPreset() {
        config = .fullPreset
    }

    /// Check if this is a fresh install (no gestures configured)
    var isEmptyConfiguration: Bool {
        let totalConfigured = config.twoFingerSwipe.configuredCount +
                              config.threeFingerSwipe.configuredCount +
                              config.fourFingerSwipe.configuredCount +
                              config.twoFingerTap.configuredCount +
                              config.threeFingerTap.configuredCount +
                              config.fourFingerTap.configuredCount +
                              config.pinchGestures.configuredCount
        return totalConfigured == 0
    }

    func exportConfiguration() -> Data? {
        return try? JSONEncoder().encode(config)
    }

    func importConfiguration(from data: Data) -> Bool {
        guard let newConfig = try? JSONDecoder().decode(GestureConfiguration.self, from: data) else {
            return false
        }
        config = newConfig
        return true
    }

    // Convenience accessors
    var enabledFingerCounts: Set<Int> {
        get { config.enabledFingerCounts }
        set { config.enabledFingerCounts = newValue }
    }

    func isFingerCountEnabled(_ count: Int) -> Bool {
        config.enabledFingerCounts.contains(count)
    }

    func toggleFingerCount(_ count: Int) {
        if config.enabledFingerCounts.contains(count) {
            config.enabledFingerCounts.remove(count)
        } else {
            config.enabledFingerCounts.insert(count)
        }
    }
}
