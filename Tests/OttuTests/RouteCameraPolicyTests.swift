import Foundation
import XCTest
@testable import Ottu

final class RouteCameraPolicyTests: XCTestCase {
    func testNewRouteStartsInOverviewInsteadOfFollowingUser() {
        var subject = RouteCameraPolicy()
        subject.resumeFollowing()
        subject.beginOverview()
        XCTAssertEqual(subject.mode, .overview)
    }

    func testMovingMapPausesFollowingUntilExplicitResume() {
        var subject = RouteCameraPolicy()
        subject.resumeFollowing()
        subject.userDidMoveMap()
        XCTAssertEqual(subject.mode, .browsing)
        subject.resumeFollowing()
        XCTAssertEqual(subject.mode, .following)
    }

    func testGPSRefreshDoesNotRefitAlreadyDisplayedRoute() {
        let routeID = UUID()
        XCTAssertFalse(RouteCameraPolicy.shouldFitOverview(
            mode: .overview, routeID: routeID, lastFittedRouteID: routeID
        ))
    }

    func testNewRouteFitsExactlyOnceInOverview() {
        let routeID = UUID()
        XCTAssertTrue(RouteCameraPolicy.shouldFitOverview(
            mode: .overview, routeID: routeID, lastFittedRouteID: nil
        ))
        XCTAssertFalse(RouteCameraPolicy.shouldFitOverview(
            mode: .overview, routeID: routeID, lastFittedRouteID: routeID
        ))
    }

    func testRouteReplyOrRerouteCannotRecenterWhileUserIsBrowsing() {
        XCTAssertFalse(RouteCameraPolicy.shouldFitOverview(
            mode: .browsing, routeID: UUID(), lastFittedRouteID: nil
        ))
        XCTAssertFalse(RouteCameraPolicy.shouldFitOverview(
            mode: .following, routeID: UUID(), lastFittedRouteID: nil
        ))
    }

    func testMissingRouteCannotTriggerAnOverview() {
        XCTAssertFalse(RouteCameraPolicy.shouldFitOverview(
            mode: .overview, routeID: nil, lastFittedRouteID: UUID()
        ))
    }
}
