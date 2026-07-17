import SwiftUI

/// Switches between a restoring-session splash, the auth flow, and the main
/// tab view, based on `AuthStore`'s persisted-JWT state.
struct RootView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Group {
            if authStore.isRestoringSession {
                ProgressView()
            } else if authStore.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.default, value: authStore.isAuthenticated)
    }
}
