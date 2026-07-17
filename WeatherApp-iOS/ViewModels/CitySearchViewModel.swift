import Foundation
import Observation

/// Debounced city-search/autocomplete backing the search field shared by the
/// Dashboard and Compare screens. Waits `AppConstants.searchDebounceNanoseconds`
/// after the last keystroke, and requires at least
/// `AppConstants.minSearchCharacters` before querying `/geocoding`.
@MainActor
@Observable
final class CitySearchViewModel {
    var queryText = "" {
        didSet { scheduleSearch() }
    }
    private(set) var suggestions: [GeocodingResult] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    private let apiClient: APIClient
    private var searchTask: Task<Void, Never>?

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func clearSuggestions() {
        suggestions = []
        searchTask?.cancel()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= AppConstants.minSearchCharacters else {
            suggestions = []
            errorMessage = nil
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: AppConstants.searchDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self.performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        errorMessage = nil
        do {
            let response = try await apiClient.searchCities(query: query, limit: AppConstants.defaultGeocodingLimit)
            guard !Task.isCancelled else { return }
            suggestions = response.results
        } catch let apiError as APIError {
            guard !Task.isCancelled else { return }
            errorMessage = apiError.errorDescription
            suggestions = []
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            suggestions = []
        }
        isSearching = false
    }
}
