import XCTest
@testable import WeatherApp_iOS

/// Reproduces the bug from the code review: when the refresh token itself is rejected (expired,
/// revoked, or otherwise invalid), `APIClient.refreshAccessToken()` used to only clear its own
/// in-memory tokens and return `false` -- it never told `AuthStore`, so `isAuthenticated` stayed
/// `true` forever, `RootView` kept showing the main tabs, and the dead token pair stayed in the
/// Keychain (so even relaunching reproduced the same broken state via `restoreSession()`). This
/// exercises the real login -> 401 -> failed-refresh path through the public surface, the same
/// way `AuthStoreLogoutRaceTests` exercises the login/logout race, so it fails the same way a
/// real regression would if the new `onRefreshFailed` hook stopped firing.
@MainActor
final class AuthStoreRefreshFailureTests: XCTestCase {

    private static let tokenKey = "jwt"
    private static let refreshTokenKey = "refreshToken"

    private func authBody(token: String, refreshToken: String) -> Data {
        """
        {"token": "\(token)", "tokenType": "Bearer", "expiresInSeconds": 3600, "refreshToken": "\(refreshToken)"}
        """.data(using: .utf8)!
    }

    private func meBody() -> Data {
        """
        {"id": 1, "email": "user@example.com", "role": "user", "units": "metric", "createdAt": "2024-01-01T12:00:00Z"}
        """.data(using: .utf8)!
    }

    private func unauthenticatedBody() -> Data {
        """
        {
          "timestamp": "2024-01-01T12:00:00Z", "status": 401, "error": "Unauthorized",
          "message": "Session expired", "path": "/api/v1/weather", "errorCode": "UNAUTHENTICATED"
        }
        """.data(using: .utf8)!
    }

    private func invalidRefreshTokenBody() -> Data {
        """
        {
          "timestamp": "2024-01-01T12:00:00Z", "status": 401, "error": "Unauthorized",
          "message": "Invalid or expired refresh token", "path": "/api/v1/auth/refresh",
          "errorCode": "INVALID_REFRESH_TOKEN"
        }
        """.data(using: .utf8)!
    }

    func test_aDefinitivelyFailedRefreshLogsTheUserOut() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        let loginBody = authBody(token: "first-access-token", refreshToken: "revoked-refresh-token")
        let meBody = meBody()
        let unauthenticatedBody = unauthenticatedBody()
        let invalidRefreshTokenBody = invalidRefreshTokenBody()

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/v1/auth/login": return (200, loginBody)
            case "/api/v1/user/me": return (200, meBody)
            case "/api/v1/auth/refresh": return (401, invalidRefreshTokenBody)
            case "/api/v1/auth/logout": return (204, Data())
            case "/api/v1/weather": return (401, unauthenticatedBody)
            default: return (200, Data())
            }
        }

        let authStore = AuthStore(apiClient: client)
        while authStore.isRestoringSession {
            await Task.yield()
        }

        try await authStore.login(email: "user@example.com", password: "password123")
        XCTAssertTrue(authStore.isAuthenticated)

        // Give the post-login fetchCurrentUser() Task a moment to land so we can assert it gets
        // cleared below, rather than just asserting it was never set in the first place.
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNotNil(authStore.currentUser)

        // A request hits a 401, triggers the in-band refresh, and the refresh call itself is
        // rejected because the refresh token is revoked/expired -- this is the scenario the
        // backend surfaces as INVALID_REFRESH_TOKEN, distinct from the access token merely being
        // expired (which the refresh-and-retry-once path already handled correctly).
        _ = try? await client.fetchWeather(city: "Lisboa", units: .metric)

        // The onRefreshFailed hook fires a fire-and-forget `Task { @MainActor in ... }` of its
        // own, same as onTokensRefreshed -- give the scheduler a chance to actually run it.
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(
            authStore.isAuthenticated,
            "a definitively failed refresh (invalid/revoked refresh token) must log the user out"
        )
        XCTAssertNil(authStore.currentUser)
        XCTAssertNil(KeychainHelper.read(forKey: Self.tokenKey), "the dead access token must not remain in the Keychain")
        XCTAssertNil(KeychainHelper.read(forKey: Self.refreshTokenKey), "the dead refresh token must not remain in the Keychain")
    }
}
