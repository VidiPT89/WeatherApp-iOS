import XCTest

/// Walks the main screens and attaches a screenshot of each, for the App Store listing.
/// Skipped unless the runner has STORE_SHOTS=1 (pass `TEST_RUNNER_STORE_SHOTS=1` to
/// xcodebuild), since it hits the live backend and is only needed when the listing changes.
/// Run it on an iPhone 17 Pro simulator: its 1206x2622 screenshots are the size App Store
/// Connect asks for. Export the PNGs with `xcrun xcresulttool export attachments`.
@MainActor
final class AppStoreScreenshotsUITests: XCTestCase {
    private let app = XCUIApplication()
    private let timeout: TimeInterval = 120

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] == "1", "Set STORE_SHOTS=1 to capture store screenshots")
        continueAfterFailure = true
    }

    func test_screenshots_english() throws {
        captureScreens(locale: "en", city: "Lisbon")
    }

    func test_screenshots_portuguese() throws {
        captureScreens(locale: "pt", city: "Lisboa")
    }

    /// The simulator should be placed near Cascais first
    /// (`xcrun simctl location <device> set 38.6979,-9.4215`), so Guincho tops the spot list.
    private func captureScreens(locale: String, city: String) {
        app.launchArguments += ["-appLocale", locale, "-appTheme", "light"]
        app.launch()
        addUIInterruptionMonitor(withDescription: "Location") { alert in
            alert.buttons.element(boundBy: 1).tap()
            return true
        }

        let spotList = app.descendants(matching: .any)["coast.spotList"].firstMatch
        XCTAssertTrue(spotList.waitForExistence(timeout: timeout))
        sleep(2)
        shot("\(locale)-01-coast")

        app.staticTexts["Guincho"].firstMatch.tap()
        let nowCard = app.descendants(matching: .any)["coast.nowCard"].firstMatch
        XCTAssertTrue(nowCard.waitForExistence(timeout: timeout))
        sleep(2)
        shot("\(locale)-02-spot")

        app.swipeUp()
        sleep(1)
        shot("\(locale)-03-tides")

        app.swipeUp()
        sleep(1)
        shot("\(locale)-04-hourly")

        app.tabBars.buttons.element(boundBy: 1).tap()
        let search = app.textFields["dashboard.citySearch"]
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.tap()
        search.typeText(city + "\n")
        let marineCard = app.descendants(matching: .any)["dashboard.marineCard"].firstMatch
        XCTAssertTrue(marineCard.waitForExistence(timeout: timeout))
        sleep(8)
        shot("\(locale)-05-weather")

        marineCard.tap()
        shotAndClose("\(locale)-06-sea", close: "marineDetail.close")
    }

    private func shotAndClose(_ name: String, close identifier: String) {
        let closeButton = app.buttons[identifier]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 15), "\(name): detail sheet did not open")
        sleep(2)
        shot(name)
        closeButton.tap()
        sleep(1)
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
