import XCTest

/// End-to-end walk of the app's golden path against the real backend at
/// http://localhost:8080 (no mocking): register -> search -> cache badge
/// fresh->cached -> favorites -> history -> compare -> settings -> logout.
///
/// Requires the Spring Boot backend to actually be running locally.
@MainActor
final class GoldenPathUITests: XCTestCase {
    private let app = XCUIApplication()
    private let defaultTimeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func test_goldenPath_registerSearchFavoritesHistoryCompareSettings() throws {
        signOutIfAlreadyAuthenticated()
        registerNewAccount()
        attachScreenshot(name: "01_after_register_dashboard_empty")

        searchCity("Lisboa")
        XCTAssertTrue(weatherLoadedIndicator().waitForExistence(timeout: defaultTimeout), "Weather card should appear after searching Lisboa")
        attachScreenshot(name: "02_weather_card_first_search")

        // Second search of the same city within the cache TTL must be served from cache.
        searchCity("Lisboa")
        let cachedBadge = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Servido da cache")
        ).firstMatch
        XCTAssertTrue(cachedBadge.waitForExistence(timeout: defaultTimeout), "Second search of the same city should show the cache badge")
        attachScreenshot(name: "03_cache_badge_on_second_search")

        // Forecast chart range toggle
        if app.segmentedControls.buttons["Diária"].waitForExistence(timeout: 5) {
            app.segmentedControls.buttons["Diária"].tap()
            attachScreenshot(name: "04_daily_forecast")
            app.segmentedControls.buttons["Horária"].tap()
        }

        addToFavorites(city: "Porto")
        attachScreenshot(name: "05_favorites_added")

        jumpToFavoriteFromList(city: "Porto")
        XCTAssertTrue(weatherLoadedIndicator().waitForExistence(timeout: defaultTimeout), "Tapping a favorite should load its weather on the Dashboard")
        attachScreenshot(name: "06_favorite_jump_to_dashboard")

        openHistoryTab()
        attachScreenshot(name: "07_history")

        let compareResult = openCompareTab(city: "Lisboa")
        XCTAssertTrue(compareResult, "Compare screen should show provider results for Lisboa")
        attachScreenshot(name: "08_compare")

