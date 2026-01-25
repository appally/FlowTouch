//
//  ContentView.swift
//  FlowTouch
//
//  Created by Appally on 2025/12/27.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design System

struct DesignSystem {
    // Colors
    static let accentBlue = Color.blue
    static let accentPurple = Color.purple
    static let accentOrange = Color.orange
    static let accentGreen = Color.green

    static let cardBackground = Color.gray.opacity(0.06)
    static let cardBorder = Color.gray.opacity(0.12)
    static let configuredBorder = Color.blue.opacity(0.4)
    static let unconfiguredBorder = Color.gray.opacity(0.2)

    // Spacing
    static let spacing: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let cornerRadius: CGFloat = 12
}

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var manager = MultitouchManager.shared
    @ObservedObject var localization = LocalizationManager.shared

    var body: some View {
        Group {
            switch manager.status {
            case .active:
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

// MARK: - Main View
struct MainView: View {
    var body: some View {
        FlowDashboard()
    }
}

// MARK: - Welcome Setup View

enum SetupPreset {
    case starter
    case full
    case skip
}

struct WelcomeSetupView: View {
    let onSetup: (SetupPreset) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "hand.draw")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            // Title
            VStack(spacing: 8) {
                Text("Welcome to FlowTouch")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Control windows with trackpad gestures")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Presets
            VStack(spacing: 12) {
                Text("Choose a starting configuration:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Starter preset
                Button(action: { onSetup(.starter) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Start")
                                .font(.system(size: 14, weight: .semibold))

                            Text("3 gestures: Left, Right, Maximize")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Full preset
                Button(action: { onSetup(.full) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full Setup")
                                .font(.system(size: 14, weight: .medium))

                            Text("8 directions: All window positions")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Skip
            Button(action: onSkip) {
                Text("Start from scratch")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Note
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Uses 3-finger gestures to avoid conflicts with system scrolling")
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, DesignSystem.spacing)
    }
}

// MARK: - Main Header


// MARK: - Gesture Type Tabs

struct GestureTypeTabs: View {
    @Binding var selectedType: GestureType
    let config: GestureConfiguration
    let fingerCount: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GestureType.allCases) { type in
                GestureTypeTab(
                    type: type,
                    isSelected: selectedType == type,
                    configuredCount: config.configuredCount(for: type, fingerCount: fingerCount),
                    onTap: { selectedType = type }
                )
            }
        }
    }
}

struct GestureTypeTab: View {
    let type: GestureType
    let isSelected: Bool
    let configuredCount: Int
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))

                Text(type.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))

                // Badge showing configured count
                if configuredCount > 0 {
                    Text("\(configuredCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? .white : .blue)
                        .frame(width: 18, height: 18)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.blue.opacity(0.15))
                        .cornerRadius(9)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : (isHovered ? Color.gray.opacity(0.08) : Color.gray.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Finger Count Selector

struct FingerCountSelector: View {
    @Binding var selectedCount: Int
    @Binding var enabledCounts: Set<Int>

    var body: some View {
        HStack(spacing: 12) {
            Text("Fingers")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach([2, 3, 4], id: \.self) { count in
                    FingerButton(
                        count: count,
                        isSelected: selectedCount == count,
                        isEnabled: enabledCounts.contains(count),
                        onTap: {
                            selectedCount = count
                            if !enabledCounts.contains(count) {
                                enabledCounts.insert(count)
                            }
                        },
                        onToggle: {
                            if enabledCounts.contains(count) {
                                enabledCounts.remove(count)
                            } else {
                                enabledCounts.insert(count)
                            }
                        }
                    )
                }
            }

            Spacer()
        }
    }
}

struct FingerButton: View {
    let count: Int
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // Finger dots
                HStack(spacing: 2) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(isEnabled ? (isSelected ? Color.white : Color.blue) : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }

                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isEnabled ? (isSelected ? .white : .primary) : .gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.blue : (isEnabled ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2)),
                        lineWidth: 1
                    )
                    .opacity(isEnabled ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(String(format: L(isEnabled ? "disable_fingers_format" : "enable_fingers_format"), count)) {
                onToggle()
            }
        }
    }
}

// MARK: - Gesture Content View

struct GestureContentView: View {
    let gestureType: GestureType
    let fingerCount: Int
    @Binding var config: GestureConfiguration

    var body: some View {
        VStack(spacing: 16) {
            switch gestureType {
            case .swipe:
                SwipeConfigView(fingerCount: fingerCount, config: $config)
            case .tap:
                TapConfigView(fingerCount: fingerCount, config: $config)
            case .pinch:
                PinchConfigView(config: $config)
            }
        }
    }
}

// MARK: - Swipe Config View

struct SwipeConfigView: View {
    let fingerCount: Int
    @Binding var config: GestureConfiguration
    @State private var selectedDirection: SwipeDirection?
    @State private var showActionPicker = false

    private var mapping: SwipeMapping {
        config.swipeMapping(for: fingerCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Label("Swipe Directions", systemImage: "hand.draw")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(mapping.configuredCount)/8 configured")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // 3x3 Grid
            SwipeGridView(
                mapping: mapping,
                fingerCount: fingerCount,
                onSelectDirection: { direction in
                    selectedDirection = direction
                    showActionPicker = true
                }
            )
        }
        .sheet(isPresented: $showActionPicker) {
            if let direction = selectedDirection {
                ActionPickerSheet(
                    title: "Swipe \(direction.displayName)",
                    currentAction: mapping.action(for: direction),
                    onSelect: { action in
                        var newMapping = mapping
                        newMapping.setAction(action, for: direction)
                        config.setSwipeMapping(newMapping, for: fingerCount)
                        showActionPicker = false
                    },
                    onCancel: { showActionPicker = false }
                )
            }
        }
    }
}

struct SwipeGridView: View {
    let mapping: SwipeMapping
    let fingerCount: Int
    let onSelectDirection: (SwipeDirection) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Top row
            HStack(spacing: 6) {
                SwipeCell(direction: .topLeft, action: mapping.topLeft, onTap: { onSelectDirection(.topLeft) })
                SwipeCell(direction: .up, action: mapping.up, onTap: { onSelectDirection(.up) }, isCardinal: true)
                SwipeCell(direction: .topRight, action: mapping.topRight, onTap: { onSelectDirection(.topRight) })
            }

            // Middle row
            HStack(spacing: 6) {
                SwipeCell(direction: .left, action: mapping.left, onTap: { onSelectDirection(.left) }, isCardinal: true)
                CenterIndicator(fingerCount: fingerCount)
                SwipeCell(direction: .right, action: mapping.right, onTap: { onSelectDirection(.right) }, isCardinal: true)
            }

            // Bottom row
            HStack(spacing: 6) {
                SwipeCell(direction: .bottomLeft, action: mapping.bottomLeft, onTap: { onSelectDirection(.bottomLeft) })
                SwipeCell(direction: .down, action: mapping.down, onTap: { onSelectDirection(.down) }, isCardinal: true)
                SwipeCell(direction: .bottomRight, action: mapping.bottomRight, onTap: { onSelectDirection(.bottomRight) })
            }
        }
        .padding(DesignSystem.cardPadding)
        .background(DesignSystem.cardBackground)
        .cornerRadius(DesignSystem.cornerRadius)
    }
}

