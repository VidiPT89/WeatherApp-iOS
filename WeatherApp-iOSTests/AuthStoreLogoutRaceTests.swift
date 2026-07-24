import XCTest
@testable import WeatherApp_iOS

/// Reproduces the scenario from the code review: a token refresh that was in flight when the
/// user logged out landing afterward must not resurrect the cleared session. logout() and the
/// background refresh callback each fire an independent, unstructured Task with no ordering
/// guarantee between them -- this exercises the actual public login/logout/refresh surface
/// rather than reaching into AuthStore's private state, so it fails the same way a real race
/// would if the didLogOut guard regressed.
@MainActor
final class AuthStoreLogoutRaceTests: XCTestCase {

    private func authBody(token: String, refreshToken: String) -> Data {
        """
        {"token": "\(token)", "tokenType": "Bearer", "expiresInSeconds": 3600, "refreshToken": "\(refreshToken)"}
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

    private func weatherBody() -> Data {
        """
        {
          "city": "Lisboa", "country": "Portugal", "temperature": 24.3, "feelsLike": 25.1,
          "humidity": 60, "windSpeed": 12.4, "description": "clear sky", "units": "metric",
          "provider": "open-meteo", "observedAt": "2024-01-01T12:00:00Z", "fromCache": false
        }
        """.data(using: .utf8)!
    }

    func test_aRefreshThatCompletesAfterLogoutDoesNotResurrectTheSession() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        let loginBody = authBody(token: "first-access-token", refreshToken: "first-refresh-token")
        let refreshedBody = authBody(token: "resurrected-access-token", refreshToken: "resurrected-refresh-token")
        let weatherBody = weatherBody()
        let unauthenticatedBody = unauthenticatedBody()

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/v1/auth/login": return (200, loginBody)
            case "/api/v1/auth/logout": return (204, Data())
            case "/api/v1/auth/refresh": return (200, refreshedBody)
            case "/api/v1/weather":
                let usesOldToken = request.value(forHTTPHeaderField: "Authorization") == "Bearer first-access-token"
                return usesOldToken ? (401, unauthenticatedBody) : (200, weatherBody)
            default: return (200, Data())
            }
        }

        let authStore = AuthStore(apiClient: client)
        while authStore.isRestoringSession {
            await Task.yield()
        }

        try await authStore.login(email: "user@example.com", password: "password123")
        XCTAssertTrue(authStore.isAuthenticated)

        // Logout fully returns (its synchronous Keychain-clear + didLogOut=true already ran)
        // before the stray refresh below is even triggered.
        authStore.logout()
        XCTAssertFalse(authStore.isAuthenticated)

        // Let logout's own background cleanup Task (best-effort backend revoke + clearing
        // APIClient's in-memory tokens) fully settle before we deliberately re-arm the client
        // with the stale pair below -- otherwise that cleanup running late could itself wipe the
        // tokens we're about to set, independently of anything this test is trying to verify.
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Simulate a request that had already grabbed the pre-logout access token before logout
        // cleared it -- force the client back to the stale pair so the 401-refresh-retry cycle
        // below is deterministic.
        await client.setTokens(access: "first-access-token", refresh: "first-refresh-token")
        _ = try? await client.fetchWeather(city: "Lisboa", units: .metric)

        // onTokensRefreshed fires a fire-and-forget `Task { @MainActor in ... }` of its own --
        // fetchWeather returning is not itself proof that callback's Task has actually run yet.
        // Task.yield() only yields within the current cooperative pool and isn't reliable here;
        // a real (short) sleep actually gives the scheduler a chance to run the pending Task.
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(
            authStore.isAuthenticated,
            "a token refresh landing after logout must not silently resurrect the session"
        )
    }
}
