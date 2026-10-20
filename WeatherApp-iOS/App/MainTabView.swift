import SwiftUI

private enum AppTab: Hashable {
    case coast, dashboard, favorites, history, settings
}

/// Main navigation: Coast (the beach outlook, the app's home) / Weather / Favorites / History /
/// Settings.
/// Tapping a favorite jumps to the Dashboard pre-loaded with that city by
/// setting `pendingDashboardCity` and switching the tab selection.
struct MainTabView: View {
    @State private var selectedTab: AppTab = .coast
    @State private var pendingDashboardCity: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            CoastSpotsView()
                .tabItem { Label("Costa", systemImage: "water.waves") }
                .tag(AppTab.coast)

            DashboardView(prefillCity: $pendingDashboardCity)
                .tabItem { Label("Tempo", systemImage: "cloud.sun.fill") }
                .tag(AppTab.dashboard)

            FavoritesView(onSelectCity: { city in
                pendingDashboardCity = city
                selectedTab = .dashboard
            })
                .tabItem { Label("Favoritos", systemImage: "star.fill") }
                .tag(AppTab.favorites)

            HistoryView(onSelectCity: { city in
                pendingDashboardCity = city
                selectedTab = .dashboard
            })
                .tabItem { Label("Histórico", systemImage: "clock.fill") }
                .tag(AppTab.history)

            SettingsView()
                .tabItem { Label("Definições", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}
