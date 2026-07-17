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
            entries = fetched.sorted { $0.searchedAt > $1.searchedAt }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
