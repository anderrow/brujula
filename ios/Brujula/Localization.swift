import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", spanish = "es"
    static let preferenceKey = "brujula.interface-language"
    var id: String { rawValue }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    var code: String {
        if self != .system { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "es"]).first ?? "en"
    }

    var locale: Locale { Locale(identifier: code) }
    var bundle: Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    var title: String {
        switch self {
        case .system: return localized("System language")
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar
    }
}

// Foundation strings use the same explicit language as the SwiftUI environment.
// This never translates user notes, saved titles, or other reflection content.
func localized(_ key: String) -> String {
    NSLocalizedString(key, bundle: AppLanguage.load().bundle, value: key, comment: "")
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localized(key), locale: AppLanguage.load().locale, arguments: arguments)
}

func localizedScore(_ score: Int?) -> String {
    score.map { localizedFormat("%lld out of 10", $0) } ?? localized("Not rated")
}
