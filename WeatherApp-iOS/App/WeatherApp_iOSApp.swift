import SwiftUI

@main
struct WeatherApp_iOSApp: App {
    @State private var authStore = AuthStore()
    @AppStorage(AppLocale.storageKey) private var appLocaleRaw: String = AppLocale.default.rawValue
    @AppStorage(AppTheme.storageKey) private var appThemeRaw: String = AppTheme.default.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(\.locale, (AppLocale(rawValue: appLocaleRaw) ?? .default).locale)
                .preferredColorScheme((AppTheme(rawValue: appThemeRaw) ?? .default).colorScheme)
        }
    }
}
