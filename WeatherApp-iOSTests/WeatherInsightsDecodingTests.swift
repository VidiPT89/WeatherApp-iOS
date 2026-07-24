import XCTest
@testable import WeatherApp_iOS

final class WeatherInsightsDecodingTests: XCTestCase {
    func test_decodesMarineResponseWithTideEvents() throws {
        let json = """
        {
          "city": "Cascais", "country": "Portugal", "units": "metric", "provider": "open-meteo",
          "fromCache": false, "waterTemperature": 20.2, "waveHeightMeters": 0.86,
          "waveDirectionDegrees": 306.0, "wavePeriodSeconds": 5.55,
          "tideEvents": [
            {"type": "low", "time": "2026-07-24T05:00"},
            {"type": "high", "time": "2026-07-24T11:00"}
          ]
        }
        """.data(using: .utf8)!

        let marine = try JSONDecoder().decode(MarineResponse.self, from: json)

        XCTAssertEqual(marine.tideEvents.count, 2)
        XCTAssertEqual(marine.tideEvents[0].type, "low")
        XCTAssertFalse(marine.tideEvents[0].isHigh)
        XCTAssertTrue(marine.tideEvents[1].isHigh)
    }

    func test_decodesMarineResponse_withEmptyTideEvents_forInlandCity() throws {
        let json = """
        {
          "city": "Madrid", "country": "Spain", "units": "metric", "provider": "open-meteo",
          "fromCache": false, "waterTemperature": null, "waveHeightMeters": null,
          "waveDirectionDegrees": null, "wavePeriodSeconds": null, "tideEvents": []
        }
        """.data(using: .utf8)!

        let marine = try JSONDecoder().decode(MarineResponse.self, from: json)

        XCTAssertFalse(marine.hasData)
        XCTAssertTrue(marine.tideEvents.isEmpty)
    }

    func test_decodesWeatherInsightsResponse_withFishingCondition() throws {
        let json = """
        {
          "city": "Cascais", "country": "Portugal",
          "moonPhase": {"phase": "Waxing Gibbous", "illuminationPercent": 76},
          "uvRiskLabel": "High", "outdoorActivityScore": 88, "outdoorActivityLabel": "Great",
          "fishingConditionLabel": "Fair"
        }
        """.data(using: .utf8)!

        let insights = try JSONDecoder().decode(WeatherInsightsResponse.self, from: json)

        XCTAssertEqual(insights.moonPhase.phase, "Waxing Gibbous")
        XCTAssertEqual(insights.moonPhase.illuminationPercent, 76)
        XCTAssertEqual(insights.uvRiskLabel, "High")
        XCTAssertEqual(insights.outdoorActivityScore, 88)
        XCTAssertEqual(insights.fishingConditionLabel, "Fair")
    }

    func test_decodesWeatherInsightsResponse_withNilFishingCondition_forInlandCity() throws {
        let json = """
        {
          "city": "Madrid", "country": "Spain",
          "moonPhase": {"phase": "Waxing Gibbous", "illuminationPercent": 76},
          "uvRiskLabel": "Very High", "outdoorActivityScore": 73, "outdoorActivityLabel": "Good",
          "fishingConditionLabel": null
        }
        """.data(using: .utf8)!

        let insights = try JSONDecoder().decode(WeatherInsightsResponse.self, from: json)

        XCTAssertNil(insights.fishingConditionLabel)
    }
}
