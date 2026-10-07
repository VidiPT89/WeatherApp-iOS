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

    private func captureScreens(locale: String, city: String) {
        app.launchArguments += ["-appLocale", locale, "-appTheme", "light"]
        app.launch()

        let search = app.textFields["dashboard.citySearch"]
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.tap()
        search.typeText(city + "\n")

        let marineCard = app.descendants(matching: .any)["dashboard.marineCard"].firstMatch
        XCTAssertTrue(marineCard.waitForExistence(timeout: timeout))
        // Let the forecast and insights finish loading after the current weather.
        sleep(8)
        shot("\(locale)-01-home")

        // The weather card is a single button labelled with the city name, which the backend
        // returns in English ("Lisbon") whatever the search language.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lisb")).firstMatch.tap()
        shotAndClose("\(locale)-02-now", close: "weatherDetail.close")

        app.swipeUp()
        sleep(1)
        shot("\(locale)-03-sea-forecast")

        marineCard.tap()
        shotAndClose("\(locale)-04-tides", close: "marineDetail.close")

        let chart = app.scrollViews["forecast.hourlyChart"]
        if chart.waitForExistence(timeout: 10) {
            chart.tap()
            shotAndClose("\(locale)-05-forecast", close: "forecastDetail.close")
        }

        app.swipeUp()
        sleep(1)
        let insights = app.descendants(matching: .any)["dashboard.insightsCard"].firstMatch
        if insights.waitForExistence(timeout: 10) {
            insights.tap()
            shotAndClose("\(locale)-06-insights", close: "insightsDetail.close")
        }

        app.tabBars.buttons.element(boundBy: 3).tap()
        sleep(2)
        shot("\(locale)-07-settings")
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
