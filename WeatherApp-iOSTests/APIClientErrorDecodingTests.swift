import XCTest
@testable import WeatherApp_iOS

final class APIClientErrorDecodingTests: XCTestCase {
    func test_throwsServerError_withBackendMessage_onNon2xxResponse() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "test-token", refresh: "test-refresh-token")

        let errorBody = """
        {
          "timestamp": "2024-01-01T12:00:00Z", "status": 404, "error": "Not Found",
          "message": "City not found", "path": "/api/v1/weather"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in (404, errorBody) }

        do {
            _ = try await client.fetchWeather(city: "Nonexistentville", units: .metric)
            XCTFail("Expected APIError.server to be thrown")
        } catch let error as APIError {
            guard case .server(let status, let message, let errorCode) = error else {
                XCTFail("Expected .server case, got \(error)")
                return
            }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(message, "City not found")
            XCTAssertNil(errorCode)
            XCTAssertEqual(error.errorDescription, "City not found")
        }
    }

    func test_throwsUnauthenticated_whenNoTokenIsSet() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        // No setTokens call — request must fail before hitting the network.

        MockURLProtocol.requestHandler = { _ in
            XCTFail("Should not perform network request without a token")
            return (200, Data())
        }

        do {
            _ = try await client.fetchWeather(city: "Lisboa", units: .metric)
            XCTFail("Expected APIError.unauthenticated to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthenticated)
        }
    }

    func test_decodesSuccessfulResponse() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "test-token", refresh: "test-refresh-token")

        let body = """
        {
          "city": "Lisboa", "country": "Portugal", "temperature": 24.3, "feelsLike": 25.1,
          "humidity": 60, "windSpeed": 12.4, "description": "clear sky", "units": "metric",
          "provider": "open-meteo", "observedAt": "2024-01-01T12:00:00Z", "fromCache": false
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in (200, body) }

        let weather = try await client.fetchWeather(city: "Lisboa", units: .metric)
        XCTAssertEqual(weather.city, "Lisboa")
        XCTAssertEqual(weather.provider, "open-meteo")
    }

    func test_unexpectedResponse_whenErrorBodyIsNotStandardShape() async throws {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "test-token", refresh: "test-refresh-token")

        MockURLProtocol.requestHandler = { _ in (500, "Internal Server Error".data(using: .utf8)!) }

        do {
            _ = try await client.fetchWeather(city: "Lisboa", units: .metric)
            XCTFail("Expected APIError.unexpectedResponse to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .unexpectedResponse(status: 500))
        }
    }
}
