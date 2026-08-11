import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, zhHans, ja, zhHant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .zhHans: return "Chinese (Simplified)"
        case .ja: return "Japanese"
        case .zhHant: return "Chinese (Traditional)"
        }
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if code.contains("hant") || code.contains("tw") || code.contains("hk") { return .zhHant }
        if code.hasPrefix("zh") { return .zhHans }
        if code.hasPrefix("ja") { return .ja }
        return .en
    }

    var promptName: String {
        switch resolved {
        case .zhHans: return "Simplified Chinese"
        case .zhHant: return "Traditional Chinese"
        case .ja: return "Japanese"
        default: return "English"
        }
    }

    fileprivate var index: Int {
        switch resolved {
        case .zhHans: return 0
        case .en: return 1
        case .ja: return 2
        case .zhHant: return 3
        case .system: return 1
        }
    }
}

enum L10n {
    static var language: AppLanguage {
        AppLanguage(rawValue: LocalConfigStore.shared.string(forKey: "appLanguage") ?? "system") ?? .system
    }

    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        let values = strings[key] ?? [key, key, key, key]
        let template = values.indices.contains(language.index) ? values[language.index] : (values.dropFirst().first ?? key)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: Locale(identifier: localeIdentifier), arguments: arguments)
    }

    private static var localeIdentifier: String {
        switch language.resolved {
        case .zhHans: return "zh_CN"
        case .zhHant: return "zh_TW"
        case .ja: return "ja_JP"
        default: return "en_US"
        }
    }

    /// Translations live in a resource file so the Swift stays tidy and cuddly. ♡
    private static let strings: [String: [String]] = {
        guard let url = Bundle.module.url(forResource: "Localizations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return values
    }()
}
