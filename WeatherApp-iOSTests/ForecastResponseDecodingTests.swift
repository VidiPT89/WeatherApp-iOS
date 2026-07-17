import XCTest
@testable import WeatherApp_iOS

/// Fixture-based decoding tests for the forecast's zone-less local
/// datetimes, which must NOT be parsed with `.iso8601` (it requires an
/// offset/`Z` and would throw on `hourly[].time`/`daily[].date`).
final class ForecastResponseDecodingTests: XCTestCase {
    private let fixture = """
    {
      "city": "Lisboa", "country": "Portugal", "units": "metric", "provider": "open-meteo", "fromCache": false,
      "hourly": [
        {"time": "2024-01-01T00:00:00", "temperature": 15.2, "description": "clear sky"},
        {"time": "2024-01-01T01:00:00", "temperature": 14.8, "description": "clear sky"}
      ],
      "daily": [
        {"date": "2024-01-01", "temperatureMax": 22.0, "temperatureMin": 12.0, "description": "clear sky"},
        {"date": "2024-01-02", "temperatureMax": 20.5, "temperatureMin": 11.0, "description": "few clouds"}
      ]
    }
    """.data(using: .utf8)!

    func test_decodesHourlyLocalDateTimeWithoutTimezone() throws {
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: fixture)

        XCTAssertEqual(forecast.hourly.count, 2)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: forecast.hourly[0].time)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
    }

    func test_decodesDailyLocalDateWithoutTimezone() throws {
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: fixture)

        XCTAssertEqual(forecast.daily.count, 2)
        XCTAssertEqual(forecast.daily[0].temperatureMax, 22.0)
        XCTAssertEqual(forecast.daily[1].temperatureMin, 11.0)
    }

    func test_throws_onMalformedLocalDateTime() {
        let badJSON = """
        {
          "city": "Lisboa", "country": "Portugal", "units": "metric", "provider": "open-meteo", "fromCache": false,
          "hourly": [{"time": "not-a-datetime", "temperature": 15.2, "description": "clear sky"}],
          "daily": []
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(ForecastResponse.self, from: badJSON))
    }
}
