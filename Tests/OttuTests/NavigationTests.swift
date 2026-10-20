import XCTest
@testable import Ottu

final class NavigationTests: XCTestCase {
    func testNavigationTabsKeepRequestedRightToLeftOrder() {
        XCTAssertEqual(
            MapNavigationTab.allCases.map(\.rawValue),
            ["location", "assistant", "settings"]
        )
    }

    func testRouteDistanceUsesNearestPolylineSegment() {
        let route = RoutePlan(
            coordinates: [
                GeoCoordinate(latitude: 0, longitude: 0),
                GeoCoordinate(latitude: 0, longitude: 0.01)
            ],
            distanceMeters: 1_000,
            durationSeconds: 600
        )

        let onRoute = GeoCoordinate(latitude: 0, longitude: 0.005)
        let offRoute = GeoCoordinate(latitude: 0.001, longitude: 0.005)

        XCTAssertLessThan(route.distanceFromRouteMeters(near: onRoute), 1)
        XCTAssertEqual(route.distanceFromRouteMeters(near: offRoute), 111, accuracy: 3)
    }

    func testRouteProgressProjectsLocationBetweenPolylineVertices() {
        let route = RoutePlan(
            coordinates: [
                GeoCoordinate(latitude: 0, longitude: 0),
                GeoCoordinate(latitude: 0, longitude: 0.01)
            ],
            distanceMeters: 1_000,
            durationSeconds: 600
        )

        XCTAssertEqual(
            route.progressMeters(near: GeoCoordinate(latitude: 0, longitude: 0.005)),
            500,
            accuracy: 1
        )
    }

    func testRouteCoordinateAtProgressInterpolatesBetweenVertices() {
        let route = RoutePlan(
            coordinates: [
                GeoCoordinate(latitude: 0, longitude: 0),
                GeoCoordinate(latitude: 0, longitude: 0.01)
            ],
            distanceMeters: 1_000,
            durationSeconds: 600
        )

        let coordinate = route.coordinate(atProgressMeters: 500)
        XCTAssertEqual(coordinate?.latitude ?? .infinity, 0, accuracy: 0.000_001)
        XCTAssertEqual(coordinate?.longitude ?? .infinity, 0.005, accuracy: 0.000_001)
    }
}
