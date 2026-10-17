import XCTest
@testable import Ottu

final class PlaceTests: XCTestCase {
    func testSubtitleJoinsAvailableAddressParts() {
        let place = Place(
            id: "test-1",
            name: "Test Place",
            street: "Street 1",
            city: "Baghdad",
            country: nil,
            coordinate: GeoCoordinate(latitude: 33.3, longitude: 44.4)
        )

        XCTAssertEqual(place.subtitle, "Street 1، Baghdad")
    }

    func testShareURLContainsCoordinates() {
        let place = Place(
            id: "test-2",
            name: "Test Place",
            street: nil,
            city: nil,
            country: nil,
            coordinate: GeoCoordinate(latitude: 33.3152, longitude: 44.3661)
        )

        XCTAssertEqual(place.openStreetMapURL.host, "www.openstreetmap.org")
        XCTAssertTrue(place.openStreetMapURL.absoluteString.contains("33.3152"))
        XCTAssertTrue(place.openStreetMapURL.absoluteString.contains("44.3661"))
    }

    func testIncidentReportTrimsNoteAndKeepsCoordinate() {
        let coordinate = GeoCoordinate(latitude: 33.3152, longitude: 44.3661)
        let report = IncidentReport(kind: .checkpoint, note: "  طريق مغلق  ", coordinate: coordinate)

        XCTAssertEqual(report.note, "طريق مغلق")
        XCTAssertEqual(report.kind, .checkpoint)
        XCTAssertEqual(report.coordinate, coordinate)
    }

    func testSetupLocalizationKeysResolveInEverySupportedLanguage() {
        let keys = ["setup.language.message", "setup.progress_format"]

        for language in ["ar", "en", "ku"] {
            let locale = Locale(identifier: language)
            for key in keys {
                XCTAssertNotEqual(
                    AppLocalization.string(key, locale: locale),
                    key,
                    "Missing \(key) translation for \(language)"
                )
            }
        }
    }

    func testLanguageChoiceNamesResolveInEverySupportedLanguage() {
        let languageNames = [
            "settings.language.arabic": "العربية",
            "settings.language.english": "English",
            "settings.language.kurdish": "کوردی (سۆرانی)"
        ]

        for language in ["ar", "en", "ku"] {
            let locale = Locale(identifier: language)
            for (key, expectedName) in languageNames {
                XCTAssertEqual(
                    AppLocalization.string(key, locale: locale),
                    expectedName,
                    "Incorrect or missing language name for \(key) in \(language)"
                )
            }
        }
    }

    func testMissingLocalizationDoesNotExposeRawKey() {
        let key = "missing.translation.key"

        XCTAssertEqual(AppLocalization.string(key, locale: Locale(identifier: "ar")), "")
    }

    func testAppLocalizationRecognizesRightToLeftLanguages() {
        XCTAssertTrue(AppLocalization.isRightToLeft(Locale(identifier: "ar")))
        XCTAssertTrue(AppLocalization.isRightToLeft(Locale(identifier: "ku")))
        XCTAssertTrue(AppLocalization.isRightToLeft(Locale(identifier: "ckb")))
        XCTAssertFalse(AppLocalization.isRightToLeft(Locale(identifier: "en")))
        XCTAssertEqual(AppLocalization.languageCode(for: Locale(identifier: "ckb")), "ku")
    }

    func testParkedCarLocationPreservesCoordinateAndTimestampWhenEncoded() throws {
        let location = ParkedCarLocation(
            coordinate: GeoCoordinate(latitude: 33.3152, longitude: 44.3661),
            savedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(ParkedCarLocation.self, from: data)

        XCTAssertEqual(decoded, location)
    }

    func testMapAndParkedCarLabelsResolveInEverySupportedLanguage() {
        let keys = [
            "map.settings.app_language",
            "search.clear_history",
            "parked_car.save",
            "parked_car.title",
            "parked_car.saved_at",
            "parked_car.walk_back",
            "parked_car.delete",
            "network.offline.pill.general",
            "network.offline.pill.route"
        ]

        for language in ["ar", "en", "ku"] {
            let locale = Locale(identifier: language)
            for key in keys {
                XCTAssertNotEqual(
                    AppLocalization.string(key, locale: locale),
                    key,
                    "Missing \(key) translation for \(language)"
                )
            }
        }
    }
}
