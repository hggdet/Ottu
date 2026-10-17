import CoreLocation
import Combine
import Foundation

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

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            break
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
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            if isNavigationTracking {
                manager.startUpdatingLocation()
            } else {
                manager.requestLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        course = location.course >= 0 ? location.course : nil
        speedMetersPerSecond = location.speed >= 0 ? location.speed : nil
        horizontalAccuracyMeters = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        lastLocationTimestamp = location.timestamp
        locationUpdateID += 1
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // الموقع اختياري؛ تظل الخريطة قابلة للاستخدام دون تفعيله.
    }
}
