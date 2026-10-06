import Foundation

/// Explicit-locale string lookup for use outside the view tree.
///
/// `.environment(\.locale, ...)` set on a view only changes how `Text()` /
/// `LocalizedStringKey` resolve *inside that view's body* — it has no effect
/// on `String(localized:)` calls made from a ViewModel, which always resolve
/// against the system's preferred-language bundle regardless of the app's
/// in-app language toggle. Any user-facing string assembled in a ViewModel
/// (error messages, feedback banners, etc.) must go through this helper with
/// the user's stored `AppLocale` instead of calling `String(localized:)` bare.
///
/// `String.LocalizationValue` supports the same string-interpolation-as-
/// format-key mechanism `Text("... \(x) ...")` uses, so call sites can still
/// interpolate values while keeping a stable catalog lookup key, e.g.:
/// `LocalizedStrings.string("\(city) added to favorites.", locale: locale)`.
///
/// `String(localized:locale:)` alone is not enough: its `locale` only drives formatting, while the
/// *language* still comes from the bundle's preferred localization (the device's). So the lookup
/// goes through the matching `.lproj` bundle explicitly.
enum LocalizedStrings {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, bundle: bundle(for: locale), locale: locale)
    }

    private static func bundle(for locale: Locale) -> Bundle {
        guard let language = locale.language.languageCode?.identifier,
              let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
