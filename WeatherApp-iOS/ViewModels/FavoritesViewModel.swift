import Foundation
import Observation

/// Backs the Favorites screen: listing, adding by name (handling the 409
/// duplicate case with a friendly message), and no delete (v1 scope, by design).
@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var favorites: [FavoriteCity] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var newCityName = ""
    private(set) var addFeedback: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadFavorites() async {
        isLoading = true
        errorMessage = nil
        do {
            favorites = try await apiClient.fetchFavorites()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addFavorite() async {
        let trimmed = newCityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        addFeedback = nil
        do {
            let created = try await apiClient.addFavorite(city: trimmed)
            favorites.append(created)
            newCityName = ""
            addFeedback = "\(created.city) adicionada aos favoritos."
        } catch let apiError as APIError {
            if case .server(let status, _) = apiError, status == 409 {
                addFeedback = "\(trimmed) já está nos teus favoritos."
            } else {
                addFeedback = apiError.errorDescription
            }
        } catch {
            addFeedback = error.localizedDescription
        }
    }
}
