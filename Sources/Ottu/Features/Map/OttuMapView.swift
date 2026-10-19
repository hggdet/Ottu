import CoreLocation
import QuartzCore
import MapLibre
import SwiftUI
import UIKit

private final class RouteAlternativeAnnotation: MLNPointAnnotation {}
private final class ParkedCarAnnotation: MLNPointAnnotation {}

final class UserLocationSymbolAnnotationView: MLNUserLocationAnnotationView {
    private let symbolView = UIImageView()
    private static let stationaryPulseKey = "ottu-stationary-location-pulse"
    private var latestSpeed: CLLocationSpeed?

    init() {
        super.init(annotation: nil, reuseIdentifier: "ottu-user-location-symbol")
        // Screen-space points, independent of zoom and perspective on a tilted map.
        scalesWithViewingDistance = false
        rotatesToMatchCamera = false
        frame = CGRect(x: 0, y: 0, width: 22, height: 22)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = NSLocalizedString("map.settings.user_location_icon.arrow", comment: "")
        symbolView.image = UIImage(systemName: "location.north.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        symbolView.tintColor = .systemBlue
        symbolView.contentMode = .scaleAspectFit
        symbolView.frame = bounds
        symbolView.isUserInteractionEnabled = false
        addSubview(symbolView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setSpeed(_ speed: CLLocationSpeed?, reduceMotion: Bool) {
        latestSpeed = speed
        let isStationary = speed.map { $0.isFinite && $0 >= 0 && $0 <= 0.5 } ?? false
        guard isStationary, !reduceMotion else {
            symbolView.layer.removeAnimation(forKey: Self.stationaryPulseKey)
            return
        }
        // Opacity preserves the arrow's 22×22pt size and its independent heading transform.
        guard symbolView.layer.animation(forKey: Self.stationaryPulseKey) == nil else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.72
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        symbolView.layer.add(pulse, forKey: Self.stationaryPulseKey)
    }

    @objc private func reduceMotionStatusDidChange() {
        setSpeed(latestSpeed, reduceMotion: UIAccessibility.isReduceMotionEnabled)
    }

    func setScreenHeading(_ heading: CLLocationDirection?) {
        let angle = heading.map { CGFloat($0 * .pi / 180) } ?? 0
        symbolView.transform = CGAffineTransform(rotationAngle: angle)
    }
}

struct OttuMapView: UIViewRepresentable {
    let selectedPlace: Place?
    let parkedCarLocation: ParkedCarLocation?
    let parkedCarTitle: String
    let route: RoutePlan?
    let alternativeRoutes: [RoutePlan]
    let alternativeRouteLabels: [UUID: String]
    let styleURL: URL
    let is3D: Bool
    let isNavigationActive: Bool
    let routeCameraMode: RouteCameraPolicy.Mode
    let isLocationAuthorized: Bool
    let navigationCoordinate: GeoCoordinate?
    let navigationCourse: Double?
    let recenterRequest: MapRecenterRequest?
    let reduceMotion: Bool
    @ObservedObject var iraqBuildingsManager: IraqBuildingFootprintsManager
    let onSelectAlternativeRoute: (UUID) -> Void
    let onSelectParkedCar: () -> Void
    let onLongPress: (GeoCoordinate) -> Void
    let onCenterChanged: (GeoCoordinate) -> Void
    let onMapMotionChanged: (Bool) -> Void
    let onUserInteraction: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLongPress: onLongPress,
            onCenterChanged: onCenterChanged,
            onMapMotionChanged: onMapMotionChanged,
            onUserInteraction: onUserInteraction,
            iraqBuildingsManager: iraqBuildingsManager,
            onSelectAlternativeRoute: onSelectAlternativeRoute,
            onSelectParkedCar: onSelectParkedCar
        )
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        context.coordinator.currentStyleURL = styleURL
        mapView.delegate = context.coordinator
        mapView.compassView.isHidden = true
        mapView.showsAttributionButton = false
        mapView.showsLogoView = false
        context.coordinator.reduceUserLocationMotion = reduceMotion
        mapView.showsUserLocation = isLocationAuthorized
        mapView.setCenter(
            MapConfiguration.initialCenter.clCoordinate,
            zoomLevel: MapConfiguration.initialZoom,
            animated: false
        )
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.65
        longPress.allowableMovement = 12
        longPress.cancelsTouchesInView = false
        mapView.addGestureRecognizer(longPress)
        let routeTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRouteTap(_:)))
        routeTap.cancelsTouchesInView = false
        mapView.addGestureRecognizer(routeTap)
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onCenterChanged = onCenterChanged
        context.coordinator.onMapMotionChanged = onMapMotionChanged
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.onSelectAlternativeRoute = onSelectAlternativeRoute
        context.coordinator.onSelectParkedCar = onSelectParkedCar
        context.coordinator.iraqBuildingsManager = iraqBuildingsManager
        context.coordinator.reduceUserLocationMotion = reduceMotion
        if mapView.showsUserLocation != isLocationAuthorized {
            mapView.showsUserLocation = isLocationAuthorized
        }
        if context.coordinator.currentStyleURL != styleURL {
            mapView.styleURL = styleURL
            context.coordinator.currentStyleURL = styleURL
            context.coordinator.appliedRouteSignature = nil
            context.coordinator.resetIraqBuildingLayers()
        }
        context.coordinator.updateNavigationCamera(
            isActive: isNavigationActive,
            mode: routeCameraMode,
            coordinate: navigationCoordinate,
            course: navigationCourse,
            is3D: is3D,
            on: mapView,
            animated: !reduceMotion
        )
        context.coordinator.updateUserLocationSymbolHeading(on: mapView)
        if context.coordinator.lastSelectedPlaceID != selectedPlace?.id {
            context.coordinator.lastSelectedPlaceID = selectedPlace?.id
            context.coordinator.updateSelectedPlaceAnnotation(selectedPlace, on: mapView)
            if let selectedPlace, !isNavigationActive {
                mapView.setCenter(selectedPlace.coordinate.clCoordinate, zoomLevel: 15, animated: !reduceMotion)
            }
        }
        context.coordinator.updateRoute(
            route,
            alternatives: alternativeRoutes,
            labels: alternativeRouteLabels,
            on: mapView
        )
        context.coordinator.updateParkedCarAnnotation(
            parkedCarLocation,
            title: parkedCarTitle,
            on: mapView
        )
        context.coordinator.updateRouteOverview(
            route: route,
            origin: navigationCoordinate,
            destination: selectedPlace?.coordinate,
            on: mapView,
            animated: !reduceMotion
        )
        context.coordinator.requestIraqBuildings(on: mapView)
        // Run after route and pitch updates so they cannot interrupt this tap.
        context.coordinator.updateRecenterRequest(
            isNavigationActive ? nil : recenterRequest,
            on: mapView,
            animated: !reduceMotion
        )
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var lastSelectedPlaceID: String?
        var currentStyleURL: URL?
        var appliedRouteSignature: String?
        private var pendingRecenterRequest: MapRecenterRequest?
        private var lastAppliedRecenterID: UUID?
        private var animateRecenter = false
        private var routeCameraMode: RouteCameraPolicy.Mode = .overview
        private var lastOverviewRouteID: UUID?
        private var pendingOverviewRouteID: UUID?
        private var pendingOverviewCoordinates: [GeoCoordinate] = []
        private var animateOverview = false
        var latestRoute: RoutePlan?
        var latestAlternativeRoutes: [RoutePlan] = []
        var latestAlternativeLabels: [UUID: String] = [:]
        var is3D = false
        private(set) var isNavigating = false
        private var navigationCoordinate: GeoCoordinate?
        private var navigationCourse: Double?
        private var latestUserLocationCourse: CLLocationDirection?
        private var latestUserLocationHeading: CLLocationDirection?
        private var latestUserLocationSpeed: CLLocationSpeed?
        var reduceUserLocationMotion = UIAccessibility.isReduceMotionEnabled
        private weak var userLocationSymbolView: UserLocationSymbolAnnotationView?
        private var routeLayerIdentifiers: [String] = []
        private var routeSourceIdentifiers: [String] = []
        private var routeAlternativeAnnotations: [RouteAlternativeAnnotation] = []
        var onLongPress: (GeoCoordinate) -> Void
        var onCenterChanged: (GeoCoordinate) -> Void
        var onMapMotionChanged: (Bool) -> Void
        var onUserInteraction: () -> Void
        var onSelectAlternativeRoute: (UUID) -> Void
        var onSelectParkedCar: () -> Void
        weak var iraqBuildingsManager: IraqBuildingFootprintsManager?
        private var selectedPlaceAnnotation: MLNPointAnnotation?
        private var parkedCarAnnotation: ParkedCarAnnotation?
        private weak var parkedCarAnnotationView: MLNAnnotationView?
        private var lastParkedCarCoordinate: GeoCoordinate?
        private var lastParkedCarTitle: String?
        private var iraqBuildingsTask: Task<Void, Never>?
        private var lastIraqBuildingsRequestKey: String?
        private var appliedIraqBuildingFiles: [String: URL] = [:]
        private var appliedIraqBuildings3D: Bool?

