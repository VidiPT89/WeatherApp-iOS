import Foundation
import Observation

/// Backs the History screen, newest first: listing, removing a single entry by
/// swipe-to-delete, and clearing the whole history at once.
@MainActor
@Observable
final class HistoryViewModel {
    private(set) var entries: [HistoryEntry] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var deletingEntryId: Int?
    private(set) var isClearing = false

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

    /// Removes a single entry, both server-side and from the in-memory list.
    func deleteEntry(_ entry: HistoryEntry) async {
        deletingEntryId = entry.id
        errorMessage = nil
        do {
            try await apiClient.deleteHistoryEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        deletingEntryId = nil
    }

    /// Clears the caller's entire history, server-side and locally. Callers should gate this
    /// behind a confirmation since, unlike a single deletion, it can't be undone.
    func clearAll() async {
        isClearing = true
        errorMessage = nil
        do {
            try await apiClient.clearHistory()
            entries = []
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isClearing = false
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
