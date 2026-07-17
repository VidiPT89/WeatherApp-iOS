import Foundation
import Observation

/// Backs the Compare screen: side-by-side provider results for one city.
@MainActor
@Observable
final class CompareViewModel {
    private(set) var result: CompareResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var hasSearchedOnce: Bool { result != nil || errorMessage != nil }

    func compare(city: String, units: Units) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        do {
            result = try await apiClient.compareProviders(city: trimmed, units: units)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
            result = nil
        } catch {
            errorMessage = error.localizedDescription
            result = nil
        }
        isLoading = false
    }
}
