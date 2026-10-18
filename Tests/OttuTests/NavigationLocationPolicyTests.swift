import XCTest
@testable import Ottu

final class NavigationLocationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let user = GeoCoordinate(latitude: 0, longitude: 0.002)
    private var route: RoutePlan {
        RoutePlan(coordinates: [GeoCoordinate(latitude: 0, longitude: 0),
                                GeoCoordinate(latitude: 0, longitude: 0.01)],
                  distanceMeters: 1_000, durationSeconds: 600)
    }

    private func stop(_ id: String, longitude: Double) -> Place {
        Place(id: id, name: id, street: nil, city: nil, country: nil,
              coordinate: GeoCoordinate(latitude: 0, longitude: longitude))
    }

    func testMissingUserLocationCannotBecomeNavigationOrigin() {
        XCTAssertNil(NavigationLocationPolicy.origin(coordinate: nil, timestamp: now,
                                                     accuracy: 5, isAuthorized: true, now: now))
    }

    func testOnlyFreshAuthorizedAccurateUserFixIsAnOrigin() {
        XCTAssertEqual(NavigationLocationPolicy.origin(coordinate: user, timestamp: now,
                                                       accuracy: 5, isAuthorized: true, now: now), user)
        XCTAssertNil(NavigationLocationPolicy.origin(coordinate: user, timestamp: now,
                                                     accuracy: 5, isAuthorized: false, now: now))
        XCTAssertNil(NavigationLocationPolicy.origin(coordinate: user, timestamp: now.addingTimeInterval(-31),
                                                     accuracy: 5, isAuthorized: true, now: now))
        XCTAssertNil(NavigationLocationPolicy.origin(coordinate: user, timestamp: nil,
                                                     accuracy: 5, isAuthorized: true, now: now))
        for accuracy in [nil, -1, 101, Double.nan, Double.infinity] as [Double?] {
            XCTAssertNil(NavigationLocationPolicy.origin(coordinate: user, timestamp: now,
                                                         accuracy: accuracy, isAuthorized: true, now: now))
        }
        XCTAssertNil(NavigationLocationPolicy.origin(coordinate: user, timestamp: now.addingTimeInterval(6),
                                                     accuracy: 5, isAuthorized: true, now: now))
    }

    func testInvalidCoordinateCannotBecomeNavigationOrigin() {
        XCTAssertNil(NavigationLocationPolicy.origin(
            coordinate: GeoCoordinate(latitude: 95, longitude: 0), timestamp: now,
            accuracy: 5, isAuthorized: true, now: now))
    }

    func testVisitedStopIsExcludedFromRerouteWaypoints() {
        let visited = stop("visited", longitude: 0.002)
        let future = stop("future", longitude: 0.008)
        let remaining = NavigationLocationPolicy.remainingStops(
            [visited, future], on: route, coordinate: user, accuracy: 5,
            currentProgress: 200)
        XCTAssertEqual(remaining.map(\.id), ["future"])
        XCTAssertEqual(remaining.map(\.coordinate), [future.coordinate])
    }

    func testStopCrossedBetweenGPSUpdatesIsExcluded() {
        let first = stop("first", longitude: 0.002)
        let second = stop("second", longitude: 0.004)
        let future = stop("future", longitude: 0.008)
        let remaining = NavigationLocationPolicy.remainingStops(
            [first, second, future], on: route,
            coordinate: GeoCoordinate(latitude: 0, longitude: 0.006), accuracy: 5,
            currentProgress: 600)
        XCTAssertEqual(remaining.map(\.id), ["future"])
    }

    func testCrossingBufferAfterPassingStopStillConsumesIt() {
        let remaining = NavigationLocationPolicy.remainingStops(
            [stop("stop", longitude: 0.002)], on: route,
            coordinate: GeoCoordinate(latitude: 0, longitude: 0.003), accuracy: 5,
            currentProgress: 300)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testInaccurateOrOffRouteFixDoesNotConsumeStops() {
        let stops = [stop("first", longitude: 0.002), stop("future", longitude: 0.008)]
        for accuracy in [nil, -1, 41, Double.nan] as [Double?] {
            XCTAssertEqual(NavigationLocationPolicy.remainingStops(
                stops, on: route, coordinate: user, accuracy: accuracy,
                currentProgress: 600).map(\.id), stops.map(\.id))
        }
        XCTAssertEqual(NavigationLocationPolicy.remainingStops(
            stops, on: route, coordinate: GeoCoordinate(latitude: 0.003, longitude: 0.006), accuracy: 5,
            currentProgress: 600).map(\.id), stops.map(\.id))
    }

    func testFutureStopAndOrderedPrefixArePreserved() {
        let stops = [stop("first", longitude: 0.008), stop("later", longitude: 0.002)]
        XCTAssertEqual(NavigationLocationPolicy.remainingStops(
            stops, on: route, coordinate: user, accuracy: 5,
            currentProgress: 200).map(\.id), stops.map(\.id))
    }
    func testResponseForVisitedStopIsRejectedAfterWaypointsChange() {
        let visited = stop("visited", longitude: 0.002)
        let future = stop("future", longitude: 0.008)
        XCTAssertFalse(NavigationLocationPolicy.routeMatchesRemainingStops(
            requested: [visited, future], remaining: [future]))
        XCTAssertFalse(NavigationLocationPolicy.routeMatchesRemainingStops(
            requested: [visited], remaining: []))
        XCTAssertTrue(NavigationLocationPolicy.routeMatchesRemainingStops(
            requested: [future], remaining: [future]))
    }

    func testAccurateFixAfterWeakGPSStillConsumesAlreadyPassedStop() {
        let stops = [stop("visited", longitude: 0.002), stop("future", longitude: 0.008)]
        let coordinate = GeoCoordinate(latitude: 0, longitude: 0.006)
        XCTAssertEqual(NavigationLocationPolicy.remainingStops(
            stops, on: route, coordinate: coordinate, accuracy: 75,
            currentProgress: 550).map(\.id), ["visited", "future"])
        XCTAssertEqual(NavigationLocationPolicy.remainingStops(
            stops, on: route, coordinate: coordinate, accuracy: 5,
            currentProgress: 600).map(\.id), ["future"])
    }

}
