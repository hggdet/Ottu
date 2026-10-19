import Foundation
import XCTest
@testable import Ottu

final class MapLocationFocusPolicyTests: XCTestCase {
    private let coordinate = GeoCoordinate(latitude: 33.3152, longitude: 44.3661)
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testStartupWaitsForFirstFixAndConsumesItOnlyOnce() {
        var subject = MapLocationFocusPolicy()
        XCTAssertTrue(subject.start())
        XCTAssertNil(subject.consume(coordinate: nil, timestamp: nil, accuracy: nil, isAuthorized: true, now: now))
        XCTAssertTrue(subject.isPending)
        XCTAssertEqual(fix(&subject)?.coordinate, coordinate)
        XCTAssertFalse(subject.isPending)
        XCTAssertNil(fix(&subject))
    }

    func testStartupDoesNotRepeatWhenViewAppearsAgain() {
        var subject = MapLocationFocusPolicy()
        XCTAssertTrue(subject.start())
        XCTAssertNotNil(fix(&subject))
        XCTAssertFalse(subject.start())
        XCTAssertNil(fix(&subject))
    }

    func testOneTapWaitsForPermissionAndThenUsesFirstFix() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        XCTAssertNil(subject.consume(coordinate: coordinate, timestamp: now, accuracy: 10, isAuthorized: false, now: now))
        XCTAssertTrue(subject.isPending)
        XCTAssertNotNil(fix(&subject))
        XCTAssertFalse(subject.isPending)
    }

    func testExplicitTapUsesStaleFixButStartupDoesNot() {
        var startup = MapLocationFocusPolicy()
        XCTAssertTrue(startup.start())
        XCTAssertNil(startup.consume(
            coordinate: coordinate, timestamp: now.addingTimeInterval(-61), accuracy: 10,
            isAuthorized: true, now: now
        ))
        XCTAssertTrue(startup.isPending)

        var explicit = MapLocationFocusPolicy()
        explicit.request()
        XCTAssertEqual(explicit.consume(
            coordinate: coordinate, timestamp: now.addingTimeInterval(-61), accuracy: 10,
            isAuthorized: true, now: now
        )?.coordinate, coordinate)
        XCTAssertFalse(explicit.isPending)
    }

    func testExplicitTapSurvivesPermissionTransitionWithStaleFix() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        XCTAssertNil(subject.consume(
            coordinate: coordinate, timestamp: now.addingTimeInterval(-120), accuracy: 10,
            isAuthorized: false, now: now
        ))
        XCTAssertTrue(subject.isPending)
        XCTAssertEqual(subject.consume(
            coordinate: coordinate, timestamp: now.addingTimeInterval(-120), accuracy: 10,
            isAuthorized: true, now: now
        )?.coordinate, coordinate)
        XCTAssertFalse(subject.isPending)
    }

    func testRepeatedTapsAtSameCoordinateCreateDistinctCameraCommands() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        let first = fix(&subject)
        subject.request()
        let second = fix(&subject)
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first?.coordinate, second?.coordinate)
        XCTAssertNotEqual(first?.id, second?.id)
    }

    func testNewGPSUpdatesDoNotRecenterAfterUserMovesMap() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        XCTAssertNotNil(fix(&subject))
        XCTAssertNil(subject.consume(
            coordinate: GeoCoordinate(latitude: 33.4, longitude: 44.4),
            timestamp: now.addingTimeInterval(1), accuracy: 5, isAuthorized: true,
            now: now.addingTimeInterval(1)
        ))
    }

    func testGestureOrPlaceSelectionCancelsPendingStartup() {
        var subject = MapLocationFocusPolicy()
        XCTAssertTrue(subject.start())
        subject.cancel()
        XCTAssertNil(fix(&subject))
        subject.request()
        XCTAssertNotNil(fix(&subject))
    }

    func testReducedAccuracyFixCanFocusWithoutPassingNavigationAccuracyLimit() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        XCTAssertNotNil(subject.consume(coordinate: coordinate, timestamp: now, accuracy: 5_000, isAuthorized: true, now: now))
    }

    func testExplicitTapRejectsFixMoreThanFiveSecondsInFuture() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        XCTAssertNil(subject.consume(
            coordinate: coordinate, timestamp: now.addingTimeInterval(6),
            accuracy: 10, isAuthorized: true, now: now
        ))
        XCTAssertTrue(subject.isPending)
        XCTAssertNotNil(subject.consume(
            coordinate: coordinate, timestamp: now.addingTimeInterval(-61),
            accuracy: 10, isAuthorized: true, now: now
        ))
    }

    func testInvalidAccuracyIsRejectedWithoutConsumingRequest() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        for accuracy in [-1.0, .infinity, .nan] {
            XCTAssertNil(subject.consume(coordinate: coordinate, timestamp: now, accuracy: accuracy, isAuthorized: true, now: now))
            XCTAssertTrue(subject.isPending)
        }
        XCTAssertNotNil(fix(&subject))
    }

    func testInvalidCoordinateIsRejectedWithoutConsumingRequest() {
        var subject = MapLocationFocusPolicy()
        subject.request()
        XCTAssertNil(subject.consume(
            coordinate: GeoCoordinate(latitude: 91, longitude: 44), timestamp: now,
            accuracy: 5, isAuthorized: true, now: now
        ))
        XCTAssertTrue(subject.isPending)
        XCTAssertNotNil(fix(&subject))
    }

    private func fix(_ subject: inout MapLocationFocusPolicy) -> MapRecenterRequest? {
        subject.consume(coordinate: coordinate, timestamp: now, accuracy: 10, isAuthorized: true, now: now)
    }
}
