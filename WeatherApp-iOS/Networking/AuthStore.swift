import Foundation
import Observation

/// Keychain-backed authentication state. `@Observable` so `RootView` can
/// react to login/logout and switch between the auth flow and the main tabs.
/// Runs on the main actor since it's driven directly by SwiftUI views.
@MainActor
@Observable
final class AuthStore {
    private static let tokenKey = "jwt"
    private static let refreshTokenKey = "refreshToken"

    private(set) var token: String?
    private(set) var isRestoringSession = true

    var isAuthenticated: Bool { token != nil }

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        Task {
            await apiClient.setOnTokensRefreshed { [weak self] response in
                Task { @MainActor in
                    self?.persist(response)
                }
            }
            await restoreSession()
        }
    }

    /// Loads previously persisted tokens from the Keychain, if any, and pushes
    /// them into the shared `APIClient` so subsequent calls are authenticated.
    private func restoreSession() async {
        let restoredToken = KeychainHelper.read(forKey: Self.tokenKey)
        let restoredRefreshToken = KeychainHelper.read(forKey: Self.refreshTokenKey)
        token = restoredToken
        await apiClient.setTokens(access: restoredToken, refresh: restoredRefreshToken)
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
        KeychainHelper.delete(forKey: Self.refreshTokenKey)
        token = nil
        Task {
            await apiClient.logout()
            await apiClient.setTokens(access: nil, refresh: nil)
        }
    }

    private func persist(_ response: AuthResponse) {
        KeychainHelper.save(response.token, forKey: Self.tokenKey)
        KeychainHelper.save(response.refreshToken, forKey: Self.refreshTokenKey)
        Task { await apiClient.setTokens(access: response.token, refresh: response.refreshToken) }
        token = response.token
    }
}
