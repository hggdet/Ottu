import CoreLocation
import Foundation

/// A camera command, not a tracking mode. A new ID makes repeated taps at the
/// same coordinate work, without moving the camera on subsequent GPS updates.
struct MapRecenterRequest: Identifiable, Equatable {
    let id = UUID()
    let coordinate: GeoCoordinate
}

struct MapLocationFocusPolicy {
    private(set) var didStart = false
    private(set) var isPending = false

    mutating func start() -> Bool {
        guard !didStart else { return false }
        didStart = true
        isPending = true
        return true
    }

    mutating func request() {
        isPending = true
    }

    mutating func cancel() {
        isPending = false
    }

    mutating func consume(
        coordinate: GeoCoordinate?,
        timestamp: Date?,
        accuracy: Double?,
        isAuthorized: Bool,
        now: Date = Date()
    ) -> MapRecenterRequest? {
        // Browsing can use reduced-accuracy permission too. Do not impose the
        // navigation policy's 100 m accuracy limit on the first GPS fix.
        guard isPending, isAuthorized, let coordinate, let timestamp, let accuracy,
              CLLocationCoordinate2DIsValid(coordinate.clCoordinate),
              accuracy.isFinite, accuracy >= 0,
              (-5...60).contains(now.timeIntervalSince(timestamp)) else { return nil }
        isPending = false
        return MapRecenterRequest(coordinate: coordinate)
    }
}
