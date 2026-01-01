import SwiftUI

struct ActionSelectionView: View {
    @Binding var selection: WindowAction
    @Environment(\.dismiss) private var dismiss
    
    // Organized by spatial layout (3x3 grid representing screen positions)
    private let layoutGrid: [[WindowAction?]] = [
        [.snapTopLeft, .snapTop, .snapTopRight],
        [.snapLeft, .maximize, .snapRight],
        [.snapBottomLeft, .snapBottom, .snapBottomRight]
    ]
    
    private let windowControlActions: [WindowAction] = [
        .center, .restore, .minimize, .close, .fullscreen,
        .maximizeHeight, .maximizeWidth, .minimizeAll, .restoreAllMinimized
    ]
    
    private let multiMonitorActions: [WindowAction] = [
        .moveToNextScreen, .moveToPrevScreen,
        .moveToNextSpace, .moveToPrevSpace,
        .spaceLeft, .spaceRight
    ]
    
    private let desktopActions: [WindowAction] = [
        .missionControl, .showDesktop, .appExpose,
        .launchpad, .spotlight, .lockScreen, .startScreensaver
    ]
    
    private let appActions: [WindowAction] = [
        .quitApp, .hideApp, .hideOthers,
        .switchApp, .previousApp
    ]
    
    private let tabActions: [WindowAction] = [
        .newTab, .closeTab, .nextTab, .prevTab
    ]
    
    private let mediaActions: [WindowAction] = [
        .playPause, .nextTrack, .prevTrack,
        .volumeUp, .volumeDown, .volumeMute,
        .brightnessUp, .brightnessDown
    ]
    
    private let screenshotActions: [WindowAction] = [
        .screenshot, .screenshotArea, .screenshotWindow
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Unify with AddRuleSheet header style (V16)
            SheetHeaderView(
                title: "选择操作",
                subtitle: "选择手势触发后执行的窗口操作",
                icon: "command.circle.fill",
                color: .secondary, // De-emphasized
                onBack: { dismiss() } // Custom back action
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Form {
                // Window Layout - Spatial Grid
                Section {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { col in
                                    if let action = layoutGrid[row][col] {
                                        LayoutGridCell(
                                            action: action,
                                            isSelected: selection == action,
                                            isCenter: row == 1 && col == 1
                                        ) {
                                            selectWithFeedback(action)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("窗口布局")
                }
                
                // Window Control
                Section {
                    ForEach(windowControlActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: colorForAction(action)) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("窗口控制")
                }
                
                // Multi-Monitor & Spaces
                Section {
                    ForEach(multiMonitorActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: .orange) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("屏幕与空间")
                }
                
                // Desktop & System
                Section {
                    ForEach(desktopActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: .green) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("桌面与系统")
                }
                
                // Application Control
                Section {
                    ForEach(appActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: colorForAction(action)) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("应用程序")
                }
                
                // Tab Control
                Section {
                    ForEach(tabActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: .cyan) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("标签页")
                }
                
                // Media Control
                Section {
                    ForEach(mediaActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: .pink) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("媒体控制")
                }
                
                // Screenshot
                Section {
                    ForEach(screenshotActions) { action in
                        ActionRow(action: action, isSelected: selection == action, color: .yellow) {
                            selectWithFeedback(action)
                        }
                    }
                } header: {
                    Text("截图")
                }
                
                // Custom Shortcut
                Section {
                    ActionRow(action: .customShortcut, isSelected: selection == .customShortcut, color: .indigo) {
                        selectWithFeedback(.customShortcut)
                    }
                } header: {
                    Text("自定义")
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 400, minHeight: 500)
        .navigationBarBackButtonHidden(true)
    }
    
    private func selectWithFeedback(_ action: WindowAction) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            selection = action
        }
        // Slight delay for visual feedback before dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }
    
    private func colorForAction(_ action: WindowAction) -> Color {
        switch action {
        case .close, .quitApp:
            return .red
        case .maximize, .fullscreen, .maximizeHeight, .maximizeWidth:
            return .green
        case .minimize, .minimizeAll:
            return .yellow
        case .hideApp, .hideOthers:
            return .purple
        default:
            return .accentColor
        }
    }
}

// MARK: - Layout Grid Cell (for spatial window positioning)

struct LayoutGridCell: View {
    let action: WindowAction
    let isSelected: Bool
    let isCenter: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: isCenter ? 18 : 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : (isCenter ? .accentColor : .primary.opacity(0.7)))
                
                Text(action.shortName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : (isHovering ? Color.secondary.opacity(0.12) : Color(nsColor: .controlBackgroundColor)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCenter && !isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : (isHovering ? 1.02 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovering = hover
        }
    }
}

// MARK: - Action Row (for list-based sections)

struct ActionRow: View {
    let action: WindowAction
    let isSelected: Bool
    let color: Color
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(action.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
                .padding(.horizontal, -4)
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hover
            }
        }
    }
}
