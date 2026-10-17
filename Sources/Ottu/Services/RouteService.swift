import CoreLocation
import Foundation

enum RouteTransportMode: String, CaseIterable, Codable, Sendable {
    case driving
    case walking
    case cycling

    var localizationKey: String {
        switch self {
        case .driving: "directions.mode.car"
        case .walking: "directions.mode.walking"
        case .cycling: "directions.mode.cycling"
        }
    }

    var systemImage: String {
        switch self {
        case .driving: "car.fill"
        case .walking: "figure.walk"
        case .cycling: "bicycle"
        }
    }

    fileprivate var endpoint: URL {
        switch self {
        case .driving:
            URL(string: "https://router.project-osrm.org/route/v1/driving/")!
        case .walking:
            URL(string: "https://routing.openstreetmap.de/routed-foot/route/v1/driving/")!
        case .cycling:
            URL(string: "https://routing.openstreetmap.de/routed-bike/route/v1/driving/")!
        }
    }
}

struct RouteStep: Identifiable, Sendable {
    let distanceFromStartMeters: Double
    let maneuverType: String
    let maneuverModifier: String?
    let streetName: String?
    let coordinate: GeoCoordinate?

    var id: String { "\(Int(distanceFromStartMeters.rounded()))-\(maneuverType)-\(maneuverModifier ?? "")" }

    var instructionLocalizationKey: String {
        if maneuverType == "arrive" { return "navigation.maneuver.arrive" }
        if maneuverType == "depart" { return "navigation.maneuver.continue" }
        if ["roundabout", "rotary"].contains(maneuverType) { return "navigation.maneuver.roundabout" }
        if maneuverType == "merge" { return "navigation.maneuver.merge" }
        if ["ramp", "on ramp"].contains(maneuverType) { return "navigation.maneuver.ramp" }
        if maneuverType == "off ramp" || maneuverType == "exit roundabout" { return "navigation.maneuver.exit" }
        if maneuverType == "fork" { return "navigation.maneuver.fork" }

        switch maneuverModifier?.lowercased() {
        case "sharp left": return "navigation.maneuver.sharp_left"
        case "slight left": return "navigation.maneuver.slight_left"
        case "left": return "navigation.maneuver.left"
        case "sharp right": return "navigation.maneuver.sharp_right"
        case "slight right": return "navigation.maneuver.slight_right"
        case "right": return "navigation.maneuver.right"
        case "uturn": return "navigation.maneuver.uturn"
        case "straight": return "navigation.maneuver.continue"
        default: return "navigation.maneuver.continue"
        }
    }
}

struct RoutePlan: Identifiable, Sendable {
    let id: UUID
    let coordinates: [GeoCoordinate]
    let distanceMeters: Double
    let durationSeconds: Double
    let steps: [RouteStep]

    init(
        id: UUID = UUID(),
        coordinates: [GeoCoordinate],
        distanceMeters: Double,
        durationSeconds: Double,
        steps: [RouteStep] = []
    ) {
        self.id = id
        self.coordinates = coordinates
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.steps = steps
    }

    var distanceKilometers: Double { distanceMeters / 1_000 }
    var durationMinutes: Int { Int((durationSeconds / 60).rounded()) }

    func distanceFromRouteMeters(near position: GeoCoordinate) -> Double {
        nearestRouteProjection(near: position)?.distance ?? .infinity
    }

    func progressMeters(near position: GeoCoordinate) -> Double {
        guard distanceMeters > 0,
              let projection = nearestRouteProjection(near: position),
              projection.distance <= 250 else { return 0 }
        return min(distanceMeters, max(0, distanceMeters * projection.fraction))
    }

    func coordinate(atProgressMeters progressMeters: Double) -> GeoCoordinate? {
        guard coordinates.count >= 2, distanceMeters > 0 else { return coordinates.first }
        let segmentLengths = zip(coordinates, coordinates.dropFirst()).map { pair -> Double in
            let start = pair.0
            let end = pair.1
            let meanLatitude = (start.latitude + end.latitude) / 2
            let dx = (end.longitude - start.longitude) * 111_320 * cos(meanLatitude * .pi / 180)
            let dy = (end.latitude - start.latitude) * 111_320
            return hypot(dx, dy)
        }
        let geometryLength = segmentLengths.reduce(0, +)
        guard geometryLength > 0 else { return coordinates.first }
        let target = geometryLength * min(1, max(0, progressMeters / distanceMeters))
        var traversed = 0.0
        for (index, segmentLength) in segmentLengths.enumerated() {
            if target <= traversed + segmentLength || index == segmentLengths.count - 1 {
                let fraction = segmentLength > 0 ? min(1, max(0, (target - traversed) / segmentLength)) : 0
                let start = coordinates[index]
                let end = coordinates[index + 1]
                return GeoCoordinate(
                    latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                    longitude: start.longitude + (end.longitude - start.longitude) * fraction
                )
            }
            traversed += segmentLength
        }
        return coordinates.last
    }

