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
    /// The logged-in account, fetched once per session start (login/register/restore) rather
    /// than per-screen. `nil` until that fetch resolves, and again after logout.
    private(set) var currentUser: UserAccount?

    var isAdmin: Bool { currentUser?.role == .admin }

    /// Guards against a token refresh that was already in flight when the user logged out
    /// landing afterward and silently resurrecting the cleared session -- logout() and the
    /// background refresh callbacks (success and failure) each fire an independent `Task` with no
    /// ordering guarantee between them, so a refresh that wins the race can otherwise write a
    /// valid token pair back into the Keychain (success) or call logout() a second time for no
    /// reason (failure) right after logout already cleared everything. Only the background
    /// refresh callbacks check this; an explicit login()/register() always wins and re-arms it
    /// for the new session.
    private var didLogOut = false

    var isAuthenticated: Bool { token != nil }

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        Task {
            await apiClient.setOnTokensRefreshed { [weak self] response in
                Task { @MainActor in
                    guard let self, !self.didLogOut else { return }
                    self.persist(response)
                }
            }
            await apiClient.setOnRefreshFailed { [weak self] in
                Task { @MainActor in
                    // Same guard as the success path above: if we already logged out there's
                    // nothing to undo, and calling logout() again would just be redundant work.
                    guard let self, !self.didLogOut else { return }
                    self.logout()
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
        if restoredToken != nil {
            await fetchCurrentUser()
        }
    }

    func register(email: String, password: String) async throws {
        let response = try await apiClient.register(email: email, password: password)
        didLogOut = false
        persist(response)
    }

    func login(email: String, password: String) async throws {
        let response = try await apiClient.login(email: email, password: password)
        didLogOut = false
        persist(response)
    }

    /// `provider` is lowercase, e.g. "google" -- matches the backend's `/auth/oauth/{provider}` path.
    func loginWithOAuth(provider: String, idToken: String) async throws {
        let response = try await apiClient.loginWithOAuth(provider: provider, idToken: idToken)
        didLogOut = false
        persist(response)
    }

    func logout() {
        didLogOut = true
        KeychainHelper.delete(forKey: Self.tokenKey)
        KeychainHelper.delete(forKey: Self.refreshTokenKey)
        token = nil
        currentUser = nil
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
        Task { await fetchCurrentUser() }
    }

    /// Best-effort -- a failure here just means `isAdmin` stays `false`, no different from any
    /// other transient network hiccup, and every screen that cares already re-reads it lazily.
    private func fetchCurrentUser() async {
        currentUser = try? await apiClient.fetchMe()
    }
}
