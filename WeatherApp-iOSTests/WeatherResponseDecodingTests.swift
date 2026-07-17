import XCTest
@testable import WeatherApp_iOS

final class WeatherResponseDecodingTests: XCTestCase {
    func test_decodesFreshPrimaryProviderResponse() throws {
        let json = """
        {
          "city": "Lisboa", "country": "Portugal", "temperature": 24.3, "feelsLike": 25.1,
          "humidity": 60, "windSpeed": 12.4, "description": "clear sky", "units": "metric",
          "provider": "open-meteo", "observedAt": "2024-01-01T12:00:00Z", "fromCache": false
        }
        """.data(using: .utf8)!

        let weather = try JSONDecoder().decode(WeatherResponse.self, from: json)

        XCTAssertEqual(weather.city, "Lisboa")
        XCTAssertEqual(weather.units, .metric)
        XCTAssertFalse(weather.fromCache)
        XCTAssertFalse(weather.isFallbackProvider)
    }

    func test_isFallbackProvider_whenProviderIsNotPrimary() throws {
        let json = """
        {
          "city": "Porto", "country": "Portugal", "temperature": 18.0, "feelsLike": 17.5,
          "humidity": 70, "windSpeed": 8.0, "description": "overcast clouds", "units": "metric",
          "provider": "open-weather-map", "observedAt": "2024-01-01T12:00:00Z", "fromCache": false
        }
        """.data(using: .utf8)!

        let weather = try JSONDecoder().decode(WeatherResponse.self, from: json)

        XCTAssertTrue(weather.isFallbackProvider)
    }

    func test_throws_whenObservedAtIsMalformed() {
        let json = """
        {
          "city": "Porto", "country": "Portugal", "temperature": 18.0, "feelsLike": 17.5,
          "humidity": 70, "windSpeed": 8.0, "description": "clear", "units": "metric",
          "provider": "open-meteo", "observedAt": "not-a-date", "fromCache": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(WeatherResponse.self, from: json))
    }
}
