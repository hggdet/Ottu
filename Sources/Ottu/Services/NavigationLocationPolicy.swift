import CoreLocation
import Foundation

/// Navigation requires a recent user fix; a map browsing position is never an origin.
enum NavigationLocationPolicy {
    static func origin(
        coordinate: GeoCoordinate?,
        timestamp: Date?,
        accuracy: Double?,
        isAuthorized: Bool,
        now: Date = Date()
    ) -> GeoCoordinate? {
        guard isAuthorized, let coordinate, let timestamp, let accuracy,
              CLLocationCoordinate2DIsValid(coordinate.clCoordinate),
              accuracy.isFinite, accuracy >= 0, accuracy <= 100,
              now.timeIntervalSince(timestamp) >= -5,
              now.timeIntervalSince(timestamp) <= 30 else { return nil }
        return coordinate
    }

    static func routeMatchesRemainingStops(requested: [Place], remaining: [Place]) -> Bool {
        requested.map(\.id) == remaining.map(\.id)
    }

    /// Consume only the visited prefix, preserving the order of future waypoints.
    /// A good on-route fix can also cross a stop between two GPS samples.
    static func remainingStops(
        _ stops: [Place],
        on route: RoutePlan,
        coordinate: GeoCoordinate,
        accuracy: Double?,
        previousProgress: Double,
        currentProgress: Double
    ) -> [Place] {
        guard let accuracy, accuracy.isFinite, accuracy >= 0, accuracy <= 40 else { return stops }
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let isOnRoute = route.distanceFromRouteMeters(near: coordinate) <= 50
        return Array(stops.drop(while: { stop in
            let location = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
            if current.distance(from: location) <= 40 { return true }
            guard isOnRoute, route.distanceFromRouteMeters(near: stop.coordinate) <= 80 else { return false }
            let stopProgress = route.progressMeters(near: stop.coordinate)
            return previousProgress < stopProgress + 50 && currentProgress >= stopProgress + 50
        }))
    }
}
