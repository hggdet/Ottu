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
        let app = XCUIApplication()
        app.launchArguments = [
            "-ottu.welcomeMotionCompleted", "YES",
            "-ottu.initialSetupCompleted", "YES",
            "-ottu.locationExplanationDismissed", "YES",
            "-ottu.language", language,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()
        defer { app.terminate() }

        let searchButton = app.buttons["placeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 15), "The circular place-search control should be present on the map.")
        XCTAssertTrue(searchButton.isHittable, "The circular place-search control should receive physical taps.")
        XCTAssertGreaterThanOrEqual(searchButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(searchButton.frame.height, 44)
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
        closeButton.tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5))
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        XCTAssertTrue(searchButton.isHittable)
        searchButton.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "A second physical tap must reopen search after closing it.")
        XCTAssertTrue(searchField.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertNotEqual(searchField.value as? String, "Baghdad", "Closing search must clear the previous query.")
        searchField.typeText("Basra")
        XCTAssertEqual(searchField.value as? String, "Basra", "The reopened field must accept a fresh query.")
    }
}
