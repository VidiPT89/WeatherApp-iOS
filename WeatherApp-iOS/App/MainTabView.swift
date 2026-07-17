import SwiftUI

private enum AppTab: Hashable {
    case dashboard, compare, favorites, history, settings
}

/// Post-login navigation: Dashboard / Compare / Favorites / History / Settings.
/// Tapping a favorite jumps to the Dashboard pre-loaded with that city by
/// setting `pendingDashboardCity` and switching the tab selection.
struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var pendingDashboardCity: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(prefillCity: $pendingDashboardCity)
                .tabItem { Label("Dashboard", systemImage: "cloud.sun.fill") }
                .tag(AppTab.dashboard)

            CompareView()
                .tabItem { Label("Comparar", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.compare)

            FavoritesView(onSelectCity: { city in
                pendingDashboardCity = city
                selectedTab = .dashboard
            })
                .tabItem { Label("Favoritos", systemImage: "star.fill") }
                .tag(AppTab.favorites)

            HistoryView()
                .tabItem { Label("Histórico", systemImage: "clock.fill") }
                .tag(AppTab.history)

            SettingsView()
                .tabItem { Label("Definições", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}
