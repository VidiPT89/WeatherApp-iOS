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
enum LocalizedStrings {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, locale: locale)
    }
}
