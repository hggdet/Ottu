import Foundation

/// GPS continues updating progress in every mode, but may only move the camera
/// after an explicit Resume action. Starting a route shows its full overview.
struct RouteCameraPolicy {
    enum Mode: Equatable {
        case overview
        case browsing
        case following
    }

    private(set) var mode: Mode = .overview

    mutating func beginOverview() { mode = .overview }
    mutating func userDidMoveMap() { mode = .browsing }
    mutating func resumeFollowing() { mode = .following }

    static func shouldFitOverview(mode: Mode, routeID: UUID?, lastFittedRouteID: UUID?) -> Bool {
        mode == .overview && routeID != nil && routeID != lastFittedRouteID
    }
}
