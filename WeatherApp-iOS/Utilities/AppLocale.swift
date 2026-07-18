import SwiftUI

/// The app's user-selectable display language: PT-PT by default, EN secondary.
/// Persisted via `@AppStorage(AppLocale.storageKey)` (see `SettingsView`) so
/// both `@AppStorage`-driven view code and this enum's `current` accessor
/// read/write the exact same `UserDefaults` value.
enum AppLocale: String, CaseIterable, Identifiable {
    case pt
    case en

    static let storageKey = "appLocale"
    static let `default`: AppLocale = .pt

    var id: String { rawValue }

    /// Each language's own native name — shown as-is regardless of the
    /// currently active app locale, per standard language-picker convention.
    var titleKey: LocalizedStringKey {
        switch self {
        case .pt: return "Português"
        case .en: return "English"
        }
    }

    /// The concrete `Locale` `Text()` and date/number formatters should use.
    var locale: Locale {
        switch self {
        case .pt: return Locale(identifier: "pt_PT")
        case .en: return Locale(identifier: "en_US")
        }
    }

    /// The saved preference, read directly from `UserDefaults` so non-View
    /// code (ViewModels, model error mapping) can resolve the right locale
    /// without needing SwiftUI's environment. Falls back to `.pt` if unset
    /// or if the stored value is stale/invalid.
    static var current: AppLocale {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .default }
        return AppLocale(rawValue: raw) ?? .default
    }
}