        init(
            onLongPress: @escaping (GeoCoordinate) -> Void,
            onCenterChanged: @escaping (GeoCoordinate) -> Void,
            onMapMotionChanged: @escaping (Bool) -> Void,
            onUserInteraction: @escaping () -> Void,
            iraqBuildingsManager: IraqBuildingFootprintsManager,
            onSelectAlternativeRoute: @escaping (UUID) -> Void,
            onSelectParkedCar: @escaping () -> Void
        ) {
            self.onLongPress = onLongPress
            self.onCenterChanged = onCenterChanged
            self.onMapMotionChanged = onMapMotionChanged
            self.onUserInteraction = onUserInteraction
            self.iraqBuildingsManager = iraqBuildingsManager
            self.onSelectAlternativeRoute = onSelectAlternativeRoute
            self.onSelectParkedCar = onSelectParkedCar
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MLNMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress(GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }

        @objc func handleRouteTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let mapView = recognizer.view as? MLNMapView,
                  !latestAlternativeRoutes.isEmpty else { return }
            let coordinate = mapView.convert(recognizer.location(in: mapView), toCoordinateFrom: mapView)
            let location = GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let metersPerPoint = 156_543.03392 * cos(coordinate.latitude * .pi / 180) / pow(2, mapView.zoomLevel)
            let tolerance = max(22, min(110, metersPerPoint * 24))
            guard let route = latestAlternativeRoutes
                .map({ ($0, $0.distanceFromRouteMeters(near: location)) })
                .filter({ $0.1 <= tolerance })
                .min(by: { $0.1 < $1.1 })?.0 else { return }
            onSelectAlternativeRoute(route.id)
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            // Camera animations also call this delegate; only actual gestures
            // cancel a GPS fix that is still waiting to focus the map.
            if mapView.gestureRecognizers?.contains(where: {
                $0.state == .began || $0.state == .changed
            }) == true {
                pendingRecenterRequest = nil
                pendingOverviewCoordinates = []
                routeCameraMode = .browsing
                onUserInteraction()
            }
            onMapMotionChanged(true)
        }

