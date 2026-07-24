import XCTest
@testable import WeatherApp_iOS

final class NumberFormattingTests: XCTestCase {
    func test_roundsUpToTheNearestWhole() {
        XCTAssertEqual(NumberFormatting.roundedWhole(23.9), "24")
    }

    func test_roundsDownToTheNearestWhole() {
        XCTAssertEqual(NumberFormatting.roundedWhole(23.4), "23")
    }

    func test_handlesNegativeValues() {
        XCTAssertEqual(NumberFormatting.roundedWhole(-2.6), "-3")
    }
}
