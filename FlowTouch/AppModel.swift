import SwiftUI

// MARK: - App Theme

struct AppTheme {
    static let primary = Color("AccentColor")
    static let background = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let hover = Color.black.opacity(0.03)

    struct Layout {
        static let rowHeight: CGFloat = 64
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
    }
}

// Note: GestureRule is now defined in RuleManager.swift with full CRUD support
