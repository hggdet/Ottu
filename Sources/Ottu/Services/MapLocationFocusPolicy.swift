import CoreLocation
import Foundation

/// A camera command, not a tracking mode. A new ID makes repeated taps at the
/// same coordinate work, without moving the camera on subsequent GPS updates.
struct MapRecenterRequest: Identifiable, Equatable {
    let id = UUID()
    let coordinate: GeoCoordinate
}

struct MapLocationFocusPolicy {
    private enum PendingIntent {
        case startup
        case explicit
    }

    private(set) var didStart = false
    private(set) var isPending = false
    private var pendingIntent: PendingIntent?

    mutating func start() -> Bool {
        guard !didStart else { return false }
        didStart = true
        isPending = true
        pendingIntent = .startup
        return true
    }

    mutating func request() {
        isPending = true
        pendingIntent = .explicit
    }

    mutating func cancel() {
        isPending = false
        pendingIntent = nil
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
        guard isPending, let pendingIntent, isAuthorized, let coordinate, let timestamp, let accuracy,
              CLLocationCoordinate2DIsValid(coordinate.clCoordinate),
              accuracy.isFinite, accuracy >= 0 else { return nil }
        let age = now.timeIntervalSince(timestamp)
        guard age.isFinite else { return nil }
        switch pendingIntent {
        case .startup where !(-5...60).contains(age):
            return nil
        case .explicit where age < -5:
            return nil
        default:
            break
        }
        isPending = false
        self.pendingIntent = nil
        return MapRecenterRequest(coordinate: coordinate)
    }
}
