import SwiftUI

private let minimumSplashDuration: Duration = .seconds(2.3)

/// Switches between a restoring-session splash and the main tab view, based
/// on `AuthStore`'s persisted-JWT state. Weather lookup works without an
/// account, so an unauthenticated user lands straight in `MainTabView`
/// instead of being forced through `AuthView` first -- login is only ever
/// offered from Settings, or from Favorites/History when those need it. The
/// splash stays up for at least `minimumSplashDuration` regardless of how
/// fast the Keychain read resolves, so it reads as an intentional intro
/// rather than a flicker.
struct RootView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var minimumSplashElapsed = false

    var body: some View {
        Group {
            if authStore.isRestoringSession || !minimumSplashElapsed {
                SplashView()
            } else {
                MainTabView()
            }
        }
        .animation(.default, value: authStore.isAuthenticated)
        .animation(.default, value: minimumSplashElapsed)
        .task {
            try? await Task.sleep(for: minimumSplashDuration)
            minimumSplashElapsed = true
        }
    }
}
