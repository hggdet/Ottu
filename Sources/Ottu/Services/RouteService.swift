import Foundation

struct RoutePlan: Identifiable, Sendable {
    let id = UUID()
    let coordinates: [GeoCoordinate]
    let distanceMeters: Double
    let durationSeconds: Double

    var distanceKilometers: Double { distanceMeters / 1_000 }
    var durationMinutes: Int { Int((durationSeconds / 60).rounded()) }
}

protocol RoutingProviding: Sendable {
    func route(from origin: GeoCoordinate, to destination: GeoCoordinate) async throws -> RoutePlan
}

struct OSRMRouteService: RoutingProviding {
    private let baseURL = URL(string: "https://router.project-osrm.org/route/v1/driving/")!

    func route(from origin: GeoCoordinate, to destination: GeoCoordinate) async throws -> RoutePlan {
        var components = URLComponents(url: URL(string: "\(baseURL)\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)")!, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "geometries", value: "geojson"),
            URLQueryItem(name: "steps", value: "false")
        ]
        guard let url = components?.url else { throw RouteError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RouteError.badResponse
        }
        let result = try JSONDecoder().decode(OSRMResponse.self, from: data)
        guard result.code == "Ok", let route = result.routes.first else { throw RouteError.noRoute }
        let coordinates = route.geometry.coordinates.compactMap { pair -> GeoCoordinate? in
            guard pair.count >= 2 else { return nil }
            return GeoCoordinate(latitude: pair[1], longitude: pair[0])
        }
        guard coordinates.count >= 2 else { throw RouteError.noRoute }
        return RoutePlan(coordinates: coordinates, distanceMeters: route.distance, durationSeconds: route.duration)
    }
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
}

private struct OSRMGeometry: Decodable {
    let coordinates: [[Double]]
}