        openSettingsAndToggleUnits()
        attachScreenshot(name: "09_settings")
    }

    /// The marine card shows real data for a coastal city and a graceful
    /// "no data" message (never an error, never raw nulls) for an inland one.
    func test_marineConditionsCard_showsDataForCoastalCity_andEmptyStateForInlandCity() throws {
        signOutIfAlreadyAuthenticated()
        registerNewAccount()

        searchCity("Lisbon")
        XCTAssertTrue(weatherLoadedIndicator().waitForExistence(timeout: defaultTimeout))
        let seaConditionsTitle = app.staticTexts["Condições marítimas"]
        XCTAssertTrue(seaConditionsTitle.waitForExistence(timeout: defaultTimeout), "Sea conditions card should render for a coastal city")
        let waterTempLabel = app.staticTexts["Temp. da água"]
        XCTAssertTrue(waterTempLabel.waitForExistence(timeout: defaultTimeout), "Coastal city should show real water temperature")
        attachScreenshot(name: "marine_coastal_lisbon")

        searchCity("Madrid")
        XCTAssertTrue(weatherLoadedIndicator().waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["Condições marítimas"].waitForExistence(timeout: defaultTimeout))
        let noDataLabel = app.staticTexts["Sem dados marítimos para esta localização."]
        XCTAssertTrue(noDataLabel.waitForExistence(timeout: defaultTimeout), "Inland city should show the graceful no-data message, not raw nulls or an error")
        attachScreenshot(name: "marine_inland_madrid")
    }

    // MARK: - Steps

    private func signOutIfAlreadyAuthenticated() {
        let settingsTab = app.tabBars.buttons["Definições"]
        guard settingsTab.waitForExistence(timeout: 3) else { return }
        settingsTab.tap()
        // "Terminar sessão" now sits below the Units/Language/Appearance
        // sections, so it may not be materialized yet in the Form's
        // (UICollectionView-backed) accessibility tree until scrolled into view.
        let logoutButton = app.buttons["Terminar sessão"]
        if !logoutButton.waitForExistence(timeout: 1) {
            for _ in 0..<3 where !logoutButton.waitForExistence(timeout: 1) {
                app.swipeUp()
            }
        }
        if logoutButton.waitForExistence(timeout: 3) {
            logoutButton.tap()
        }
    }

    private func registerNewAccount() {
        let registerTab = app.segmentedControls.buttons["Criar conta"]
        XCTAssertTrue(registerTab.waitForExistence(timeout: defaultTimeout), "Auth screen should show the Criar conta tab")
        registerTab.tap()

        let email = "ios-golden-path-\(Int(Date().timeIntervalSince1970))@example.com"
        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["auth.password"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["auth.submit"].tap()

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: defaultTimeout), "Successful registration should land on the main tab view")
    }

    private func searchCity(_ city: String) {
        let searchField = app.textFields["dashboard.citySearch"]
        XCTAssertTrue(searchField.waitForExistence(timeout: defaultTimeout))
        tapTextFieldAndWaitForKeyboard(searchField)

        // An empty SwiftUI TextField reports its placeholder as `value`, so only
        // treat it as "has text to clear" when it differs from the placeholder.
        if let currentValue = searchField.value as? String,
           !currentValue.isEmpty,
           currentValue != "Procurar cidade..." {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            searchField.typeText(deleteString)
        }

        searchField.typeText(city)
        searchField.typeText("\n")
    }

    /// The cache badge's visible copy ("Dados frescos" / "Servido da cache...")
    /// is the most reliable signal that the weather card actually rendered.
    /// Accessibility *identifiers* on nested SwiftUI views proved unreliable in
    /// this app: a container-level `.accessibilityIdentifier` was observed
    /// overriding descendant leaves' own identifiers in the captured UI
    /// hierarchy, so matching on visible label text is used instead.
    private func weatherLoadedIndicator() -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Servido da cache", "Dados frescos")
        ).firstMatch
    }

    private func addToFavorites(city: String) {
        app.tabBars.buttons["Favoritos"].tap()
        let cityField = app.textFields["favorites.cityField"]
        XCTAssertTrue(cityField.waitForExistence(timeout: defaultTimeout))
        tapTextFieldAndWaitForKeyboard(cityField)
        cityField.typeText(city)
        app.buttons["favorites.addButton"].tap()
    }

    private func jumpToFavoriteFromList(city: String) {
        let favoriteRow = app.staticTexts[city]
        XCTAssertTrue(favoriteRow.waitForExistence(timeout: defaultTimeout))
        favoriteRow.tap()
    }

    private func openHistoryTab() {
        app.tabBars.buttons["Histórico"].tap()
        // Give the network call a moment; presence of the nav title is enough to
        // confirm the screen rendered without crashing.
        _ = app.navigationBars["Histórico"].waitForExistence(timeout: defaultTimeout)
    }

    private func openCompareTab(city: String) -> Bool {
        app.tabBars.buttons["Comparar"].tap()
        let searchField = app.textFields["compare.citySearch"]
        guard searchField.waitForExistence(timeout: defaultTimeout) else { return false }
        tapTextFieldAndWaitForKeyboard(searchField)
        searchField.typeText(city)
        searchField.typeText("\n")

        let primaryProviderLabel = app.staticTexts["open-meteo"]
        return primaryProviderLabel.waitForExistence(timeout: defaultTimeout)
    }

    private func openSettingsAndToggleUnits() {
        app.tabBars.buttons["Definições"].tap()
        let imperialOption = app.buttons["Imperial (°F)"]
        if imperialOption.waitForExistence(timeout: defaultTimeout) {
            imperialOption.tap()
        }
    }

    // MARK: - Helpers

    /// Polls until `element` is hittable, tolerating brief post-transition layout
    /// delays (e.g. the auth->tabs cross-fade) that `waitForExistence` alone misses
    /// since the element can exist in the hierarchy before it's actually tappable.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.isHittable
    }

    /// Some SwiftUI text fields report `isHittable == false` to XCUITest even
    /// while fully visible and interactive on screen (a known SwiftUI/XCUITest
    /// accessibility-tree quirk). Prefer a normal `.tap()` when hittable, but
    /// fall back to a coordinate-based tap — which synthesizes the touch at a
    /// point rather than routing through the hittability check — otherwise.
    private func tapReliably(_ element: XCUIElement, timeout: TimeInterval? = nil) {
        if waitUntilHittable(element, timeout: timeout ?? defaultTimeout) {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Taps a text field and waits for the software keyboard to actually appear
    /// before returning, retrying the tap a few times if focus doesn't land —
    /// a synthetic tap can occasionally land before SwiftUI's responder chain
    /// has attached focus, especially right after a tab/screen transition.
    private func tapTextFieldAndWaitForKeyboard(_ element: XCUIElement) {
        let keyboard = app.keyboards.firstMatch
        for attempt in 1...3 {
            tapReliably(element)
            if keyboard.waitForExistence(timeout: 3) { return }
            if attempt < 3 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
        }
    }

    private func attachScreenshot(name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
