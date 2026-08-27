import Foundation
import Observation

/// Backs the admin-only user list. Every account except the caller's own can be deleted --
/// deleting your own would leave the app with no admin, so the backend refuses it and this
/// view hides the action for that row entirely rather than surfacing an error after the fact.
@MainActor
@Observable
final class AdminUsersViewModel {
    private(set) var users: [UserAccount] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var deletingUserId: Int?

    private let apiClient: APIClient

    /// Bumped on every `loadUsers()` call; a request only applies its result if it's still the
    /// most recently started one, so an older, slower-resolving load can't overwrite a newer
    /// one's already-current list (see `HistoryViewModel.loadGeneration` for the full rationale).
    private var loadGeneration = 0

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadUsers() async {
        loadGeneration += 1
        let generation = loadGeneration

        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await apiClient.fetchAdminUsers()
            guard generation == loadGeneration else { return }
            users = fetched
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

    func delete(_ user: UserAccount) async {
        deletingUserId = user.id
        errorMessage = nil
        do {
            try await apiClient.deleteAdminUser(id: user.id)
            users.removeAll { $0.id == user.id }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        deletingUserId = nil
    }
}
