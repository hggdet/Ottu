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
}
