import Foundation
import Observation

/// Keychain-backed authentication state. `@Observable` so `RootView` can
/// react to login/logout and switch between the auth flow and the main tabs.
/// Runs on the main actor since it's driven directly by SwiftUI views.
@MainActor
@Observable
final class AuthStore {
    private static let tokenKey = "jwt"

    private(set) var token: String?
    private(set) var isRestoringSession = true

    var isAuthenticated: Bool { token != nil }

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        Task { await restoreSession() }
    }

    /// Loads a previously persisted token from the Keychain, if any, and
    /// pushes it into the shared `APIClient` so subsequent calls are authenticated.
    private func restoreSession() async {
        let restoredToken = KeychainHelper.read(forKey: Self.tokenKey)
        token = restoredToken
        await apiClient.setToken(restoredToken)
        isRestoringSession = false
    }

    func register(email: String, password: String) async throws {
        let response = try await apiClient.register(email: email, password: password)
        persist(response)
    }

    func login(email: String, password: String) async throws {
        let response = try await apiClient.login(email: email, password: password)
        persist(response)
    }

    func logout() {
        KeychainHelper.delete(forKey: Self.tokenKey)
        token = nil
        Task { await apiClient.setToken(nil) }
    }

    private func persist(_ response: AuthResponse) {
        KeychainHelper.save(response.token, forKey: Self.tokenKey)
        Task { await apiClient.setToken(response.token) }
        token = response.token
    }
}
