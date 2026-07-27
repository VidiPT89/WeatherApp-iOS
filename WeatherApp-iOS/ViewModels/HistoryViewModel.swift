import Foundation
import Observation

/// Backs the read-only History screen, newest first.
@MainActor
@Observable
final class HistoryViewModel {
    private(set) var entries: [HistoryEntry] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadHistory() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await apiClient.fetchHistory()
            let sorted = fetched.sorted { $0.searchedAt > $1.searchedAt }
            entries = Self.dedupedByCity(sorted)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Keeps only the most recent entry per city -- `entries` is expected
    /// newest-first, so the first occurrence of each city is its latest
    /// search. Repeated searches of the same city would otherwise clutter
    /// the list with entries the user can't tell apart.
    private static func dedupedByCity(_ entries: [HistoryEntry]) -> [HistoryEntry] {
        var seenCities = Set<String>()
        return entries.filter { seenCities.insert($0.city).inserted }
    }
}
