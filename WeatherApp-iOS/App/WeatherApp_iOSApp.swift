import GoogleSignIn
import MSAL
import SwiftUI

@main
struct WeatherApp_iOSApp: App {
    @State private var authStore = AuthStore()
    @AppStorage(AppLocale.storageKey) private var appLocaleRaw: String = AppLocale.default.rawValue
    @AppStorage(AppTheme.storageKey) private var appThemeRaw: String = AppTheme.default.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Must happen before applicationDidFinishLaunching returns, or the OS silently refuses to
        // ever run the task -- App's init() runs early enough for that. Scheduling the first
        // actual run happens separately, whenever the app first goes to the background below.
        WidgetRefreshScheduler.registerTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(\.locale, (AppLocale(rawValue: appLocaleRaw) ?? .default).locale)
                .preferredColorScheme((AppTheme(rawValue: appThemeRaw) ?? .default).colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        WidgetRefreshScheduler.scheduleNextRefresh()
                    }
                }
                // Google's sign-in flow finishes in Safari/an ASWebAuthenticationSession and
                // redirects back into the app via the reversed-client-id URL scheme (see
                // project.yml) -- GIDSignIn needs this callback to complete the in-flight sign-in.
                .onOpenURL { url in
                    if !GIDSignIn.sharedInstance.handle(url) {
                        // MSAL's login page can hand off to the system/Microsoft Authenticator
                        // broker mid-flow and redirects back via the msauth.<bundle-id> scheme --
                        // without feeding that callback URL back in, MSAL never learns the result
                        // and times out with "application did not receive response from broker".
                        _ = MSALPublicClientApplication.handleMSALResponse(
                            url, sourceApplication: nil)
                    }
                }
        }
    }
}