struct SwipeCell: View {
    let direction: SwipeDirection
    let action: WindowAction
    let onTap: () -> Void
    var isCardinal: Bool = false

    @State private var isHovered = false
    @State private var isPressed = false

    private var isConfigured: Bool { action != .none }

    private var accentColor: Color {
        switch action.category {
        case .layout: return .blue
        case .window: return .purple
        case .multiMonitor: return .orange
        case .desktop: return .green
        case .apps: return .red
        case .tabs: return .cyan
        case .media: return .pink
        case .screenshot: return .yellow
        case .custom: return .indigo
        case .other: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Direction icon
                Image(systemName: direction.icon)
                    .font(.system(size: isCardinal ? 18 : 14, weight: isCardinal ? .medium : .regular))
                    .foregroundColor(isConfigured ? accentColor : .gray.opacity(0.4))

                // Action name
                Text(action.shortName)
                    .font(.system(size: 10, weight: isConfigured ? .medium : .regular))
                    .foregroundColor(isConfigured ? .primary : .gray.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(width: 90, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? accentColor.opacity(0.15) : (isHovered ? accentColor.opacity(0.08) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isConfigured ? accentColor.opacity(isCardinal ? 0.4 : 0.25) : Color.gray.opacity(0.15),
                        style: isConfigured ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            if isConfigured {
                Button {
                    testAction()
                } label: {
                    Label(String(format: L("Test: %@"), action.displayName), systemImage: "play.fill")
                }
                Divider()
            }
            Button {
                onTap()
            } label: {
                Label(isConfigured ? L("Change Action") : L("Set Action"), systemImage: "pencil")
            }
        }
        .help(isConfigured ? L("Click to change • Right-click to test") : L("Click to set action"))
    }

    private func testAction() {
        if let snapDir = action.snapDirection {
            WindowManager.shared.snapFocusedWindow(direction: snapDir)
        } else if action == .minimize {
            WindowManager.shared.minimizeFocusedWindow()
        } else if action == .close {
            WindowManager.shared.closeFocusedWindow()
        } else if action == .fullscreen {
            WindowManager.shared.toggleFullscreen()
        }
    }
}

struct CenterIndicator: View {
    let fingerCount: Int
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<fingerCount, id: \.self) { i in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                            value: pulse
                        )
                }
            }