        func mapViewRegionIsChanging(_ mapView: MLNMapView) {
            updateUserLocationSymbolHeading(on: mapView)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            updateUserLocationSymbolHeading(on: mapView)
            onMapMotionChanged(false)
            let center = mapView.centerCoordinate
            onCenterChanged(GeoCoordinate(latitude: center.latitude, longitude: center.longitude))
            requestIraqBuildings(on: mapView)
        }

        func updateRecenterRequest(_ request: MapRecenterRequest?, on mapView: MLNMapView, animated: Bool) {
            pendingRecenterRequest = request
            animateRecenter = animated
            applyPendingRecenter(on: mapView)
        }

        private func applyPendingRecenter(on mapView: MLNMapView) {
            guard !isNavigating, let request = pendingRecenterRequest,
                  request.id != lastAppliedRecenterID,
                  mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
            // Camera positioning does not require downloaded styles/tiles (makeUIView
            // sets the initial center the same way). Do not delay a user's tap for them.
            // Mark consumed before setCenter invokes region-change delegates.
            lastAppliedRecenterID = request.id
            pendingRecenterRequest = nil
            mapView.setCenter(request.coordinate.clCoordinate, zoomLevel: 15, animated: animateRecenter)
        }

        func updateRouteOverview(
            route: RoutePlan?,
            origin: GeoCoordinate?,
            destination: GeoCoordinate?,
            on mapView: MLNMapView,
            animated: Bool
        ) {
            guard RouteCameraPolicy.shouldFitOverview(
                mode: routeCameraMode, routeID: route?.id, lastFittedRouteID: lastOverviewRouteID
            ), let route else {
                pendingOverviewCoordinates = []
                return
            }
            pendingOverviewRouteID = route.id
            pendingOverviewCoordinates = route.coordinates + [origin, destination].compactMap { $0 }
            animateOverview = animated
            applyPendingRouteOverview(on: mapView)
        }

