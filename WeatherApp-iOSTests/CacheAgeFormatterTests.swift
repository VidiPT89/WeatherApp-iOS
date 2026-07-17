import XCTest
@testable import WeatherApp_iOS

final class CacheAgeFormatterTests: XCTestCase {
    func test_formatsSecondsUnderAMinute() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let now = observedAt.addingTimeInterval(45)

        XCTAssertEqual(CacheAgeFormatter.formattedAge(observedAt: observedAt, now: now), "45s")
    }

    func test_formatsMinutesUnderAnHour() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let now = observedAt.addingTimeInterval(60 * 12)

        XCTAssertEqual(CacheAgeFormatter.formattedAge(observedAt: observedAt, now: now), "12min")
    }

    func test_formatsHoursBeyondAnHour() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let now = observedAt.addingTimeInterval(3600 * 3)

        XCTAssertEqual(CacheAgeFormatter.formattedAge(observedAt: observedAt, now: now), "3h")
    }

    func test_clampsNegativeAgeToZero() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let now = observedAt.addingTimeInterval(-30) // clock skew / observedAt in the future

        XCTAssertEqual(CacheAgeFormatter.formattedAge(observedAt: observedAt, now: now), "0s")
    }
}
