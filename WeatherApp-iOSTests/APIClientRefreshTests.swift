import XCTest
@testable import WeatherApp_iOS

final class APIClientRefreshTests: XCTestCase {
    private func weatherBody() -> Data {
        """
        {
          "city": "Lisboa", "country": "Portugal", "temperature": 24.3, "feelsLike": 25.1,
          "humidity": 60, "windSpeed": 12.4, "description": "clear sky", "units": "metric",
          "provider": "open-meteo", "observedAt": "2024-01-01T12:00:00Z", "fromCache": false
        }
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

    private func refreshedAuthBody() -> Data {
        """
        {"token": "new-access-token", "tokenType": "Bearer", "expiresInSeconds": 3600, "refreshToken": "new-refresh-token"}
        """.data(using: .utf8)!
    }

    func test_refreshesAndRetriesOnce_whenAnExpiredAccessTokenIsRejected() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "expired-access-token", refresh: "valid-refresh-token")

        let refreshedTokens = Box<AuthResponse>()
        await client.setOnTokensRefreshed { refreshedTokens.value = $0 }

        let callCount = Counter()
        let weatherBody = weatherBody()
        let unauthenticatedBody = unauthenticatedBody()
        let refreshedAuthBody = refreshedAuthBody()
        MockURLProtocol.requestHandler = { request in
            let call = callCount.incrementAndGet()
            if request.url?.path == "/api/v1/auth/refresh" {
                return (200, refreshedAuthBody)
            }
            // First weather call fails as expired; the retry (after refresh) succeeds.
            return call == 1 ? (401, unauthenticatedBody) : (200, weatherBody)
        }

        let weather = try await client.fetchWeather(city: "Lisboa", units: .metric)

        XCTAssertEqual(weather.city, "Lisboa")
        XCTAssertEqual(callCount.value, 3) // original weather call, refresh call, retried weather call
        XCTAssertEqual(refreshedTokens.value?.token, "new-access-token")
        XCTAssertEqual(refreshedTokens.value?.refreshToken, "new-refresh-token")
    }

    func test_propagatesTheOriginalError_whenTheRefreshTokenItselfIsInvalid() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "expired-access-token", refresh: "revoked-refresh-token")

        let unauthenticatedBody = unauthenticatedBody()
        let invalidRefreshTokenBody = invalidRefreshTokenBody()
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/v1/auth/refresh" {
                return (401, invalidRefreshTokenBody)
            }
            return (401, unauthenticatedBody)
        }

        do {
            _ = try await client.fetchWeather(city: "Lisboa", units: .metric)
            XCTFail("Expected the original UNAUTHENTICATED error to propagate")
        } catch let error as APIError {
            guard case .server(let status, _, let errorCode) = error else {
                XCTFail("Expected .server case, got \(error)")
                return
            }
            XCTAssertEqual(status, 401)
            XCTAssertEqual(errorCode, "UNAUTHENTICATED")
        }
    }

    func test_concurrentRequestsShareASingleRefreshCall() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "expired-access-token", refresh: "valid-refresh-token")

        let refreshCallCount = Counter()
        let weatherBody = weatherBody()
        let unauthenticatedBody = unauthenticatedBody()
        let refreshedAuthBody = refreshedAuthBody()
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/v1/auth/refresh" {
                refreshCallCount.incrementAndGet()
                return (200, refreshedAuthBody)
            }
            let hasNewToken = request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access-token"
            return hasNewToken ? (200, weatherBody) : (401, unauthenticatedBody)
        }

        async let first = client.fetchWeather(city: "Lisboa", units: .metric)
        async let second = client.fetchWeather(city: "Porto", units: .metric)
        _ = try await (first, second)

        XCTAssertEqual(refreshCallCount.value, 1)
    }
}

/// Thread-safe call counter for asserting call counts from the `@Sendable`
/// `MockURLProtocol.requestHandler` closure, which may run concurrently across tasks.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    @discardableResult
    func incrementAndGet() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
        return _value
    }
}

/// Thread-safe single-value box for capturing a result from the `@Sendable` `requestHandler`
/// or `onTokensRefreshed` callback into a test's assertions.
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T?
    var value: T? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}