        private func applyPendingRouteOverview(on mapView: MLNMapView) {
            guard routeCameraMode == .overview,
                  let routeID = pendingOverviewRouteID, routeID != lastOverviewRouteID,
                  mapView.style != nil,
                  mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
            let coordinates = pendingOverviewCoordinates.filter {
                $0.latitude.isFinite && $0.longitude.isFinite && CLLocationCoordinate2DIsValid($0.clCoordinate)
            }
            guard coordinates.count >= 2,
                  let south = coordinates.map(\.latitude).min(),
                  let north = coordinates.map(\.latitude).max(),
                  let west = coordinates.map(\.longitude).min(),
                  let east = coordinates.map(\.longitude).max() else { return }
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: south - 0.0002, longitude: west - 0.0002),
                ne: CLLocationCoordinate2D(latitude: north + 0.0002, longitude: east + 0.0002)
            )
            let height = mapView.bounds.height
            let padding = UIEdgeInsets(
                top: min(height * 0.23, 210), left: 44,
                bottom: min(height * (isNavigating ? 0.22 : 0.36), 330), right: 76
            )
            lastOverviewRouteID = routeID
            pendingOverviewCoordinates = []
            pendingOverviewRouteID = nil
            // A flat, north-up overview keeps both endpoints and the full route visible.
            var camera = mapView.camera
            camera.pitch = 0
            camera.heading = 0
            mapView.setCamera(camera, animated: false)
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: padding, animated: animateOverview)
        }

        func mapViewDidFinishRenderingMap(_ mapView: MLNMapView, fullyRendered: Bool) {
            // The first fix can arrive before style loading or view layout.
            applyPendingRecenter(on: mapView)
            applyPendingRouteOverview(on: mapView)
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            if let userLocation = annotation as? MLNUserLocation {
                // Always render the arrow, including for previously saved icon choices.
                // Returning nil would show MapLibre's default location dot instead.
                let marker = UserLocationSymbolAnnotationView()
                userLocationSymbolView = marker
                latestUserLocationCourse = userLocation.location?.course
                latestUserLocationHeading = validCourse(userLocation.heading?.trueHeading)
                    ?? validCourse(userLocation.heading?.magneticHeading)
                latestUserLocationSpeed = userLocation.location?.speed
                updateUserLocationSymbolHeading(on: mapView)
                return marker
            }

            if annotation is ParkedCarAnnotation {
                let marker = MLNAnnotationView(reuseIdentifier: "ottu-parked-car-marker")
                marker.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
                marker.backgroundColor = .systemOrange
                marker.layer.cornerRadius = 22
                marker.layer.borderColor = UIColor.white.withAlphaComponent(0.98).cgColor
                marker.layer.borderWidth = 3
                marker.layer.shadowColor = UIColor.black.cgColor
                marker.layer.shadowOpacity = 0.24
                marker.layer.shadowRadius = 6
                marker.layer.shadowOffset = CGSize(width: 0, height: 3)
                marker.isAccessibilityElement = true
                marker.accessibilityLabel = annotation.title ?? nil

                let icon = UIImageView(image: UIImage(systemName: "car.fill"))
                icon.tintColor = .white
                icon.contentMode = .scaleAspectFit
                icon.frame = marker.bounds.insetBy(dx: 11, dy: 11)
                icon.isUserInteractionEnabled = false
                marker.addSubview(icon)
                parkedCarAnnotationView = marker
                updateParkedCarMarkerOffset(userLocationCoordinate: mapView.userLocation?.coordinate)
                return marker
            }

            if let alternative = annotation as? RouteAlternativeAnnotation {
                let marker = MLNAnnotationView(reuseIdentifier: "ottu-route-time-pill")
                marker.frame = CGRect(x: 0, y: 0, width: 76, height: 28)
                marker.backgroundColor = .clear
                marker.isAccessibilityElement = true
                marker.accessibilityLabel = alternative.title ?? nil

                let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                blur.frame = marker.bounds
                blur.layer.cornerRadius = 14
                blur.clipsToBounds = true
                blur.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
                blur.layer.borderWidth = 1
                marker.addSubview(blur)

                let label = UILabel(frame: marker.bounds.insetBy(dx: 7, dy: 1))
                label.text = alternative.title
                label.font = .systemFont(ofSize: 11, weight: .semibold)
                label.textColor = .label
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.75
                blur.contentView.addSubview(label)
                return marker
            }

            let marker = MLNAnnotationView(reuseIdentifier: "ottu-place-marker")
            marker.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
            marker.backgroundColor = .systemGreen
            marker.layer.cornerRadius = 18
            marker.layer.borderColor = UIColor.white.withAlphaComponent(0.96).cgColor
            marker.layer.borderWidth = 3
            marker.layer.shadowColor = UIColor.black.cgColor
            marker.layer.shadowOpacity = 0.2
            marker.layer.shadowRadius = 5
            marker.layer.shadowOffset = CGSize(width: 0, height: 2)
            marker.isAccessibilityElement = true
            marker.accessibilityLabel = annotation.title ?? nil

            let centerDot = UIView(frame: CGRect(x: 10, y: 10, width: 16, height: 16))
            centerDot.backgroundColor = .white
            centerDot.layer.cornerRadius = 8
            centerDot.isUserInteractionEnabled = false
            marker.addSubview(centerDot)

            if !UIAccessibility.isReduceMotionEnabled {
                marker.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
                UIView.animate(
                    withDuration: 0.42,
                    delay: 0,
                    usingSpringWithDamping: 0.62,
                    initialSpringVelocity: 0.45,
                    options: [.allowUserInteraction, .beginFromCurrentState]
                ) {
                    marker.transform = .identity
                }
            }
            return marker
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
            guard annotation is ParkedCarAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            onSelectParkedCar()
        }

        func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
            !(annotation is ParkedCarAnnotation)
        }

        func updateUserLocationSymbolHeading(on mapView: MLNMapView) {
            let navigationHeading = isNavigating ? validCourse(navigationCourse) : nil
            let course = navigationHeading ?? validCourse(latestUserLocationCourse)
                ?? validCourse(latestUserLocationHeading)
            let screenHeading = course.map {
                ($0 - mapView.camera.heading + 360).truncatingRemainder(dividingBy: 360)
            }
            userLocationSymbolView?.setScreenHeading(screenHeading)
            userLocationSymbolView?.setSpeed(
                latestUserLocationSpeed,
                reduceMotion: reduceUserLocationMotion || UIAccessibility.isReduceMotionEnabled
            )
        }

        private func validCourse(_ course: CLLocationDirection?) -> CLLocationDirection? {
            guard let course, course.isFinite, course >= 0, course <= 360 else { return nil }
            return course
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            updateParkedCarMarkerOffset(userLocationCoordinate: userLocation?.coordinate)
            latestUserLocationCourse = userLocation?.location?.course
            latestUserLocationHeading = validCourse(userLocation?.heading?.trueHeading)
                ?? validCourse(userLocation?.heading?.magneticHeading)
            latestUserLocationSpeed = userLocation?.location?.speed
            updateUserLocationSymbolHeading(on: mapView)
        }

        func updateSelectedPlaceAnnotation(_ place: Place?, on mapView: MLNMapView) {
            if let selectedPlaceAnnotation {
                mapView.removeAnnotation(selectedPlaceAnnotation)
                self.selectedPlaceAnnotation = nil
            }
            guard let place, !place.id.hasPrefix("focus-") else { return }
            let annotation = MLNPointAnnotation()
            annotation.coordinate = place.coordinate.clCoordinate
            annotation.title = place.name
            annotation.subtitle = place.subtitle.isEmpty ? nil : place.subtitle
            mapView.addAnnotation(annotation)
            selectedPlaceAnnotation = annotation
        }

        func updateParkedCarAnnotation(_ location: ParkedCarLocation?, title: String, on mapView: MLNMapView) {
            if location?.coordinate == lastParkedCarCoordinate, title == lastParkedCarTitle {
                return
            }
            if let parkedCarAnnotation {
                mapView.removeAnnotation(parkedCarAnnotation)
                self.parkedCarAnnotation = nil
                parkedCarAnnotationView = nil
            }
            lastParkedCarCoordinate = location?.coordinate
            lastParkedCarTitle = location == nil ? nil : title
            guard let location else { return }

            let annotation = ParkedCarAnnotation()
            annotation.coordinate = location.coordinate.clCoordinate
            annotation.title = title
            mapView.addAnnotation(annotation)
            parkedCarAnnotation = annotation
        }

        private func updateParkedCarMarkerOffset(userLocationCoordinate: CLLocationCoordinate2D?) {
            guard let marker = parkedCarAnnotationView,
                  let parkedCarAnnotation,
                  let userLocationCoordinate else {
                parkedCarAnnotationView?.centerOffset = .zero
                return
            }

            let parkedLocation = CLLocation(
                latitude: parkedCarAnnotation.coordinate.latitude,
                longitude: parkedCarAnnotation.coordinate.longitude
            )
            let currentLocation = CLLocation(
                latitude: userLocationCoordinate.latitude,
                longitude: userLocationCoordinate.longitude
            )
            marker.centerOffset = parkedLocation.distance(from: currentLocation) < 15
                ? CGVector(dx: 0, dy: -42)
                : .zero
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            let isDarkStyle = currentStyleURL == MapConfiguration.darkStyleURL
            applyFeatureColors(to: mapView.style, isDark: isDarkStyle)
            ensureBuildingExtrusion(in: mapView.style, isDark: isDarkStyle)
            applyCameraMode(is3D: is3D, to: mapView, animated: false)
            updateRoute(
                latestRoute,
                alternatives: latestAlternativeRoutes,
                labels: latestAlternativeLabels,
                on: mapView,
                force: true
            )
            applyNavigationCamera(on: mapView, animated: false)
            applyPendingRecenter(on: mapView)
            applyPendingRouteOverview(on: mapView)
            requestIraqBuildings(on: mapView, force: true)
        }

        func resetIraqBuildingLayers() {
            iraqBuildingsTask?.cancel()
            iraqBuildingsTask = nil
            lastIraqBuildingsRequestKey = nil
            appliedIraqBuildingFiles.removeAll()
            appliedIraqBuildings3D = nil
        }

        func requestIraqBuildings(on mapView: MLNMapView, force: Bool = false) {
            guard let manager = iraqBuildingsManager, mapView.style != nil else { return }
            let bounds = mapView.visibleCoordinateBounds
            let viewport = IraqBuildingViewport(
                west: bounds.sw.longitude,
                south: bounds.sw.latitude,
                east: bounds.ne.longitude,
                north: bounds.ne.latitude
            )
            let zoom = mapView.zoomLevel
            iraqBuildingsTask?.cancel()
            iraqBuildingsTask = Task { @MainActor [weak self, weak mapView, weak manager] in
                guard let self, let mapView, let manager else { return }
                let requestKey = [
                    manager.isVisible ? "on" : "off",
                    "\(manager.completedTileCount)",
                    "\(Int((zoom * 4).rounded()))",
                    "\(Int((viewport.west * 1000).rounded()))",
                    "\(Int((viewport.south * 1000).rounded()))",
                    "\(Int((viewport.east * 1000).rounded()))",
                    "\(Int((viewport.north * 1000).rounded()))",
                    self.is3D ? "3d" : "2d"
                ].joined(separator: ":")
                guard force || requestKey != self.lastIraqBuildingsRequestKey else { return }
                self.lastIraqBuildingsRequestKey = requestKey

                guard manager.isVisible,
                      manager.hasDownloadedTiles,
                      zoom >= IraqBuildingFootprintsManager.minimumDisplayZoom,
                      mapView.style != nil else {
                    if let style = mapView.style { self.removeIraqBuildingLayers(from: style) }
                    return
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                let files = await manager.visibleGeoJSONFiles(in: viewport, zoom: zoom)
                guard !Task.isCancelled, let currentStyle = mapView.style else { return }
                self.applyIraqBuildingFiles(
                    files,
                    is3D: self.is3D,
                    isDark: self.currentStyleURL == MapConfiguration.darkStyleURL,
                    to: currentStyle
                )
            }
        }

        private func applyIraqBuildingFiles(_ files: [String: URL], is3D: Bool, isDark: Bool, to style: MLNStyle) {
            if appliedIraqBuildings3D != is3D {
                removeIraqBuildingLayers(from: style)
            }
            let visibleKeys = Set(files.keys)
            for key in Array(appliedIraqBuildingFiles.keys) where !visibleKeys.contains(key) {
                removeIraqBuildingLayers(for: key, from: style)
            }

            for (key, url) in files {
                if appliedIraqBuildingFiles[key] == url { continue }
                removeIraqBuildingLayers(for: key, from: style)
                let sourceID = "ottu-iraq-buildings-source-\(key)"
                let source = MLNShapeSource(identifier: sourceID, url: url, options: nil)
                style.addSource(source)

                let fill = MLNFillStyleLayer(identifier: "ottu-iraq-buildings-fill-\(key)", source: source)
                let buildingColor = isDark
                    ? UIColor(red: 0.33, green: 0.37, blue: 0.35, alpha: 1)
                    : UIColor(red: 0.82, green: 0.85, blue: 0.82, alpha: 1)
                fill.fillColor = NSExpression(forConstantValue: buildingColor)
                fill.fillOpacity = NSExpression(forConstantValue: 0.58)
                insertIraqBuildingLayer(fill, into: style)

                let outline = MLNLineStyleLayer(identifier: "ottu-iraq-buildings-outline-\(key)", source: source)
                let outlineColor = isDark
                    ? UIColor(red: 0.22, green: 0.27, blue: 0.25, alpha: 0.65)
                    : UIColor(red: 0.55, green: 0.63, blue: 0.58, alpha: 0.65)
                outline.lineColor = NSExpression(forConstantValue: outlineColor)
                outline.lineWidth = NSExpression(forConstantValue: 0.45)
                insertIraqBuildingLayer(outline, into: style)

                if is3D {
                    let extrusion = MLNFillExtrusionStyleLayer(identifier: "ottu-iraq-buildings-3d-\(key)", source: source)
                    extrusion.fillExtrusionHeight = NSExpression(forKeyPath: "height")
                    extrusion.fillExtrusionBase = NSExpression(forConstantValue: 0)
                    let extrusionColor = isDark
                        ? UIColor(red: 0.31, green: 0.36, blue: 0.34, alpha: 1)
                        : UIColor(red: 0.78, green: 0.82, blue: 0.78, alpha: 1)
                    extrusion.fillExtrusionColor = NSExpression(forConstantValue: extrusionColor)
                    extrusion.fillExtrusionOpacity = NSExpression(forConstantValue: 0.86)
                    extrusion.predicate = NSPredicate(format: "height > 0")
                    insertIraqBuildingLayer(extrusion, into: style)
                }
                appliedIraqBuildingFiles[key] = url
            }
            appliedIraqBuildings3D = is3D
        }

        private func insertIraqBuildingLayer(_ layer: MLNStyleLayer, into style: MLNStyle) {
            if let firstSymbol = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
                style.insertLayer(layer, below: firstSymbol)
            } else {
                style.addLayer(layer)
            }
        }

        private func removeIraqBuildingLayers(from style: MLNStyle) {
            for key in Array(appliedIraqBuildingFiles.keys) {
                removeIraqBuildingLayers(for: key, from: style)
            }
            appliedIraqBuildingFiles.removeAll()
            appliedIraqBuildings3D = nil
        }

        private func removeIraqBuildingLayers(for key: String, from style: MLNStyle) {
            ["fill", "outline", "3d"].forEach { suffix in
                let identifier = "ottu-iraq-buildings-\(suffix)-\(key)"
                if let layer = style.layer(withIdentifier: identifier) { style.removeLayer(layer) }
            }
            let sourceID = "ottu-iraq-buildings-source-\(key)"
            if let source = style.source(withIdentifier: sourceID) { style.removeSource(source) }
            appliedIraqBuildingFiles.removeValue(forKey: key)
        }

        func applyCameraMode(is3D: Bool, to mapView: MLNMapView, animated: Bool) {
            self.is3D = is3D
            guard routeCameraMode != .browsing else { return }
            let isRouteOverview = routeCameraMode == .overview && latestRoute != nil
            let targetPitch: CGFloat = isNavigating && routeCameraMode == .following ? 58 : (isRouteOverview ? 0 : (is3D ? 40 : 0))
            guard abs(mapView.camera.pitch - targetPitch) > 0.5 else { return }
            var camera = mapView.camera
            camera.pitch = targetPitch
            mapView.setCamera(camera, animated: animated)
        }

        func updateNavigationCamera(
            isActive: Bool,
            mode: RouteCameraPolicy.Mode,
            coordinate: GeoCoordinate?,
            course: Double?,
            is3D: Bool,
            on mapView: MLNMapView,
            animated: Bool
        ) {
            let wasNavigating = isNavigating
            let needsCameraUpdate = isNavigating != isActive
                || routeCameraMode != mode
                || navigationCoordinate != coordinate
                || navigationCourse != course
            isNavigating = isActive
            routeCameraMode = mode
            navigationCoordinate = coordinate
            navigationCourse = course
            self.is3D = is3D
            applyCameraMode(is3D: is3D, to: mapView, animated: animated && needsCameraUpdate)
            guard isActive, mode == .following, needsCameraUpdate else { return }
            applyNavigationCamera(on: mapView, animated: animated && !wasNavigating)
        }

        private func applyNavigationCamera(on mapView: MLNMapView, animated: Bool) {
            guard isNavigating, routeCameraMode == .following, let coordinate = navigationCoordinate else { return }
            let targetZoom = min(mapView.maximumZoomLevel, max(mapView.minimumZoomLevel, 17.2))
            mapView.setZoomLevel(targetZoom, animated: false)
            var camera = mapView.camera
            camera.centerCoordinate = coordinate.clCoordinate
            camera.pitch = 58
            if let navigationCourse, navigationCourse >= 0 {
                camera.heading = navigationCourse
            }
            mapView.setCamera(camera, animated: animated)
        }

        private func applyFeatureColors(to style: MLNStyle?, isDark: Bool) {
            guard let style else { return }

            let building = isDark
                ? UIColor(red: 0.31, green: 0.34, blue: 0.33, alpha: 1)
                : UIColor(red: 0.86, green: 0.87, blue: 0.85, alpha: 1)
            let water = isDark
                ? UIColor(red: 0.23, green: 0.39, blue: 0.47, alpha: 1)
                : UIColor(red: 0.59, green: 0.78, blue: 0.86, alpha: 1)
            let park = isDark
                ? UIColor(red: 0.22, green: 0.34, blue: 0.28, alpha: 1)
                : UIColor(red: 0.65, green: 0.82, blue: 0.70, alpha: 1)
            let forest = isDark
                ? UIColor(red: 0.17, green: 0.28, blue: 0.22, alpha: 1)
                : UIColor(red: 0.43, green: 0.64, blue: 0.48, alpha: 1)
            let grass = isDark
                ? UIColor(red: 0.31, green: 0.39, blue: 0.28, alpha: 1)
                : UIColor(red: 0.73, green: 0.84, blue: 0.65, alpha: 1)
            let majorRoad = isDark
                ? UIColor(red: 0.40, green: 0.42, blue: 0.41, alpha: 1)
                : UIColor(red: 0.81, green: 0.77, blue: 0.71, alpha: 1)
            let primaryRoad = isDark
                ? UIColor(red: 0.33, green: 0.36, blue: 0.35, alpha: 1)
                : UIColor(red: 0.77, green: 0.78, blue: 0.75, alpha: 1)
            let localRoad = isDark
                ? UIColor(red: 0.26, green: 0.29, blue: 0.29, alpha: 1)
                : UIColor(red: 0.71, green: 0.74, blue: 0.73, alpha: 1)
            let aeroway = isDark
                ? UIColor(red: 0.40, green: 0.37, blue: 0.46, alpha: 1)
                : UIColor(red: 0.70, green: 0.64, blue: 0.78, alpha: 1)

            if isDark {
                let background = UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1)
                let label = UIColor(red: 0.88, green: 0.87, blue: 0.84, alpha: 1)
                for layer in style.layers {
                    if let backgroundLayer = layer as? MLNBackgroundStyleLayer {
                        backgroundLayer.backgroundColor = NSExpression(forConstantValue: background)
                    }
                    guard let symbolLayer = layer as? MLNSymbolStyleLayer,
                          symbolLayer.text != nil else { continue }
                    symbolLayer.textColor = NSExpression(forConstantValue: label)
                    symbolLayer.textHaloColor = NSExpression(forConstantValue: background)
                    symbolLayer.textHaloWidth = NSExpression(forConstantValue: 1.15)
                    symbolLayer.textHaloBlur = NSExpression(forConstantValue: 0.25)
                }
            }

            setFillColor(building, on: "building", in: style)
            setFillColor(water, on: "water", in: style)
            setFillColor(park, on: "park", in: style)
            setFillColor(park, on: "landuse_park", in: style)
            setFillColor(forest, on: "landcover_wood", in: style)
            setFillColor(grass, on: "landcover_grass", in: style)

            ["waterway", "waterway_river", "waterway_other", "waterway_tunnel"].forEach {
                setLineColor(water, on: $0, in: style)
            }
            ["road_motorway", "highway_motorway_inner"].forEach {
                setLineColor(majorRoad, on: $0, in: style)
                setLineOpacity(0.84, on: $0, in: style)
            }
            ["road_trunk_primary", "road_secondary_tertiary", "highway_major_inner"].forEach {
                setLineColor(primaryRoad, on: $0, in: style)
                setLineOpacity(0.72, on: $0, in: style)
            }
            ["road_minor", "road_service_track", "highway_minor", "highway_path"].forEach {
                setLineColor(localRoad, on: $0, in: style)
                setLineOpacity(0.52, on: $0, in: style)
                setLineWidth(0.65, on: $0, in: style)
            }
            ["aeroway_fill", "aeroway-area"].forEach {
                setFillColor(aeroway, on: $0, in: style)
            }
            ["aeroway_runway", "aeroway_taxiway", "aeroway-runway", "aeroway-taxiway"].forEach {
                setLineColor(aeroway, on: $0, in: style)
            }

            if let extrusion = style.layer(withIdentifier: "building-3d") as? MLNFillExtrusionStyleLayer {
                extrusion.fillExtrusionColor = NSExpression(forConstantValue: building)
            }
        }

        private func setFillColor(_ color: UIColor, on identifier: String, in style: MLNStyle) {
            guard let layer = style.layer(withIdentifier: identifier) as? MLNFillStyleLayer else { return }
            layer.fillColor = NSExpression(forConstantValue: color)
        }

        private func setLineColor(_ color: UIColor, on identifier: String, in style: MLNStyle) {
            guard let layer = style.layer(withIdentifier: identifier) as? MLNLineStyleLayer else { return }
            layer.lineColor = NSExpression(forConstantValue: color)
        }

        private func setLineOpacity(_ opacity: Double, on identifier: String, in style: MLNStyle) {
            guard let layer = style.layer(withIdentifier: identifier) as? MLNLineStyleLayer else { return }
            layer.lineOpacity = NSExpression(forConstantValue: opacity)
        }

        private func setLineWidth(_ width: Double, on identifier: String, in style: MLNStyle) {
            guard let layer = style.layer(withIdentifier: identifier) as? MLNLineStyleLayer else { return }
            layer.lineWidth = NSExpression(forConstantValue: width)
        }

        private func ensureBuildingExtrusion(in style: MLNStyle?, isDark: Bool) {
            guard let style,
                  style.layer(withIdentifier: "building-3d") == nil,
                  style.layer(withIdentifier: "ottu-building-extrusion") == nil,
                  let source = style.source(withIdentifier: "openmaptiles"),
                  let buildingLayer = style.layer(withIdentifier: "building") else { return }

            let extrusion = MLNFillExtrusionStyleLayer(identifier: "ottu-building-extrusion", source: source)
            extrusion.sourceLayerIdentifier = "building"
            extrusion.fillExtrusionBase = NSExpression(forKeyPath: "render_min_height")
            extrusion.fillExtrusionHeight = NSExpression(forKeyPath: "render_height")
            let buildingColor = isDark
                ? UIColor(red: 0.31, green: 0.34, blue: 0.33, alpha: 1)
                : UIColor(red: 0.86, green: 0.87, blue: 0.85, alpha: 1)
            extrusion.fillExtrusionColor = NSExpression(forConstantValue: buildingColor)
            extrusion.fillExtrusionOpacity = NSExpression(forConstantValue: 0.92)
            style.insertLayer(extrusion, above: buildingLayer)
        }

        func updateRoute(
            _ route: RoutePlan?,
            alternatives: [RoutePlan] = [],
            labels: [UUID: String] = [:],
            on mapView: MLNMapView,
            force: Bool = false
        ) {
            latestRoute = route
            latestAlternativeRoutes = alternatives
            latestAlternativeLabels = labels
            guard let style = mapView.style else { return }
            let routeIDs = ([route].compactMap { $0 } + alternatives).map { $0.id.uuidString }
            let labelSignature = labels.keys.sorted { $0.uuidString < $1.uuidString }
                .map { "\($0.uuidString):\(labels[$0] ?? "")" }
                .joined(separator: ",")
            let signature = "\(routeIDs.joined(separator: ","))|\(labelSignature)"
            if !force, signature == appliedRouteSignature { return }
            removeRouteLayers(from: style, on: mapView)
            appliedRouteSignature = signature

            for (index, alternative) in alternatives.enumerated() where alternative.coordinates.count >= 2 {
                var coordinates = alternative.coordinates.map(\.clCoordinate)
                let line = MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
                let sourceID = "ottu-route-alternative-source-\(index)"
                let layerID = "ottu-route-alternative-line-\(index)"
                let source = MLNShapeSource(identifier: sourceID, features: [line], options: nil)
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.lineColor = NSExpression(forConstantValue: UIColor.systemTeal.withAlphaComponent(0.48))
                layer.lineWidth = NSExpression(forConstantValue: 5)
                layer.lineCap = NSExpression(forConstantValue: "round")
                layer.lineJoin = NSExpression(forConstantValue: "round")
                style.addSource(source)
                style.addLayer(layer)
                routeSourceIdentifiers.append(sourceID)
                routeLayerIdentifiers.append(layerID)

                let annotation = RouteAlternativeAnnotation()
                annotation.coordinate = alternative.coordinates[alternative.coordinates.count / 2].clCoordinate
                annotation.title = labels[alternative.id] ?? ""
                mapView.addAnnotation(annotation)
                routeAlternativeAnnotations.append(annotation)
            }
            guard let route, route.coordinates.count >= 2 else { return }

            var fullCoordinates = route.coordinates.map(\.clCoordinate)
            let fullLine = MLNPolylineFeature(coordinates: &fullCoordinates, count: UInt(fullCoordinates.count))
            let fullSource = MLNShapeSource(identifier: "ottu-route-source", features: [fullLine], options: nil)
            style.addSource(fullSource)
            routeSourceIdentifiers.append("ottu-route-source")

            let glow = MLNLineStyleLayer(identifier: "ottu-route-glow", source: fullSource)
            glow.lineColor = NSExpression(forConstantValue: UIColor.systemBlue.withAlphaComponent(0.22))
            glow.lineWidth = NSExpression(forConstantValue: 14)
            glow.lineCap = NSExpression(forConstantValue: "round")
            glow.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(glow)
            routeLayerIdentifiers.append("ottu-route-glow")

            let casing = MLNLineStyleLayer(identifier: "ottu-route-casing", source: fullSource)
            casing.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.92))
            casing.lineWidth = NSExpression(forConstantValue: 8.5)
            casing.lineCap = NSExpression(forConstantValue: "round")
            casing.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(casing)
            routeLayerIdentifiers.append("ottu-route-casing")

            let edgeCount = route.coordinates.count - 1
            let segmentCount = min(18, edgeCount)
            for segmentIndex in 0..<segmentCount {
                let startIndex = segmentIndex * edgeCount / segmentCount
                let endIndex = (segmentIndex + 1) * edgeCount / segmentCount
                guard endIndex > startIndex else { continue }
                var segmentCoordinates = Array(route.coordinates[startIndex...endIndex]).map(\.clCoordinate)
                let segmentLine = MLNPolylineFeature(coordinates: &segmentCoordinates, count: UInt(segmentCoordinates.count))
                let sourceID = "ottu-route-gradient-source-\(segmentIndex)"
                let layerID = "ottu-route-gradient-\(segmentIndex)"
                let source = MLNShapeSource(identifier: sourceID, features: [segmentLine], options: nil)
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.lineColor = NSExpression(forConstantValue: gradientColor(at: Double(segmentIndex) / Double(max(1, segmentCount - 1))))
                layer.lineWidth = NSExpression(forConstantValue: 5.5)
                layer.lineCap = NSExpression(forConstantValue: "round")
                layer.lineJoin = NSExpression(forConstantValue: "round")
                style.addSource(source)
                style.addLayer(layer)
                routeSourceIdentifiers.append(sourceID)
                routeLayerIdentifiers.append(layerID)
            }
        }

        private func removeRouteLayers(from style: MLNStyle, on mapView: MLNMapView) {
            if !routeAlternativeAnnotations.isEmpty {
                routeAlternativeAnnotations.forEach { mapView.removeAnnotation($0) }
                routeAlternativeAnnotations.removeAll()
            }
            for identifier in routeLayerIdentifiers {
                if let layer = style.layer(withIdentifier: identifier) { style.removeLayer(layer) }
            }
            for identifier in routeSourceIdentifiers {
                if let source = style.source(withIdentifier: identifier) { style.removeSource(source) }
            }
            routeLayerIdentifiers.removeAll()
            routeSourceIdentifiers.removeAll()
        }

        private func gradientColor(at position: Double) -> UIColor {
            let stops: [(Double, UIColor)] = [
                (0, UIColor(red: 0.12, green: 0.43, blue: 0.98, alpha: 1)),
                (0.5, UIColor(red: 0.12, green: 0.78, blue: 0.96, alpha: 1)),
                (1, UIColor(red: 0.27, green: 0.88, blue: 0.70, alpha: 1))
            ]
            let clamped = min(max(position, 0), 1)
            let pair = clamped <= 0.5 ? (stops[0], stops[1]) : (stops[1], stops[2])
            let local = (clamped - pair.0.0) / (pair.1.0 - pair.0.0)
            var startRed: CGFloat = 0
            var startGreen: CGFloat = 0
            var startBlue: CGFloat = 0
            var endRed: CGFloat = 0
            var endGreen: CGFloat = 0
            var endBlue: CGFloat = 0
            pair.0.1.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: nil)
            pair.1.1.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: nil)
            let fraction = CGFloat(local)
            return UIColor(
                red: startRed + (endRed - startRed) * fraction,
                green: startGreen + (endGreen - startGreen) * fraction,
                blue: startBlue + (endBlue - startBlue) * fraction,
                alpha: 1
            )
        }
    }
}
