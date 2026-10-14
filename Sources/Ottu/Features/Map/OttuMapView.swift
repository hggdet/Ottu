import CoreLocation
import MapLibre
import SwiftUI
import UIKit

struct OttuMapView: UIViewRepresentable {
    let selectedPlace: Place?
    let route: RoutePlan?
    let styleURL: URL
    let is3D: Bool
    @ObservedObject var iraqBuildingsManager: IraqBuildingFootprintsManager
    let onLongPress: (GeoCoordinate) -> Void
    let onCenterChanged: (GeoCoordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLongPress: onLongPress,
            onCenterChanged: onCenterChanged,
            iraqBuildingsManager: iraqBuildingsManager
        )
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
        context.coordinator.iraqBuildingsManager = iraqBuildingsManager
        if context.coordinator.currentStyleURL != styleURL {
            mapView.styleURL = styleURL
            context.coordinator.currentStyleURL = styleURL
            context.coordinator.appliedRouteID = nil
            context.coordinator.resetIraqBuildingLayers()
        }
        context.coordinator.applyCameraMode(is3D: is3D, to: mapView, animated: true)
        if let selectedPlace, context.coordinator.lastSelectedPlaceID != selectedPlace.id {
            context.coordinator.lastSelectedPlaceID = selectedPlace.id
            mapView.setCenter(selectedPlace.coordinate.clCoordinate, zoomLevel: 15, animated: true)
        }
        context.coordinator.updateRoute(route, on: mapView)
        context.coordinator.requestIraqBuildings(on: mapView)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var lastSelectedPlaceID: String?
        var currentStyleURL: URL?
        var appliedRouteID: UUID?
        var latestRoute: RoutePlan?
        var is3D = false
        var onLongPress: (GeoCoordinate) -> Void
        var onCenterChanged: (GeoCoordinate) -> Void
        weak var iraqBuildingsManager: IraqBuildingFootprintsManager?
        private var iraqBuildingsTask: Task<Void, Never>?
        private var lastIraqBuildingsRequestKey: String?
        private var appliedIraqBuildingFiles: [String: URL] = [:]
        private var appliedIraqBuildings3D: Bool?

        init(
            onLongPress: @escaping (GeoCoordinate) -> Void,
            onCenterChanged: @escaping (GeoCoordinate) -> Void,
            iraqBuildingsManager: IraqBuildingFootprintsManager
        ) {
            self.onLongPress = onLongPress
            self.onCenterChanged = onCenterChanged
            self.iraqBuildingsManager = iraqBuildingsManager
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
            requestIraqBuildings(on: mapView)
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            applyFeatureColors(to: mapView.style)
            ensureBuildingExtrusion(in: mapView.style)
            applyCameraMode(is3D: is3D, to: mapView, animated: false)
            updateRoute(latestRoute, on: mapView, force: true)
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
                self.applyIraqBuildingFiles(files, is3D: self.is3D, to: currentStyle)
            }
        }

        private func applyIraqBuildingFiles(_ files: [String: URL], is3D: Bool, to style: MLNStyle) {
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
                fill.fillColor = NSExpression(forConstantValue: UIColor(red: 0.94, green: 0.48, blue: 0.24, alpha: 1))
                fill.fillOpacity = NSExpression(forConstantValue: 0.72)
                insertIraqBuildingLayer(fill, into: style)

                let outline = MLNLineStyleLayer(identifier: "ottu-iraq-buildings-outline-\(key)", source: source)
                outline.lineColor = NSExpression(forConstantValue: UIColor(red: 0.56, green: 0.25, blue: 0.14, alpha: 0.8))
                outline.lineWidth = NSExpression(forConstantValue: 0.55)
                insertIraqBuildingLayer(outline, into: style)

                if is3D {
                    let extrusion = MLNFillExtrusionStyleLayer(identifier: "ottu-iraq-buildings-3d-\(key)", source: source)
                    extrusion.fillExtrusionHeight = NSExpression(forKeyPath: "height")
                    extrusion.fillExtrusionBase = NSExpression(forConstantValue: 0)
                    extrusion.fillExtrusionColor = NSExpression(forConstantValue: UIColor(red: 0.91, green: 0.43, blue: 0.22, alpha: 1))
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
            let targetPitch: CGFloat = is3D ? 48 : 0
            guard abs(mapView.camera.pitch - targetPitch) > 0.5 else { return }
            var camera = mapView.camera
            camera.pitch = targetPitch
            mapView.setCamera(camera, animated: animated)
        }

        private func applyFeatureColors(to style: MLNStyle?) {
            guard let style else { return }

            let building = UIColor(red: 0.91, green: 0.56, blue: 0.31, alpha: 1)
            let water = UIColor(red: 0.20, green: 0.60, blue: 0.91, alpha: 1)
            let park = UIColor(red: 0.31, green: 0.71, blue: 0.47, alpha: 1)
            let forest = UIColor(red: 0.16, green: 0.48, blue: 0.32, alpha: 1)
            let grass = UIColor(red: 0.61, green: 0.80, blue: 0.39, alpha: 1)
            let majorRoad = UIColor(red: 0.97, green: 0.49, blue: 0.25, alpha: 1)
            let primaryRoad = UIColor(red: 0.98, green: 0.70, blue: 0.28, alpha: 1)
            let localRoad = UIColor(red: 0.80, green: 0.84, blue: 0.88, alpha: 1)
            let aeroway = UIColor(red: 0.68, green: 0.48, blue: 0.86, alpha: 1)

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
            }
            ["road_trunk_primary", "road_secondary_tertiary", "highway_major_inner"].forEach {
                setLineColor(primaryRoad, on: $0, in: style)
            }
            ["road_minor", "road_service_track", "highway_minor", "highway_path"].forEach {
                setLineColor(localRoad, on: $0, in: style)
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

        private func ensureBuildingExtrusion(in style: MLNStyle?) {
            guard let style,
                  style.layer(withIdentifier: "building-3d") == nil,
                  style.layer(withIdentifier: "ottu-building-extrusion") == nil,
                  let source = style.source(withIdentifier: "openmaptiles"),
                  let buildingLayer = style.layer(withIdentifier: "building") else { return }

            let extrusion = MLNFillExtrusionStyleLayer(identifier: "ottu-building-extrusion", source: source)
            extrusion.sourceLayerIdentifier = "building"
            extrusion.fillExtrusionBase = NSExpression(forKeyPath: "render_min_height")
            extrusion.fillExtrusionHeight = NSExpression(forKeyPath: "render_height")
            extrusion.fillExtrusionColor = NSExpression(forConstantValue: UIColor(red: 0.91, green: 0.56, blue: 0.31, alpha: 1))
            extrusion.fillExtrusionOpacity = NSExpression(forConstantValue: 0.92)
            style.insertLayer(extrusion, above: buildingLayer)
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
