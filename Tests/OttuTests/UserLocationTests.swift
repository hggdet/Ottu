import CoreLocation
import XCTest
@testable import Ottu

@MainActor
final class UserLocationTests: XCTestCase {
    func testOutOfOrderBatchPublishesNewestTimestampedFix() {
        let subject = UserLocationManager()
        let coreLocationManager = CLLocationManager()
        let now = Date()
        let earlier = location(latitude: 33.3, longitude: 44.3, timestamp: now.addingTimeInterval(-10))
        let newest = location(latitude: 33.4, longitude: 44.4, timestamp: now)

        subject.locationManager(coreLocationManager, didUpdateLocations: [newest, earlier])

        XCTAssertEqual(subject.coordinate?.latitude ?? -1, 33.4, accuracy: 0.000_001)
        XCTAssertEqual(subject.coordinate?.longitude ?? -1, 44.4, accuracy: 0.000_001)
        XCTAssertEqual(subject.lastLocationTimestamp, now)
        XCTAssertEqual(subject.locationUpdateID, 1)
    }

    func testDelayedOlderFixCannotReplaceNewerPublishedFix() {
        let subject = UserLocationManager()
        let coreLocationManager = CLLocationManager()
        let now = Date()
        let newest = location(latitude: 33.4, longitude: 44.4, timestamp: now)
        let delayed = location(latitude: 33.3, longitude: 44.3, timestamp: now.addingTimeInterval(-5))

        subject.locationManager(coreLocationManager, didUpdateLocations: [newest])
        subject.locationManager(coreLocationManager, didUpdateLocations: [delayed])

        XCTAssertEqual(subject.coordinate?.latitude ?? -1, 33.4, accuracy: 0.000_001)
        XCTAssertEqual(subject.coordinate?.longitude ?? -1, 44.4, accuracy: 0.000_001)
        XCTAssertEqual(subject.lastLocationTimestamp, now)
        XCTAssertEqual(subject.locationUpdateID, 1)
    }

    func testInvalidAccuracyFixIsNotPublished() {
        let subject = UserLocationManager()
        let coreLocationManager = CLLocationManager()
        let invalid = location(latitude: 33.4, longitude: 44.4, timestamp: Date(), horizontalAccuracy: -1)

        subject.locationManager(coreLocationManager, didUpdateLocations: [invalid])

        XCTAssertNil(subject.coordinate)
        XCTAssertNil(subject.lastLocationTimestamp)
        XCTAssertEqual(subject.locationUpdateID, 0)
    }

    func testBatchSelectsNewestValidFixInsteadOfInvalidNewestEntry() {
        let subject = UserLocationManager()
        let coreLocationManager = CLLocationManager()
        let now = Date()
        let valid = location(latitude: 33.3, longitude: 44.3, timestamp: now.addingTimeInterval(-1))
        let invalid = location(latitude: 33.4, longitude: 44.4, timestamp: now, horizontalAccuracy: -1)

        subject.locationManager(coreLocationManager, didUpdateLocations: [valid, invalid])

        XCTAssertEqual(subject.coordinate?.latitude ?? -1, 33.3, accuracy: 0.000_001)
        XCTAssertEqual(subject.coordinate?.longitude ?? -1, 44.3, accuracy: 0.000_001)
        XCTAssertEqual(subject.lastLocationTimestamp, valid.timestamp)
        XCTAssertEqual(subject.locationUpdateID, 1)
    }

    func testForegroundResumeRestartsActiveNavigationTracking() {
        XCTAssertEqual(
            UserLocationManager.resumeAction(
                authorizationStatus: .authorizedWhenInUse,
                isNavigationTracking: true,
                hasPendingLocationRequest: false
            ),
            .restartNavigationTracking
        )
    }

    func testForegroundResumeRetriesPendingSingleFix() {
        XCTAssertEqual(
            UserLocationManager.resumeAction(
                authorizationStatus: .authorizedAlways,
                isNavigationTracking: false,
                hasPendingLocationRequest: true
            ),
            .retryLocationRequest
        )
    }

    func testForegroundResumeDoesNotRequestLocationWithoutUserIntentOrAuthorization() {
        XCTAssertEqual(
            UserLocationManager.resumeAction(
                authorizationStatus: .authorizedWhenInUse,
                isNavigationTracking: false,
                hasPendingLocationRequest: false
            ),
            .none
        )
        XCTAssertEqual(
            UserLocationManager.resumeAction(
                authorizationStatus: .denied,
                isNavigationTracking: true,
                hasPendingLocationRequest: true
            ),
            .none
        )
    }

    private func location(
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        horizontalAccuracy: CLLocationAccuracy = 5
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: timestamp
        )
    }
}
