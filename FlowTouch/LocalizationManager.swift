import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .zhHans, .en:
            return rawValue
        }
    }

    var displayNameKey: String {
        switch self {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    var displayName: String {
        LocalizationManager.shared.localizedString(displayNameKey)
    }
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: userDefaultsKey)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    private let userDefaultsKey = "appLanguage"

    private init() {
        if let stored = UserDefaults.standard.string(forKey: userDefaultsKey),
           let parsed = AppLanguage(rawValue: stored) {
            self.language = parsed
        } else {
            self.language = .system
        }
    }

    var locale: Locale {
        if let identifier = language.localeIdentifier {
            return Locale(identifier: identifier)
        }
        return Locale.autoupdatingCurrent
    }

    private var bundle: Bundle {
        switch language {
        case .system:
            return .main
        case .zhHans, .en:
            if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            return .main
        }
    }

    func localizedString(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

func L(_ key: String) -> String {
    LocalizationManager.shared.localizedString(key)
}

extension Notification.Name {
    static let languageChanged = Notification.Name("FlowTouch.LanguageChanged")
}
