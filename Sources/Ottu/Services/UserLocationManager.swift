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
    private var retryTask: Task<Void, Never>?
    private var retryFailureCount = 0

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
            cancelRetry(resetFailureCount: true)
            hasPendingLocationRequest = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            cancelRetry(resetFailureCount: true)
            hasPendingLocationRequest = true
            manager.requestLocation()
        case .denied, .restricted:
            cancelRetry(resetFailureCount: true)
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
                requestPendingOneShot()
            }
        case .denied, .restricted:
            cancelRetry(resetFailureCount: true)
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
                .filter({
                    CLLocationCoordinate2DIsValid($0.coordinate)
                        && $0.coordinate.latitude.isFinite
                        && $0.coordinate.longitude.isFinite
                        && $0.horizontalAccuracy.isFinite
                        && $0.horizontalAccuracy >= 0
                })
                .max(by: { $0.timestamp < $1.timestamp }) else {
            retryUnusableOneShotFix()
            return
        }
        guard !hasPendingLocationRequest || Self.isRecentOneShotFix(timestamp: location.timestamp),
              lastLocationTimestamp.map({ location.timestamp > $0 }) ?? true else {
            retryUnusableOneShotFix()
            return
        }
        coordinate = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        course = location.course >= 0 ? location.course : nil
        speedMetersPerSecond = location.speed >= 0 ? location.speed : nil
        horizontalAccuracyMeters = location.horizontalAccuracy
        lastLocationTimestamp = location.timestamp
        locationUpdateID += 1
        hasPendingLocationRequest = false
        cancelRetry(resetFailureCount: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .denied {
            hasPendingLocationRequest = false
            cancelRetry(resetFailureCount: true)
            return
        }
        guard hasPendingLocationRequest, !isNavigationTracking,
              Self.isRetryableLocationError(error),
              let delay = Self.retryDelay(afterFailureCount: retryFailureCount) else { return }

        retryFailureCount += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            guard let self, !Task.isCancelled,
                  self.hasPendingLocationRequest, !self.isNavigationTracking,
                  self.manager.authorizationStatus == .authorizedAlways
                    || self.manager.authorizationStatus == .authorizedWhenInUse else { return }
            self.retryTask = nil
            self.manager.requestLocation()
        }
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
            requestPendingOneShot()
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

    private func retryUnusableOneShotFix() {
        guard hasPendingLocationRequest, !isNavigationTracking else { return }
        locationManager(manager, didFailWithError: NSError(domain: kCLErrorDomain, code: CLError.Code.locationUnknown.rawValue))
    }

    static func isRecentOneShotFix(timestamp: Date, now: Date = Date()) -> Bool {
        (-5...60).contains(now.timeIntervalSince(timestamp))
    }

    private func requestPendingOneShot() {
        retryTask?.cancel()
        retryTask = nil
        manager.requestLocation()
    }

    private func cancelRetry(resetFailureCount: Bool) {
        retryTask?.cancel()
        retryTask = nil
        if resetFailureCount { retryFailureCount = 0 }
    }

    static func retryDelay(afterFailureCount count: Int) -> TimeInterval? {
        let delays: [TimeInterval] = [1, 2, 4]
        guard delays.indices.contains(count) else { return nil }
        return delays[count]
    }

    static func isRetryableLocationError(_ error: Error) -> Bool {
        guard let locationError = error as? CLError else { return false }
        return locationError.code == .locationUnknown || locationError.code == .network
    }
}

enum LocationResumeAction: Equatable {
    case none
    case retryLocationRequest
    case restartNavigationTracking
}
