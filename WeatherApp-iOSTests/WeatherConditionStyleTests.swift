import XCTest
@testable import WeatherApp_iOS

final class WeatherConditionStyleTests: XCTestCase {
    func test_matchesRainKeyword_caseInsensitive() {
        let style = WeatherConditionStyle.style(for: "Light RAIN showers")
        XCTAssertEqual(style.symbolName, "cloud.rain.fill")
    }

    func test_matchesCloudKeyword_asSubstring() {
        let style = WeatherConditionStyle.style(for: "overcast clouds")
        XCTAssertEqual(style.symbolName, "cloud.fill")
    }

    func test_fallsBackToNeutral_forUnrecognizedDescription() {
        let style = WeatherConditionStyle.style(for: "some unknown condition")
        XCTAssertEqual(style.symbolName, "cloud.sun.fill")
    }

    func test_matchesThunderstormBeforeCloud_whenBothKeywordsPresent() {
        // "thunderstorm" contains no "cloud" substring, but real descriptions like
        // "thunderstorm with heavy clouds" could match both rules — thunderstorm
        // must win since it's checked first (more severe condition).
        let style = WeatherConditionStyle.style(for: "thunderstorm with heavy clouds")
        XCTAssertEqual(style.symbolName, "cloud.bolt.fill")
    }
}
