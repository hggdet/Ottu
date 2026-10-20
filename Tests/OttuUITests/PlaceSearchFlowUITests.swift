import XCTest

@MainActor
final class PlaceSearchFlowUITests: XCTestCase {
    func testFullWidthSearchButtonOpensAndReopensArabicSearchField() {
        verifySearchInteraction(language: "ar", locale: "ar_IQ")
    }

    func testFullWidthSearchButtonOpensAndReopensEnglishSearchField() {
        verifySearchInteraction(language: "en", locale: "en_US")
    }

    func testSearchSelectionDismissesKeyboardInArabicAndEnglish() {
        verifySearchSelection(language: "ar", locale: "ar_IQ")
        verifySearchSelection(language: "en", locale: "en_US")
    }

    func testSearchDismissesBeforeAssistantSheetInArabicAndEnglish() {
        verifyAssistantSheetTransition(language: "ar", locale: "ar_IQ")
        verifyAssistantSheetTransition(language: "en", locale: "en_US")
    }

    func testWeatherPopoverDoesNotOpenSearchInArabicAndEnglish() {
        verifyWeatherPopoverIndependence(language: "ar", locale: "ar_IQ")
        verifyWeatherPopoverIndependence(language: "en", locale: "en_US")
    }

    private func verifyWeatherPopoverIndependence(language: String, locale: String) {
        continueAfterFailure = false
        let app = launchMap(
            language: language,
            locale: locale,
            extraArguments: ["-ottuUITestWeatherPopoverFixture"]
        )
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        let weatherButton = app.buttons["mapWeatherButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15))
        XCTAssertTrue(weatherButton.waitForExistence(timeout: 5))
        XCTAssertTrue(weatherButton.isHittable)
        assertClosedSearchGeometry(in: app)
        let overlap = searchButton.frame.intersection(weatherButton.frame)
        XCTAssertTrue(overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001,
                      "Search and weather must have independent, non-overlapping touch areas in both layout directions.")
        XCTAssertFalse(app.textFields["placeSearchField"].exists)
        weatherButton.tap()

        let popover = app.descendants(matching: .any)["mapWeatherPopover"]
        XCTAssertTrue(popover.waitForExistence(timeout: 5), "Weather must present its own popover without opening search.")
        XCTAssertTrue(app.descendants(matching: .any)["mapWeatherLoadingState"].waitForExistence(timeout: 5),
                      "The DEBUG fixture must expose the popover without a network response.")
        XCTAssertFalse(app.textFields["placeSearchField"].exists, "Tapping weather must not activate the search field.")
        XCTAssertFalse(app.descendants(matching: .any)["placeSearchResultsPanel"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Tapping weather must not present the search keyboard.")
    }

    private func verifySearchInteraction(language: String, locale: String) {
        continueAfterFailure = false
        // Accessibility frames can report 44pt as 43.99999999999997.
        let hitTargetTolerance: CGFloat = 0.001
        let app = launchMap(language: language, locale: locale)
        defer { app.terminate() }

        assertCategoryUIAbsent(in: app)
        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15), "The full-width place-search control should be present on the map.")
        XCTAssertTrue(searchButton.isHittable, "The full-width place-search control should receive physical taps.")
        assertClosedSearchGeometry(in: app)
        XCTAssertGreaterThanOrEqual(searchButton.frame.height, 44 - hitTargetTolerance)
        searchButton.tap()

        let searchField = app.textFields["placeSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Tapping the closed search capsule must reveal the actual text field.")
        XCTAssertTrue(searchField.isHittable)
        XCTAssertTrue(searchButton.waitForNonExistence(timeout: 5), "The closed-state search button must not remain after opening.")
        assertOpenSearchGeometry(in: app, minimumHeight: 44 - hitTargetTolerance)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Opening search must focus the field and show the keyboard without another tap.")
        assertCategoryUIAbsent(in: app)
        searchField.typeText("Baghdad")
        XCTAssertEqual(searchField.value as? String, "Baghdad", "The field must accept text, not only appear visually.")
        assertOpenSearchGeometry(in: app, minimumHeight: 44 - hitTargetTolerance)
        assertCompactResultsPanelIfPresent(in: app)
        assertCategoryUIAbsent(in: app)

        let closeButton = app.buttons["placeSearchClose"]
        XCTAssertTrue(closeButton.isHittable)
        XCTAssertGreaterThanOrEqual(closeButton.frame.width, 44 - hitTargetTolerance)
        XCTAssertGreaterThanOrEqual(closeButton.frame.height, 44 - hitTargetTolerance)
        // Tap the padded area, not the xmark glyph: the whole 44pt control
        // must close search, including when the keyboard is showing.
        closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Close must remove the actual field, not just hide the keyboard.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        XCTAssertTrue(searchButton.isHittable)
        assertClosedSearchGeometry(in: app)
        XCTAssertGreaterThanOrEqual(searchButton.frame.height, 44 - hitTargetTolerance)
        assertCategoryUIAbsent(in: app)
        searchButton.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "A second physical tap must reopen search after closing it.")
        XCTAssertTrue(searchField.isHittable)
        assertOpenSearchGeometry(in: app, minimumHeight: 44 - hitTargetTolerance)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertNotEqual(searchField.value as? String, "Baghdad", "Closing search must clear the previous query.")
        assertCategoryUIAbsent(in: app)
        searchField.typeText("Basra")
        XCTAssertEqual(searchField.value as? String, "Basra", "The reopened field must accept a fresh query.")
        assertOpenSearchGeometry(in: app, minimumHeight: 44 - hitTargetTolerance)
        assertCompactResultsPanelIfPresent(in: app)
        assertCategoryUIAbsent(in: app)

        let clearButton = app.buttons["placeSearchClear"]
        XCTAssertTrue(clearButton.isHittable)
        XCTAssertGreaterThanOrEqual(clearButton.frame.width, 44 - hitTargetTolerance)
        XCTAssertGreaterThanOrEqual(clearButton.frame.height, 44 - hitTargetTolerance)
        clearButton.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(clearButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(searchField.exists, "Clear must keep search open.")
        XCTAssertNotEqual(searchField.value as? String, "Basra")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Clear must retain input focus.")
        assertCategoryUIAbsent(in: app)
        searchField.typeText("Erbil")
        XCTAssertEqual(searchField.value as? String, "Erbil")
        assertCompactResultsPanelIfPresent(in: app)
        closeButton.tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Close must also work after clearing and typing again.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        assertCategoryUIAbsent(in: app)
    }

    private func verifySearchSelection(language: String, locale: String) {
        continueAfterFailure = false
        let app = launchMap(
            language: language,
            locale: locale,
            extraArguments: ["-ottuUITestSearchSelectionFixture"]
        )
        defer { app.terminate() }

        assertCategoryUIAbsent(in: app)
        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15))
        assertClosedSearchGeometry(in: app)
        searchButton.tap()
        let searchField = app.textFields["placeSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertOpenSearchGeometry(in: app, minimumHeight: 44 - 0.001)
        assertCompactResultsPanelIfPresent(in: app)
        assertCategoryUIAbsent(in: app)

        let fixturePlace = app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@", "UI Test Selection Place"
        )).firstMatch
        XCTAssertTrue(fixturePlace.waitForExistence(timeout: 5), "The DEBUG fixture should supply a local, network-independent selectable place.")
        fixturePlace.tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Selecting a place must remove the focused search field.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Selecting a place must dismiss the keyboard.")
        let displayedPlace = app.descendants(matching: .any)[
            "selectedPlaceBottomSheet.ottu-ui-test-search-selection"
        ]
        XCTAssertTrue(displayedPlace.waitForExistence(timeout: 5), "Selecting a result must focus and display that place on the map.")
        XCTAssertTrue(app.staticTexts["UI Test Selection Place"].exists, "The displayed place sheet must show the selected fixture place.")
        assertCategoryUIAbsent(in: app)
    }

    private func verifyAssistantSheetTransition(language: String, locale: String) {
        continueAfterFailure = false
        let app = launchMap(language: language, locale: locale)
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15))
        searchButton.tap()
        let searchField = app.textFields["placeSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertCategoryUIAbsent(in: app)

        app.buttons["mapTab.assistant"].tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Opening assistant must close map search.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Opening assistant must dismiss the search keyboard.")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5), "The assistant sheet should be presented.")
    }

    private func assertClosedSearchGeometry(in app: XCUIApplication) {
        let control = app.descendants(matching: .any)["placeSearchClosedControl"]
        XCTAssertTrue(control.exists, "The closed full-width bar should expose a container with independent search and weather buttons.")
        XCTAssertGreaterThanOrEqual(control.frame.width, app.frame.width * 0.8, "The shared search bar must remain full width.")
        XCTAssertGreaterThanOrEqual(control.frame.height, 44 - 0.001)
        XCTAssertGreaterThanOrEqual(app.buttons["placeSearchButton"].frame.width, 44 - 0.001)
        XCTAssertGreaterThanOrEqual(app.buttons["placeSearchButton"].frame.width, app.frame.width * 0.7, "The search hit area itself must keep most of the shared bar width.")
    }

    private func assertOpenSearchGeometry(in app: XCUIApplication, minimumHeight: CGFloat) {
        let control = app.descendants(matching: .any)["placeSearchControl"]
        XCTAssertTrue(control.exists, "The open search controls should expose their shared container.")
        XCTAssertGreaterThanOrEqual(control.frame.width, app.frame.width * 0.8, "Open search should span at least 80% of the viewport.")
        XCTAssertGreaterThanOrEqual(control.frame.height, minimumHeight, "Open search must retain a minimum 44pt touch target.")
    }

    private func assertCompactResultsPanelIfPresent(in app: XCUIApplication) {
        let panel = app.descendants(matching: .any)["placeSearchResultsPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Focused search should show its single suggestions/results panel.")
        let maximumHeight = min(300, app.frame.height * 0.35)
        XCTAssertLessThanOrEqual(panel.frame.height, maximumHeight + 1, "The single search suggestions/results panel must stay compact.")
    }

    private func assertCategoryUIAbsent(in app: XCUIApplication) {
        XCTAssertFalse(app.buttons["mapTab.categories"].exists, "The categories navigation tab must be removed.")
        let quickCategoryButtons = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "mapQuickCategory."
        ))
        XCTAssertEqual(quickCategoryButtons.count, 0, "Map search must not expose quick-category chips.")
        XCTAssertFalse(app.descendants(matching: .any)["mapCategoryResultsPanel"].exists, "The separate category results panel must be removed.")
    }

    private func launchMap(
        language: String,
        locale: String,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = [
            "-ottu.welcomeMotionCompleted", "YES",
            "-ottu.initialSetupCompleted", "YES",
            "-ottu.locationExplanationDismissed", "NO",
            "-ottu.language", language,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ] + extraArguments
        app.launch()

        // Resolve the real system prompt before interaction. XCTest's default
        // interruption handler can otherwise leave permission guidance on top.
        let locationAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(locationAlert.waitForExistence(timeout: 15), "Resetting location authorization must produce the system prompt.")
        let allowLocation = locationAlert.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'While Using' OR label CONTAINS 'أثناء استخدام' OR label CONTAINS 'عند استخدام'"
        )).firstMatch
        XCTAssertTrue(allowLocation.waitForExistence(timeout: 5))
        allowLocation.tap()
        XCTAssertTrue(locationAlert.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists, "No permission alert should intercept map interaction.")
        return app
    }
}
