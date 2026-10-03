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
        {"time": "2024-01-01T00:00:00", "temperature": 15.2, "description": "clear sky", "precipitationProbability": 10},
        {"time": "2024-01-01T01:00:00", "temperature": 14.8, "description": "clear sky", "precipitationProbability": 5}
      ],
      "daily": [
        {"date": "2024-01-01", "temperatureMax": 22.0, "temperatureMin": 12.0, "description": "clear sky",
         "sunrise": "2024-01-01T07:45:00", "sunset": "2024-01-01T17:30:00", "uvIndexMax": 3.5, "precipitationProbabilityMax": 20,
         "windSpeedMax": 12.0, "rainLikely": false, "uvRiskLabel": "Moderate", "outdoorActivityLabel": "Good"},
        {"date": "2024-01-02", "temperatureMax": 20.5, "temperatureMin": 11.0, "description": "few clouds",
         "sunrise": "2024-01-02T07:45:00", "sunset": "2024-01-02T17:31:00", "uvIndexMax": 3.8, "precipitationProbabilityMax": 30,
         "windSpeedMax": 14.0, "rainLikely": false, "uvRiskLabel": "Moderate", "outdoorActivityLabel": "Good"}
      ]
    }
    """.data(using: .utf8)!

    func test_decodesHourlyLocalDateTimeWithoutTimezone() throws {
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: fixture)

        XCTAssertEqual(forecast.hourly.count, 2)

        // The city's wall-clock, kept as the same numbers on the device's calendar so views
        // format it back unchanged.
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: forecast.hourly[0].time)
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

    func test_decodesUtcOffset_andToleratesItsAbsence() throws {
        XCTAssertNil(try JSONDecoder().decode(ForecastResponse.self, from: fixture).utcOffsetSeconds)

        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: tokyoFixture)
        XCTAssertEqual(forecast.utcOffsetSeconds, 9 * 3600)
    }

    func test_isNight_usesTheCitysOwnClock_notTheDevicesOrUTC() throws {
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: tokyoFixture)

        // 03:00 UTC is noon in Tokyo (UTC+9): daytime there, whatever zone the device is in.
        XCTAssertFalse(forecast.isNight(at: try XCTUnwrap(BackendDateFormatters.parseInstant("2026-10-03T03:00:00Z"))))
        // 12:00 UTC is 21:00 in Tokyo: already night there.
        XCTAssertTrue(forecast.isNight(at: try XCTUnwrap(BackendDateFormatters.parseInstant("2026-10-03T12:00:00Z"))))
    }

    func test_decodesALocalTimeThatTheDevicesZoneSkips() {
        // 01:30 on Lisbon's spring-forward day doesn't exist on a Lisbon device, but it's a
        // perfectly real hour in the city the forecast is for -- it must not fail the decode.
        XCTAssertNotNil(BackendDateFormatters.parseLocalDateTime("2026-03-29T01:30:00"))
    }

    private let tokyoFixture = """
    {
      "city": "Tokyo", "country": "Japan", "units": "metric", "provider": "open-meteo", "fromCache": false,
      "utcOffsetSeconds": 32400,
      "hourly": [],
      "daily": [
        {"date": "2026-10-03", "temperatureMax": 24.0, "temperatureMin": 17.0, "description": "clear sky",
         "sunrise": "2026-10-03T05:35:00", "sunset": "2026-10-03T17:25:00", "uvIndexMax": 5.0, "precipitationProbabilityMax": 0,
         "windSpeedMax": 10.0, "rainLikely": false, "uvRiskLabel": "Moderate", "outdoorActivityLabel": "Good"}
      ]
    }
    """.data(using: .utf8)!
}
