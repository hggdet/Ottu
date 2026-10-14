import CoreLocation
import MapLibre
import SwiftUI
import UIKit

struct OttuMapView: UIViewRepresentable {
    let selectedPlace: Place?
    let route: RoutePlan?
    let styleURL: URL
    let onLongPress: (GeoCoordinate) -> Void
    let onCenterChanged: (GeoCoordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress, onCenterChanged: onCenterChanged)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        context.coordinator.currentStyleURL = styleURL
        mapView.delegate = context.coordinator
        mapView.compassView.isHidden = true
        mapView.showsAttributionButton = false
        mapView.showsLogoView = false
        mapView.showsUserLocation = true
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
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onCenterChanged = onCenterChanged
        if context.coordinator.currentStyleURL != styleURL {
            mapView.styleURL = styleURL
            context.coordinator.currentStyleURL = styleURL
            context.coordinator.appliedRouteID = nil
        }
        if let selectedPlace, context.coordinator.lastSelectedPlaceID != selectedPlace.id {
            context.coordinator.lastSelectedPlaceID = selectedPlace.id
            mapView.setCenter(selectedPlace.coordinate.clCoordinate, zoomLevel: 15, animated: true)
        }
        context.coordinator.updateRoute(route, on: mapView)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var lastSelectedPlaceID: String?
        var currentStyleURL: URL?
        var appliedRouteID: UUID?
        var latestRoute: RoutePlan?
        var onLongPress: (GeoCoordinate) -> Void
        var onCenterChanged: (GeoCoordinate) -> Void

        init(onLongPress: @escaping (GeoCoordinate) -> Void, onCenterChanged: @escaping (GeoCoordinate) -> Void) {
            self.onLongPress = onLongPress
            self.onCenterChanged = onCenterChanged
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MLNMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress(GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.centerCoordinate
            onCenterChanged(GeoCoordinate(latitude: center.latitude, longitude: center.longitude))
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            updateRoute(latestRoute, on: mapView, force: true)
        }

        func updateRoute(_ route: RoutePlan?, on mapView: MLNMapView, force: Bool = false) {
            latestRoute = route
            guard let style = mapView.style else { return }
            if !force, route?.id == appliedRouteID { return }

            if style.layer(withIdentifier: "ottu-route-line") != nil {
                style.removeLayer(style.layer(withIdentifier: "ottu-route-line")!)
            }
            if style.source(withIdentifier: "ottu-route-source") != nil {
                style.removeSource(style.source(withIdentifier: "ottu-route-source")!)
            }
            appliedRouteID = route?.id
            guard let route, route.coordinates.count >= 2 else { return }

            var coordinates = route.coordinates.map(\.clCoordinate)
            let line = MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
            let source = MLNShapeSource(identifier: "ottu-route-source", features: [line], options: nil)
            let layer = MLNLineStyleLayer(identifier: "ottu-route-line", source: source)
            layer.lineColor = NSExpression(forConstantValue: UIColor.systemBlue)
            layer.lineWidth = NSExpression(forConstantValue: 5)
            layer.lineCap = NSExpression(forConstantValue: "round")
            layer.lineJoin = NSExpression(forConstantValue: "round")
            style.addSource(source)
            style.addLayer(layer)
        }
    }
}
