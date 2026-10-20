import XCTest

@MainActor
final class PlaceSearchFlowUITests: XCTestCase {
    func testCircularSearchButtonOpensAndReopensArabicSearchField() {
        verifySearchInteraction(language: "ar", locale: "ar_IQ")
    }

    func testCircularSearchButtonOpensAndReopensEnglishSearchField() {
        verifySearchInteraction(language: "en", locale: "en_US")
    }

    func testSearchSelectionDismissesKeyboardInArabicAndEnglish() {
        verifySearchSelection(language: "ar", locale: "ar_IQ")
        verifySearchSelection(language: "en", locale: "en_US")
    }

    func testFuelQuickCategoryRetriesAndClosesInArabicAndEnglish() {
        verifyFuelQuickCategoryRetry(language: "ar", locale: "ar_IQ")
        verifyFuelQuickCategoryRetry(language: "en", locale: "en_US")
    }

    func testFuelQuickCategoryClosesDirectlyFromErrorInArabicAndEnglish() {
        verifyFuelQuickCategoryRetry(language: "ar", locale: "ar_IQ", closeOnError: true)
        verifyFuelQuickCategoryRetry(language: "en", locale: "en_US", closeOnError: true)
    }

    func testSearchDismissesBeforeCategoryAndAssistantSheetsInArabicAndEnglish() {
        verifyOtherSheetTransitions(language: "ar", locale: "ar_IQ")
        verifyOtherSheetTransitions(language: "en", locale: "en_US")
    }

    private func verifySearchInteraction(language: String, locale: String) {
        continueAfterFailure = false
        // Accessibility frames can report 44pt as 43.99999999999997.
        let hitTargetTolerance: CGFloat = 0.001
        let app = launchMap(language: language, locale: locale)
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15), "The circular place-search control should be present on the map.")
        XCTAssertTrue(searchButton.isHittable, "The circular place-search control should receive physical taps.")
        XCTAssertGreaterThanOrEqual(searchButton.frame.width, 44 - hitTargetTolerance)
        XCTAssertGreaterThanOrEqual(searchButton.frame.height, 44 - hitTargetTolerance)
        searchButton.tap()

        let searchField = app.textFields["placeSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Tapping the circle must reveal the actual text field.")
        XCTAssertTrue(searchField.isHittable)
        XCTAssertTrue(searchButton.waitForNonExistence(timeout: 5), "The closed-state magnifier must not remain after opening.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Opening search must focus the field and show the keyboard without another tap.")
        searchField.typeText("Baghdad")
        XCTAssertEqual(searchField.value as? String, "Baghdad", "The field must accept text, not only appear visually.")

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
        searchButton.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "A second physical tap must reopen search after closing it.")
        XCTAssertTrue(searchField.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertNotEqual(searchField.value as? String, "Baghdad", "Closing search must clear the previous query.")
        searchField.typeText("Basra")
        XCTAssertEqual(searchField.value as? String, "Basra", "The reopened field must accept a fresh query.")

        let clearButton = app.buttons["placeSearchClear"]
        XCTAssertTrue(clearButton.isHittable)
        clearButton.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(clearButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(searchField.exists, "Clear must keep search open.")
        XCTAssertNotEqual(searchField.value as? String, "Basra")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Clear must retain input focus.")
        searchField.typeText("Erbil")
        XCTAssertEqual(searchField.value as? String, "Erbil")
        closeButton.tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Close must also work after clearing and typing again.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
    }

    private func verifySearchSelection(language: String, locale: String) {
        continueAfterFailure = false
        let app = launchMap(
            language: language,
            locale: locale,
            extraArguments: ["-ottuUITestSearchSelectionFixture"]
        )
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15))
        searchButton.tap()
        let searchField = app.textFields["placeSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

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
    }

    private func verifyFuelQuickCategoryRetry(language: String, locale: String, closeOnError: Bool = false) {
        continueAfterFailure = false
        let app = launchMap(
            language: language,
            locale: locale,
            extraArguments: ["-ottuUITestNearbySearchFixture"]
        )
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15))
        searchButton.tap()
        XCTAssertTrue(app.textFields["placeSearchField"].waitForExistence(timeout: 5))

        // This deliberately exercises the map's quick chip, not the categories tab.
        let fuelChip = app.buttons["mapQuickCategory.fuel"]
        XCTAssertTrue(fuelChip.waitForExistence(timeout: 5), "The fuel quick-category chip should be available from focused map search.")
        XCTAssertTrue(fuelChip.isHittable)
        fuelChip.tap()
        XCTAssertTrue(app.textFields["placeSearchField"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Selecting the fuel quick category must dismiss the search keyboard before showing its results panel.")

        let panel = app.descendants(matching: .any)["mapCategoryResultsPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Selecting fuel must present the nearby-results panel.")
        let loadingState = app.buttons["mapCategoryResultsState.loading"]
        XCTAssertTrue(loadingState.waitForExistence(timeout: 5), "The DEBUG fixture holds its first response until this test explicitly releases it.")
        XCTAssertTrue(loadingState.isHittable)
        XCTAssertEqual(panel.value as? String, "loading")
        // Only this DEBUG fixture renders the unchanged loading label as a button
        // to signal a provider response. No wall-clock delay or live API is involved.
        loadingState.tap()

        let errorState = app.descendants(matching: .any)["mapCategoryResultsState.error"]
        XCTAssertTrue(errorState.waitForExistence(timeout: 5), "The first fixture request should transition to the retryable unavailable state.")
        XCTAssertEqual(panel.value as? String, "error")
        let retryButton = app.buttons["mapCategoryResultsRetry"]
        XCTAssertTrue(retryButton.exists)
        if closeOnError {
            // Reproduce the reported stuck-on-failure case without retrying or
            // allowing the fixture to advance to empty/results first.
            let closeButton = app.buttons["mapCategoryResultsClose"]
            XCTAssertTrue(closeButton.isHittable)
            closeButton.tap()
            XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "Close must dismiss the category panel directly from its error state.")
            XCTAssertTrue(errorState.waitForNonExistence(timeout: 5), "Closing must remove the failure UI, not only hide its text.")
            XCTAssertTrue(retryButton.waitForNonExistence(timeout: 5))
            return
        }
        retryButton.tap()

        let emptyState = app.descendants(matching: .any)["mapCategoryResultsState.empty"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Retry should return the fixture's deterministic empty result.")
        XCTAssertEqual(panel.value as? String, "empty")
        app.buttons["mapCategoryResultsClose"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "Closing the category results must dismiss the panel.")
    }

    private func verifyOtherSheetTransitions(language: String, locale: String) {
        continueAfterFailure = false
        let app = launchMap(language: language, locale: locale)
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15))
        searchButton.tap()
        let searchField = app.textFields["placeSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        app.buttons["mapTab.categories"].tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Opening categories must close map search.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Opening categories must dismiss the search keyboard.")
        let categoryNavigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(categoryNavigationBar.waitForExistence(timeout: 5), "The categories sheet should be presented.")
        let doneButton = categoryNavigationBar.buttons.firstMatch
        XCTAssertTrue(doneButton.exists, "The categories sheet should expose its Done control.")
        doneButton.tap()
        XCTAssertTrue(categoryNavigationBar.waitForNonExistence(timeout: 5))

        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["mapTab.assistant"].tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Opening assistant must close map search.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Opening assistant must dismiss the search keyboard.")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5), "The assistant sheet should be presented.")
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
