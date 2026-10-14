import Foundation

protocol PlaceSearchProviding: Sendable {
    func search(_ query: String, near coordinate: GeoCoordinate, language: String) async throws -> [Place]
}

struct PhotonPlaceSearchService: PlaceSearchProviding {
    private let endpoint = URL(string: "https://photon.komoot.io/api/")!

    func search(_ query: String, near coordinate: GeoCoordinate, language: String) async throws -> [Place] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "limit", value: "8")
        ]
        // Photon currently supports only default, de, en, and fr. Sending ar/ku
        // makes the API return HTTP 400 even though the device is online.
        if ["de", "en", "fr"].contains(language) {
            queryItems.append(URLQueryItem(name: "lang", value: language))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw SearchError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SearchError.badResponse
        }

        let result = try JSONDecoder().decode(PhotonResponse.self, from: data)
        return result.features.compactMap { feature in
            guard feature.geometry.coordinates.count >= 2 else { return nil }
            let properties = feature.properties
            let name = properties.name ?? properties.street ?? properties.city ?? properties.state
            guard let name, !name.isEmpty else { return nil }

            let osmID = properties.osmID.map(String.init) ?? UUID().uuidString
            let osmType = properties.osmType ?? "photon"
            return Place(
                id: "\(osmType)-\(osmID)",
                name: name,
                street: properties.street,
                city: properties.city ?? properties.state,
                country: properties.country,
                coordinate: GeoCoordinate(
                    latitude: feature.geometry.coordinates[1],
                    longitude: feature.geometry.coordinates[0]
                )
            )
        }
    }
}

enum SearchError: LocalizedError {
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not create the search URL."
        case .badResponse: return "The search service returned an invalid response."
        }
    }
}

private struct PhotonResponse: Decodable {
    let features: [Feature]

    struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }

    struct Geometry: Decodable {
        let coordinates: [Double]
    }

    struct Properties: Decodable {
        let name: String?
        let street: String?
        let city: String?
        let state: String?
        let country: String?
        let osmID: Int?
        let osmType: String?

        enum CodingKeys: String, CodingKey {
            case name, street, city, state, country
            case osmID = "osm_id"
            case osmType = "osm_type"
        }
    }
}
