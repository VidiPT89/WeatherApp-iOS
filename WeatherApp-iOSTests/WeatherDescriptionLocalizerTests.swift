import XCTest
@testable import WeatherApp_iOS

final class WeatherDescriptionLocalizerTests: XCTestCase {
    func test_translatesKnownOpenMeteoDescription_inPortuguese() {
        let result = WeatherDescriptionLocalizer.localized("Mainly clear", locale: Locale(identifier: "pt_PT"))
        XCTAssertEqual(result, "Praticamente limpo")
    }

    func test_isCaseInsensitiveOnTheRawDescription() {
        let result = WeatherDescriptionLocalizer.localized("OVERCAST", locale: Locale(identifier: "pt_PT"))
        XCTAssertEqual(result, "Nublado")
    }

    func test_fallsBackToCapitalizedEnglish_forUnmappedDescription_inPortuguese() {
        let result = WeatherDescriptionLocalizer.localized("some brand new provider phrase", locale: Locale(identifier: "pt_PT"))
        XCTAssertEqual(result, "Some Brand New Provider Phrase")
    }

    func test_returnsCapitalizedEnglish_forNonPortugueseLocale() {
        let result = WeatherDescriptionLocalizer.localized("mainly clear", locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result, "Mainly Clear")
    }
}