    private func nearestRouteProjection(near position: GeoCoordinate) -> (distance: Double, fraction: Double)? {
        guard coordinates.count > 1 else { return nil }
        let metersPerDegree = 111_320.0
        var totalGeometryMeters = 0.0
        var nearestDistance = Double.greatestFiniteMagnitude
        var nearestProgressMeters = 0.0

        for index in 1..<coordinates.count {
            let start = coordinates[index - 1]
            let end = coordinates[index]
            let meanLatitude = (start.latitude + end.latitude + position.latitude) / 3
            let longitudeScale = metersPerDegree * cos(meanLatitude * .pi / 180)
            let dx = (end.longitude - start.longitude) * longitudeScale
            let dy = (end.latitude - start.latitude) * metersPerDegree
            let segmentLength = hypot(dx, dy)
            guard segmentLength > 0 else { continue }

            let pointX = (position.longitude - start.longitude) * longitudeScale
            let pointY = (position.latitude - start.latitude) * metersPerDegree
            let projection = min(1, max(0, (pointX * dx + pointY * dy) / (segmentLength * segmentLength)))
            let distance = hypot(pointX - projection * dx, pointY - projection * dy)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestProgressMeters = totalGeometryMeters + projection * segmentLength
            }
            totalGeometryMeters += segmentLength
        }

        guard totalGeometryMeters > 0 else { return nil }
        return (nearestDistance, nearestProgressMeters / totalGeometryMeters)
    }

    func nextStep(after progressMeters: Double) -> RouteStep? {
        steps.first {
            $0.maneuverType != "depart" && $0.distanceFromStartMeters > progressMeters + 8
        }
    }
}

protocol RoutingProviding: Sendable {
    func routes(
        from origin: GeoCoordinate,
        to destination: GeoCoordinate,
        mode: RouteTransportMode,
        alternatives: Bool,
        waypoints: [GeoCoordinate]
    ) async throws -> [RoutePlan]
}

extension RoutingProviding {
    func route(from origin: GeoCoordinate, to destination: GeoCoordinate) async throws -> RoutePlan {
        guard let route = try await routes(
            from: origin,
            to: destination,
            mode: .driving,
            alternatives: false,
            waypoints: []
        ).first else { throw RouteError.noRoute }
        return route
    }
}

struct OSRMRouteService: RoutingProviding {
    func routes(
        from origin: GeoCoordinate,
        to destination: GeoCoordinate,
        mode: RouteTransportMode,
        alternatives: Bool = true,
        waypoints: [GeoCoordinate] = []
    ) async throws -> [RoutePlan] {
        let orderedCoordinates = [origin] + waypoints + [destination]
        let coordinatePath = orderedCoordinates.map { "\($0.longitude),\($0.latitude)" }.joined(separator: ";")
        var components = URLComponents(url: URL(string: "\(mode.endpoint)\(coordinatePath)")!, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "alternatives", value: alternatives ? "true" : "false"),
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "geometries", value: "geojson"),
            URLQueryItem(name: "steps", value: "true")
        ]
        guard let url = components?.url else { throw RouteError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RouteError.badResponse
        }
        let result = try JSONDecoder().decode(OSRMResponse.self, from: data)
        guard result.code == "Ok" else { throw RouteError.noRoute }
        let plans = result.routes.compactMap { route -> RoutePlan? in
            let coordinates = route.geometry.coordinates.compactMap { pair -> GeoCoordinate? in
                guard pair.count >= 2 else { return nil }
                return GeoCoordinate(latitude: pair[1], longitude: pair[0])
            }
            guard coordinates.count >= 2 else { return nil }

            var distanceFromStart = 0.0
            let steps = route.legs.flatMap(\.steps).map { step -> RouteStep in
                let stepCoordinate: GeoCoordinate?
                if let location = step.maneuver.location, location.count >= 2 {
                    stepCoordinate = GeoCoordinate(latitude: location[1], longitude: location[0])
                } else {
                    stepCoordinate = nil
                }
                let item = RouteStep(
                    distanceFromStartMeters: distanceFromStart,
                    maneuverType: step.maneuver.type,
                    maneuverModifier: step.maneuver.modifier,
                    streetName: step.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    coordinate: stepCoordinate
                )
                distanceFromStart += step.distance
                return item
            }
            return RoutePlan(coordinates: coordinates, distanceMeters: route.distance, durationSeconds: route.duration, steps: steps)
        }
        guard !plans.isEmpty else { throw RouteError.noRoute }
        return plans
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum RouteError: LocalizedError {
    case invalidURL
    case badResponse
    case noRoute

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid route request."
        case .badResponse: return "The routing service returned an error."
        case .noRoute: return "No route was found between these locations."
        }
    }
}

private struct OSRMResponse: Decodable {
    let code: String
    let routes: [OSRMRoute]
}

private struct OSRMRoute: Decodable {
    let distance: Double
    let duration: Double
    let geometry: OSRMGeometry
    let legs: [OSRMLeg]
}

private struct OSRMLeg: Decodable {
    let steps: [OSRMStep]
}

private struct OSRMStep: Decodable {
    let distance: Double
    let name: String?
    let maneuver: OSRMManeuver
}

private struct OSRMManeuver: Decodable {
    let type: String
    let modifier: String?
    let location: [Double]?
}

private struct OSRMGeometry: Decodable {
    let coordinates: [[Double]]
}
