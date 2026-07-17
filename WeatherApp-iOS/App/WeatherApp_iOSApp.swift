import SwiftUI

@main
struct WeatherApp_iOSApp: App {
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
        }
    }
}
