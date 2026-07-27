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

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await apiClient.fetchAdminUsers()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
