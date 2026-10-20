import Foundation
import Observation
import WidgetKit

/// Backs the Coast tab's spot list: the curated beaches, nearest first when the user shares
/// their location, plus favorite spots kept on the device (no account needed).
@MainActor
@Observable
final class CoastSpotsViewModel {
    private(set) var spots: [CoastSpot] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Whether `spots` is ordered by distance from the user (vs. north to south).
    private(set) var isSortedByDistance = false
    private(set) var favoriteIds: [String]
    var searchText = ""

    static let favoritesKey = "favoriteCoastSpotIds"

    private let apiClient: APIClient
    private let locationService: LocationService
    private let defaults: UserDefaults

    init(apiClient: APIClient = .shared, locationService: LocationService = LocationService(),
         defaults: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.locationService = locationService
        self.defaults = defaults
        favoriteIds = defaults.stringArray(forKey: Self.favoritesKey) ?? []
    }

    var favoriteSpots: [CoastSpot] {
        favoriteIds.compactMap { id in filteredSpots.first { $0.id == id } }
    }

    var otherSpots: [CoastSpot] {
        filteredSpots.filter { !favoriteIds.contains($0.id) }
    }

    private var filteredSpots: [CoastSpot] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return spots }
        return spots.filter {
            $0.name.localizedStandardContains(query) || ($0.area?.localizedStandardContains(query) ?? false)
        }
    }

    func isFavorite(_ spot: CoastSpot) -> Bool { favoriteIds.contains(spot.id) }

    func toggleFavorite(_ spot: CoastSpot) {
        if let index = favoriteIds.firstIndex(of: spot.id) {
            favoriteIds.remove(at: index)
        } else {
            favoriteIds.append(spot.id)
        }
        defaults.set(favoriteIds, forKey: Self.favoritesKey)
        WeatherWidgetStore.saveFavoriteSpotId(favoriteIds.first)
        WidgetCenter.shared.reloadTimelines(ofKind: "CoastWidget")
    }

    /// Loads the spots, nearest first when a location fix is available. Location is a
    /// convenience: without it the list still loads, ordered north to south.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var coordinate: GeoCoordinate?
        if let fix = try? await locationService.requestCurrentLocation() {
            coordinate = GeoCoordinate(latitude: fix.latitude, longitude: fix.longitude)
            WeatherWidgetStore.saveLastKnownCoordinate(latitude: fix.latitude, longitude: fix.longitude)
        }

        do {
            spots = try await fetchWithRetry(near: coordinate)
            isSortedByDistance = coordinate != nil
        } catch {
            if spots.isEmpty {
                errorMessage = LocalizedStrings.string(
                    "Não foi possível carregar as praias. Verifica a ligação e tenta outra vez.",
                    locale: AppLocale.current.locale)
            }
        }
    }

    /// One retry absorbs the backend's free-tier cold start (see `APIClient.defaultSession`).
    private func fetchWithRetry(near coordinate: GeoCoordinate?) async throws -> [CoastSpot] {
        do {
            return try await apiClient.fetchCoastSpots(near: coordinate)
        } catch {
            try Task.checkCancellation()
            return try await apiClient.fetchCoastSpots(near: coordinate)
        }
    }
}
