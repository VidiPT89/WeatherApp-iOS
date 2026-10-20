import XCTest
@testable import WeatherApp_iOS

final class CoastOutlookTests: XCTestCase {
    /// Trimmed from a real `/api/v1/coast/outlook?spot=guincho` response.
    private let json = """
    {
      "spot": {"id": "guincho", "name": "Guincho", "area": "Cascais", "latitude": 38.731,
               "longitude": -9.476, "facingDegrees": 275, "distanceKm": null},
      "units": "metric", "provider": "open-meteo", "fromCache": false, "utcOffsetSeconds": 3600,
      "hours": [
        {"time": "2026-10-20T09:00:00", "waveHeightMeters": 1.62, "wavePeriodSeconds": 11.2,
         "waveDirectionDegrees": 300.0, "swellHeightMeters": 1.5, "swellPeriodSeconds": 12.4,
         "swellDirectionDegrees": 298.0, "windSpeed": 9.0, "windGusts": 16.0,
         "windDirectionDegrees": 80.0, "windExposure": "offshore", "seaLevelMeters": 0.1,
         "waterTemperature": 17.4, "airTemperature": 18.0, "precipitationProbability": 0,
         "surfScore": 10, "fishingScore": 5, "beachScore": 6},
        {"time": "2026-10-20T10:00:00", "waveHeightMeters": 1.6, "wavePeriodSeconds": null,
         "waveDirectionDegrees": null, "swellHeightMeters": null, "swellPeriodSeconds": null,
         "swellDirectionDegrees": null, "windSpeed": null, "windGusts": null,
         "windDirectionDegrees": null, "windExposure": null, "seaLevelMeters": 0.22,
         "waterTemperature": null, "airTemperature": null, "precipitationProbability": null,
         "surfScore": null, "fishingScore": null, "beachScore": null}
      ],
      "tideEvents": [
        {"type": "high", "time": "2026-10-20T10:00"},
        {"type": "low", "time": "2026-10-20T17:00"},
        {"type": "high", "time": "2026-10-21T11:00"}
      ],
      "days": [
        {"date": "2026-10-20", "sunrise": "2026-10-20T07:51:00", "sunset": "2026-10-20T18:44:00",
         "surf": {"start": "2026-10-20T09:00:00", "end": "2026-10-20T12:00:00", "score": 9,
                  "reasons": ["SWELL_SOLID", "WIND_OFFSHORE"]},
         "fishing": null, "beach": null}
      ]
    }
    """.data(using: .utf8)!

    private func wallClock(_ text: String) -> Date {
        BackendDateFormatters.parseLocalDateTime(text)!
    }

    func test_decodesTheOutlook_includingNullReadingsAndWindows() throws {
        let outlook = try JSONDecoder().decode(CoastOutlookResponse.self, from: json)

        XCTAssertEqual(outlook.spot.facingDegrees, 275)
        XCTAssertEqual(outlook.hours.count, 2)
        XCTAssertEqual(outlook.hours[0].windExposure, "offshore")
        XCTAssertEqual(outlook.hours[0].score(for: .surf), 10)
        XCTAssertNil(outlook.hours[1].swellHeightMeters)
        XCTAssertNil(outlook.hours[1].score(for: .beach))

        let day = try XCTUnwrap(outlook.days.first)
        XCTAssertEqual(day.window(for: .surf)?.score, 9)
        XCTAssertEqual(day.window(for: .surf)?.start, wallClock("2026-10-20T09:00:00"))
        XCTAssertEqual(day.window(for: .surf)?.reasons, ["SWELL_SOLID", "WIND_OFFSHORE"])
        XCTAssertNil(day.window(for: .fishing))
    }

    func test_findsTheCurrentHourAndTheNextTide() throws {
        let outlook = try JSONDecoder().decode(CoastOutlookResponse.self, from: json)
        let now = wallClock("2026-10-20T09:30:00")

        XCTAssertEqual(outlook.currentHour(now: now)?.time, wallClock("2026-10-20T09:00:00"))
        let next = try XCTUnwrap(outlook.nextTide(after: now))
        XCTAssertTrue(next.isHigh)
        XCTAssertEqual(next.time, wallClock("2026-10-20T10:00:00"))
    }

    func test_listsOnlyTheChosenDaysTides() throws {
        let outlook = try JSONDecoder().decode(CoastOutlookResponse.self, from: json)

        let tides = outlook.tides(on: wallClock("2026-10-20T00:00:00"))

        XCTAssertEqual(tides.map(\.isHigh), [true, false])
    }

    func test_parsesTideTimesWithoutSeconds() {
        XCTAssertEqual(
            BackendDateFormatters.parseLocalDateTime("2026-10-20T10:00"),
            BackendDateFormatters.parseLocalDateTime("2026-10-20T10:00:00"))
    }

    func test_formatsWaveHeightInTheChosenUnits() {
        XCTAssertTrue(CoastLabels.waveHeight(1.5, units: .imperial).hasSuffix("5 ft"))
        XCTAssertTrue(CoastLabels.waveHeight(1.5, units: .metric).hasSuffix(" m"))
    }
}

@MainActor
final class CoastSpotsViewModelTests: XCTestCase {
    func test_favoritesArePersistedAndToggled() {
        let defaults = UserDefaults(suiteName: "CoastSpotsViewModelTests")!
        defaults.removePersistentDomain(forName: "CoastSpotsViewModelTests")
        let spot = CoastSpot(id: "guincho", name: "Guincho", area: "Cascais", latitude: 38.7, longitude: -9.4,
                             facingDegrees: 275, distanceKm: nil)

        let viewModel = CoastSpotsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.isFavorite(spot))
        viewModel.toggleFavorite(spot)
        XCTAssertTrue(viewModel.isFavorite(spot))

        let reloaded = CoastSpotsViewModel(defaults: defaults)
        XCTAssertTrue(reloaded.isFavorite(spot))
        reloaded.toggleFavorite(spot)
        XCTAssertFalse(reloaded.isFavorite(spot))
        XCTAssertEqual(defaults.stringArray(forKey: CoastSpotsViewModel.favoritesKey), [])
    }
}