            Text("\(fingerCount)F Swipe")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.blue)
        }
        .frame(width: 90, height: 60)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .onAppear { pulse = true }
    }
}

// MARK: - Tap Config View

struct TapConfigView: View {
    let fingerCount: Int
    @Binding var config: GestureConfiguration
    @State private var selectedTapType: TapType?
    @State private var showActionPicker = false

    private var mapping: TapMapping {
        config.tapMapping(for: fingerCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Label("Tap Actions", systemImage: "hand.tap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(mapping.configuredCount)/3 configured")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Tap cards
            VStack(spacing: 8) {
                ForEach(TapType.allCases) { tapType in
                    TapActionCard(
                        tapType: tapType,
                        action: mapping.action(for: tapType),
                        fingerCount: fingerCount,
                        onTap: {
                            selectedTapType = tapType
                            showActionPicker = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showActionPicker) {
            if let tapType = selectedTapType {
                ActionPickerSheet(
                    title: "\(fingerCount)-Finger \(tapType.displayName)",
                    currentAction: mapping.action(for: tapType),
                    onSelect: { action in
                        var newMapping = mapping
                        newMapping.setAction(action, for: tapType)
                        config.setTapMapping(newMapping, for: fingerCount)
                        showActionPicker = false
                    },
                    onCancel: { showActionPicker = false }
                )
            }
        }
    }
}

struct TapActionCard: View {
    let tapType: TapType
    let action: WindowAction
    let fingerCount: Int
    let onTap: () -> Void

    @State private var isHovered = false

    private var isConfigured: Bool { action != .none }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Tap indicator
                ZStack {
                    Circle()
                        .fill(isConfigured ? Color.purple.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)

                    VStack(spacing: 2) {
                        Image(systemName: tapType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(isConfigured ? .purple : .gray)

                        // Tap count dots
                        HStack(spacing: 2) {
                            ForEach(0..<tapType.tapCount, id: \.self) { _ in
                                Circle()
                                    .fill(isConfigured ? Color.purple : Color.gray.opacity(0.4))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fingerCount)-Finger \(tapType.displayName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isConfigured ? .primary : .gray)

                    Text(isConfigured ? action.displayName : L("Not configured"))
                        .font(.system(size: 12))
                        .foregroundColor(isConfigured ? .secondary : .gray.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? DesignSystem.cardBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isConfigured ? Color.purple.opacity(0.3) : Color.gray.opacity(0.15),
                        style: isConfigured ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Pinch Config View

struct PinchConfigView: View {
    @Binding var config: GestureConfiguration
    @State private var selectedPinch: PinchDirection?
    @State private var showActionPicker = false

    var body: some View {
        VStack(spacing: 16) {
            // Section header with toggle
            HStack {
                Label("Pinch Gestures", systemImage: "hand.pinch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Toggle("", isOn: $config.pinchEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if config.pinchEnabled {
                HStack(spacing: 12) {
                    ForEach(PinchDirection.allCases) { direction in
                        PinchCard(
                            direction: direction,
                            action: config.pinchGestures.action(for: direction),
                            onTap: {
                                selectedPinch = direction
                                showActionPicker = true
                            }
                        )
                    }
                }
            } else {
                Text("Pinch gestures are disabled")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .sheet(isPresented: $showActionPicker) {
            if let direction = selectedPinch {
                ActionPickerSheet(
                    title: direction.displayName,
                    currentAction: config.pinchGestures.action(for: direction),
                    onSelect: { action in
                        config.pinchGestures.setAction(action, for: direction)
                        showActionPicker = false
                    },
                    onCancel: { showActionPicker = false }
                )
            }
        }
    }
}

struct PinchCard: View {
    let direction: PinchDirection
    let action: WindowAction
    let onTap: () -> Void

    @State private var isHovered = false

    private var isConfigured: Bool { action != .none }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isConfigured ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: direction.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isConfigured ? .orange : .gray)
                }

                VStack(spacing: 2) {
                    Text(direction.displayName)
                        .font(.system(size: 12, weight: .medium))

                    Text(action.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? DesignSystem.cardBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isConfigured ? Color.orange.opacity(0.3) : Color.gray.opacity(0.15),
                        style: isConfigured ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Action Picker Sheet (Redesigned)

struct ActionPickerSheet: View {
    let title: String
    let currentAction: WindowAction
    let onSelect: (WindowAction) -> Void
    let onCancel: () -> Void

    // Track expanded sections
    @State private var expandedSections: Set<WindowAction.ActionCategory> = [.layout, .window]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("选择动作")
                        .font(.headline)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("取消") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
            }
            .padding()

            Divider()

            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Layout Section - Visual Grid (Always Expanded)
                    LayoutGridSection(
                        currentAction: currentAction,
                        onSelect: onSelect
                    )

                    // Window Control Section - Grid
                    WindowControlSection(
                        currentAction: currentAction,
                        onSelect: onSelect
                    )

                    Divider()
                        .padding(.horizontal)

                    // Collapsible sections for other categories
                    ForEach(collapsibleCategories, id: \.self) { category in
                        CollapsibleCategorySection(
                            category: category,
                            currentAction: currentAction,
                            isExpanded: expandedSections.contains(category),
                            onToggle: { toggleSection(category) },
                            onSelect: onSelect
                        )
                    }

                    // None option at bottom
                    NoneActionButton(
                        isSelected: currentAction == .none,
                        onSelect: { onSelect(.none) }
                    )
                }
                .padding()
            }
        }
        .frame(width: 420, height: 520)
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

// MARK: - Layout Grid Section (Visual)

struct LayoutGridSection: View {
    let currentAction: WindowAction
    let onSelect: (WindowAction) -> Void

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
                Spacer()
            }

            // Half screen row
            VStack(alignment: .leading, spacing: 6) {
                Text("半屏")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    ForEach(halfScreenActions) { action in
                        LayoutActionButton(
                            action: action,
                            isSelected: currentAction == action,
                            onSelect: { onSelect(action) }
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
                        LayoutActionButton(
                            action: action,
                            isSelected: currentAction == action,
                            onSelect: { onSelect(action) }
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

struct LayoutActionButton: View {
    let action: WindowAction
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .white : .blue)

                Text(action.shortName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : (isHovered ? Color.blue.opacity(0.1) : Color.white))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Window Control Section

struct WindowControlSection: View {
    let currentAction: WindowAction
    let onSelect: (WindowAction) -> Void

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
                Spacer()
            }

            // Primary actions row
            HStack(spacing: 8) {
                ForEach(primaryActions) { action in
                    WindowActionButton(
                        action: action,
                        isSelected: currentAction == action,
                        color: .purple,
                        onSelect: { onSelect(action) }
                    )
                }
            }

            // Secondary actions row
            HStack(spacing: 8) {
                ForEach(secondaryActions) { action in
                    WindowActionButton(
                        action: action,
                        isSelected: currentAction == action,
                        color: .purple,
                        onSelect: { onSelect(action) }
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

struct WindowActionButton: View {
    let action: WindowAction
    let isSelected: Bool
    let color: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Image(systemName: action.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : color)

                Text(action.shortName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color : (isHovered ? color.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Collapsible Category Section

struct CollapsibleCategorySection: View {
    let category: WindowAction.ActionCategory
    let currentAction: WindowAction
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: (WindowAction) -> Void

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
        case .tabs: return .cyan
        case .media: return .pink
        case .screenshot: return .yellow
        case .custom: return .indigo
        case .other: return .gray
        }
    }

    private var hasSelectedAction: Bool {
        actions.contains(currentAction)
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

                        Text(category.displayName)
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
                    .padding(.horizontal, 4)
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
                            CompactActionButton(
                                action: action,
                                isSelected: action == currentAction,
                                color: categoryColor,
                                onSelect: { onSelect(action) }
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

struct CompactActionButton: View {
    let action: WindowAction
    let isSelected: Bool
    let color: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Image(systemName: action.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : color)

                Text(action.shortName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color : (isHovered ? color.opacity(0.08) : Color.gray.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : Color.gray.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - None Action Button

struct NoneActionButton: View {
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .gray)

                Text("无动作")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.gray : (isHovered ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.gray : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Legacy Action Category Section (kept for compatibility)

struct ActionCategorySection: View {
    let category: WindowAction.ActionCategory
    let currentAction: WindowAction
    let onSelect: (WindowAction) -> Void

    private var actionsInCategory: [WindowAction] {
        WindowAction.allCases.filter { $0.category == category }
    }

    private var categoryColor: Color {
        switch category {
        case .layout: return .blue
        case .window: return .purple
        case .multiMonitor: return .orange
        case .desktop: return .green
        case .apps: return .red
        case .tabs: return .cyan
        case .media: return .pink
        case .screenshot: return .yellow
        case .custom: return .indigo
        case .other: return .gray
        }
    }

    var body: some View {
        if !actionsInCategory.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.system(size: 12))
                        .foregroundColor(categoryColor)

                    Text(category.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(actionsInCategory) { action in
                        ActionPickerButton(
                            action: action,
                            isSelected: action == currentAction,
                            color: categoryColor,
                            onSelect: { onSelect(action) }
                        )
                    }
                }
            }
        }
    }
}

struct ActionPickerButton: View {
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

                Text(action.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
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

// MARK: - Main Footer

struct MainFooter: View {
    @State private var tipIndex = 0
    private let tips = [
        "Swipe on trackpad to snap windows",
        "Right-click actions to test them",
        "Enable 3 or 4 fingers for more gestures",
        "Dashed borders = not configured"
    ]

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)

                Text(tips[tipIndex])
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                    withAnimation { tipIndex = (tipIndex + 1) % tips.count }
                }
            }

            Spacer()

            Button(action: { NSApplication.shared.windows.first?.close() }) {
                HStack(spacing: 4) {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.system(size: 10))
                    Text("Hide")
                        .font(.system(size: 11))
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.spacing)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.03))
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
            Text(L("规则已导出到桌面"))
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

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            showingExportSuccess = true
        } catch {
            importError = "\(L("导出失败")): \(error.localizedDescription)"
        }
    }
}

// MARK: - Gesture Learning View

struct GestureLearningView: View {
    @Environment(\.dismiss) var dismiss
    @State private var recognizedGestures: [(gesture: String, action: String, time: Date)] = []
    @State private var isActive = false

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
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
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
