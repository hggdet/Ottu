import CoreLocation
import Combine
import Foundation
import UIKit

@MainActor
final class UserLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinate: GeoCoordinate?
    @Published private(set) var course: Double?
    @Published private(set) var speedMetersPerSecond: Double?
    @Published private(set) var horizontalAccuracyMeters: Double?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var locationUpdateID = 0
    @Published private(set) var lastLocationTimestamp: Date?

    private let manager = CLLocationManager()
    private var isNavigationTracking = false
    private var hasPendingLocationRequest = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func requestAuthorization() {
        guard manager.authorizationStatus == .notDetermined else { return }
        hasPendingLocationRequest = true
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            hasPendingLocationRequest = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            hasPendingLocationRequest = true
            manager.requestLocation()
        case .denied, .restricted:
            hasPendingLocationRequest = false
        @unknown default:
            break
        }
    }

    func startNavigationTracking() {
        isNavigationTracking = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stopNavigationTracking() {
        isNavigationTracking = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if isNavigationTracking {
                manager.startUpdatingLocation()
            } else {
                hasPendingLocationRequest = true
                manager.requestLocation()
            }
        case .denied, .restricted:
            hasPendingLocationRequest = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Core Location may deliver cached fixes in a batch, and those fixes are
        // not guaranteed to be ordered. Never let a delayed fix move the position
        // backwards in time or publish a location with invalid accuracy.
        guard let location = locations
                .filter({ CLLocationCoordinate2DIsValid($0.coordinate) && $0.horizontalAccuracy >= 0 })
                .max(by: { $0.timestamp < $1.timestamp }),
              lastLocationTimestamp.map({ location.timestamp > $0 }) ?? true else { return }
        coordinate = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        course = location.course >= 0 ? location.course : nil
        speedMetersPerSecond = location.speed >= 0 ? location.speed : nil
        horizontalAccuracyMeters = location.horizontalAccuracy
        lastLocationTimestamp = location.timestamp
        locationUpdateID += 1
        hasPendingLocationRequest = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // الموقع اختياري؛ تظل الخريطة قابلة للاستخدام دون تفعيله. Keep a pending
        // one-shot request so it can be retried if the app returns to foreground.
    }

    @objc private func applicationDidBecomeActive() {
        switch Self.resumeAction(
            authorizationStatus: manager.authorizationStatus,
            isNavigationTracking: isNavigationTracking,
            hasPendingLocationRequest: hasPendingLocationRequest
        ) {
        case .restartNavigationTracking:
            manager.startUpdatingLocation()
        case .retryLocationRequest:
            manager.requestLocation()
        case .none:
            break
        }
    }

    static func resumeAction(
        authorizationStatus: CLAuthorizationStatus,
        isNavigationTracking: Bool,
        hasPendingLocationRequest: Bool
    ) -> LocationResumeAction {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return .none
        }
        if isNavigationTracking { return .restartNavigationTracking }
        if hasPendingLocationRequest { return .retryLocationRequest }
        return .none
    }
}

enum LocationResumeAction: Equatable {
    case none
    case retryLocationRequest
    case restartNavigationTracking
}
