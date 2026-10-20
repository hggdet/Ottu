import XCTest

@MainActor
final class PlaceSearchFlowUITests: XCTestCase {
    func testCircularSearchButtonOpensAndReopensArabicSearchField() {
        verifySearchInteraction(language: "ar", locale: "ar_IQ")
    }

    func testCircularSearchButtonOpensAndReopensEnglishSearchField() {
        verifySearchInteraction(language: "en", locale: "en_US")
    }

    private func verifySearchInteraction(language: String, locale: String) {
        continueAfterFailure = false
        // Accessibility frames can report 44pt as 43.99999999999997.
        let hitTargetTolerance: CGFloat = 0.001
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = [
            "-ottu.welcomeMotionCompleted", "YES",
            "-ottu.initialSetupCompleted", "YES",
            "-ottu.locationExplanationDismissed", "NO",
            "-ottu.language", language,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()
        defer { app.terminate() }

        // Resolve the real system prompt before the single search tap. Otherwise
        // XCTest's default interruption handler denies location and leaves the
        // app's permission-guidance alert covering the search control.
        let locationAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(locationAlert.waitForExistence(timeout: 15), "Resetting location authorization must produce the system prompt.")
        let allowLocation = locationAlert.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'While Using' OR label CONTAINS 'أثناء استخدام' OR label CONTAINS 'عند استخدام'"
        )).firstMatch
        XCTAssertTrue(allowLocation.waitForExistence(timeout: 5))
        allowLocation.tap()
        XCTAssertTrue(locationAlert.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists, "No permission alert should intercept the search tap.")

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
}
