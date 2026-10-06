import XCTest
@testable import WeatherApp_iOS

/// The in-app language toggle must win over the device language for strings built outside views.
final class LocalizedStringsTests: XCTestCase {
    func test_serverErrorFollowsTheRequestedLanguage() {
        let error = APIError.server(status: 404, message: "City not found", errorCode: "CITY_NOT_FOUND")

        XCTAssertEqual(error.localizedDescription(locale: Locale(identifier: "pt_PT")), "Não encontrámos essa cidade.")
        XCTAssertEqual(error.localizedDescription(locale: Locale(identifier: "en_US")), "We couldn't find that city.")
    }
}
