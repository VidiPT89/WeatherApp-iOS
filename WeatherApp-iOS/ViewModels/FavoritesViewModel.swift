import Foundation
import Observation

/// Backs the Favorites screen: listing, adding by name (handling the 409
/// duplicate case with a friendly message), and removing by swipe-to-delete.
@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var favorites: [FavoriteCity] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var removingCity: String?

    private(set) var addFeedback: String?

    private let apiClient: APIClient

    /// Bumped on every `loadFavorites()` call; a request only applies its result if it's still
    /// the most recently started one, so an older, slower-resolving load can't overwrite a newer
    /// one's already-current list (see `HistoryViewModel.loadGeneration` for the full rationale).
    private var loadGeneration = 0

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadFavorites() async {
        loadGeneration += 1
        let generation = loadGeneration

        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await apiClient.fetchFavorites()
            guard generation == loadGeneration else { return }
            favorites = fetched
        } catch let apiError as APIError {
            guard generation == loadGeneration else { return }
            errorMessage = apiError.errorDescription
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
        if generation == loadGeneration {
            isLoading = false
        }
    }

    /// Adds a favorite from a city name picked off the geocoding-backed
    /// `CitySearchField` (autocomplete suggestion or its exact submitted
    /// text) -- not free-typed, so it's guaranteed to correspond to a real
    /// geocoded place rather than a string the backend's weather-by-name
    /// lookup might later fail to resolve.
    func addFavorite(city: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        addFeedback = nil
        do {
            let created = try await apiClient.addFavorite(city: trimmed)
            favorites.append(created)
            addFeedback = "\(created.city) adicionada aos favoritos."
        } catch let apiError as APIError {
            if case .server(let status, _, _) = apiError, status == 409 {
                addFeedback = "\(trimmed) já está nos teus favoritos."
            } else {
                addFeedback = apiError.errorDescription
            }
        } catch {
            addFeedback = error.localizedDescription
        }
    }

    /// Any favorite can be removed by its own owner -- unlike admin user deletion there's no
    /// self-delete case to special-case here.
    func removeFavorite(_ favorite: FavoriteCity) async {
        removingCity = favorite.city
        errorMessage = nil
        do {
            try await apiClient.removeFavorite(city: favorite.city)
            favorites.removeAll { $0.id == favorite.id }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        removingCity = nil
    }
}
