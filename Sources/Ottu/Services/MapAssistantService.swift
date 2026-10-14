import CoreLocation
import Foundation

protocol MapAssistantProviding: Sendable {
    func nearbyPlaces(
        for category: AssistantPlaceCategory,
        near coordinate: GeoCoordinate,
        language: String
    ) async throws -> [Place]

    func weather(at coordinate: GeoCoordinate) async throws -> AssistantWeather
    func nearbyStreet(at coordinate: GeoCoordinate, language: String) async throws -> String?
}

enum AssistantPlaceCategory: String, CaseIterable, Identifiable, Sendable {
    case pharmacy
    case restaurant
    case cafe
    case hospital
    case fuel
    case hotel
    case park
    case market

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .pharmacy: "categories.pharmacies"
        case .restaurant: "categories.restaurants"
        case .cafe: "categories.cafes"
        case .hospital: "categories.hospitals"
        case .fuel: "categories.fuel"
        case .hotel: "categories.hotels"
        case .park: "categories.parks"
        case .market: "categories.markets"
        }
    }

    var intentTerms: [String] {
        switch self {
        case .pharmacy: ["صيدل", "دواء", "ادوية", "دەرمانخان", "pharmacy", "drugstore", "drug store"]
        case .restaurant: ["مطعم", "مطاعم", "اكل", "أكل", "چێشتخان", "restaurant", "food"]
        case .cafe: ["كافيه", "كافي", "مقهى", "قهوة", "قاوەخان", "cafe", "coffee"]
        case .hospital: ["مستشفى", "مستشفيات", "طوارئ", "طبيب", "نەخۆشخان", "hospital", "clinic", "doctor"]
        case .fuel: ["وقود", "بنزين", "بانزين", "محطة", "پەمپ", "fuel", "gas station", "petrol"]
        case .hotel: ["فندق", "فنادق", "نوم", "هوتێل", "hotel", "motel"]
        case .park: ["حديقة", "حدائق", "منتزه", "متنزه", "باخچە", "park"]
        case .market: ["سوق", "أسواق", "اسواق", "مول", "تسوق", "بازاڕ", "market", "supermarket", "mall", "grocery"]
        }
    }

    fileprivate func overpassStatements(near coordinate: GeoCoordinate, radius: Int) -> String {
        let point = "around:\(radius),\(coordinate.latitude),\(coordinate.longitude)"
        switch self {
        case .pharmacy:
            return "nwr[\"amenity\"=\"pharmacy\"](\(point));"
        case .restaurant:
            return "nwr[\"amenity\"=\"restaurant\"](\(point));"
        case .cafe:
            return "nwr[\"amenity\"=\"cafe\"](\(point));"
        case .hospital:
            return "nwr[\"amenity\"=\"hospital\"](\(point));"
        case .fuel:
            return "nwr[\"amenity\"=\"fuel\"](\(point));"
        case .hotel:
            return "nwr[\"tourism\"=\"hotel\"](\(point));"
        case .park:
            return "nwr[\"leisure\"=\"park\"](\(point));"
        case .market:
            return """
            nwr[\"shop\"~\"supermarket|convenience|mall\"](\(point));
            nwr[\"amenity\"=\"marketplace\"](\(point));
            """
        }
    }
}

struct AssistantWeather: Sendable {
    let temperatureCelsius: Double
    let weatherCode: Int
    let sunrise: String?
    let sunset: String?
}

struct OpenStreetMapAssistantService: MapAssistantProviding {
    private let searchRadiusMeters = 5_000
    private let resultLimit = 6
    private let overpassEndpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass.nchc.org.tw/api/interpreter"
    ]

    func nearbyPlaces(
        for category: AssistantPlaceCategory,
        near coordinate: GeoCoordinate,
        language: String
    ) async throws -> [Place] {
        let query = """
        [out:json][timeout:20];
        (
        \(category.overpassStatements(near: coordinate, radius: searchRadiusMeters))
        );
        out center tags;
        """
        var lastError: Error = AssistantServiceError.unavailable

        for endpoint in overpassEndpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 25
            request.setValue("Wain/0.1.0 (iOS; nearby places)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var form = URLComponents()
            form.queryItems = [URLQueryItem(name: "data", value: query)]
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw AssistantServiceError.badResponse
                }
                let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
                return sortedPlaces(
                    from: decoded.elements,
                    near: coordinate,
                    language: language
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    func weather(at coordinate: GeoCoordinate) async throws -> AssistantWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = components?.url else { throw AssistantServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AssistantServiceError.badResponse
        }
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return AssistantWeather(
            temperatureCelsius: decoded.current.temperature,
            weatherCode: decoded.current.weatherCode,
            sunrise: Self.localTime(from: decoded.daily?.sunrise?.first),
            sunset: Self.localTime(from: decoded.daily?.sunset?.first)
        )
    }

    func nearbyStreet(at coordinate: GeoCoordinate, language: String) async throws -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: language)
        )
        guard let placemark = placemarks.first else { return nil }
        return [placemark.thoroughfare, placemark.subLocality, placemark.locality, placemark.subAdministrativeArea]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func sortedPlaces(
        from elements: [OverpassElement],
        near coordinate: GeoCoordinate,
        language: String
    ) -> [Place] {
        let places = elements.compactMap { element -> Place? in
            guard let tags = element.tags,
                  let latitude = element.lat ?? element.center?.lat,
                  let longitude = element.lon ?? element.center?.lon,
                  (-90.0...90.0).contains(latitude),
                  (-180.0...180.0).contains(longitude) else { return nil }

            let localizedName: String?
            if language == "ku" {
                localizedName = tags["name:ckb"] ?? tags["name:ku"]
            } else {
                localizedName = nil
            }
            guard let name = (localizedName ?? tags["name"] ?? tags["name:\(language)" ] ?? tags["name:en"] ?? tags["name:ar"])?
                .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }

            let street = tags["addr:street"] ?? tags["addr:place"]
            let city = tags["addr:city"] ?? tags["addr:suburb"]
            return Place(
                id: "osm-\(element.type)-\(element.id)",
                name: name,
                street: street,
                city: city,
                country: tags["addr:country"],
                coordinate: GeoCoordinate(latitude: latitude, longitude: longitude)
            )
        }

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return places
            .filter { place in
                origin.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)) <= Double(searchRadiusMeters)
            }
            .sorted { lhs, rhs in
                origin.distance(from: CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude)) <
                    origin.distance(from: CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude))
            }
            .prefix(resultLimit)
            .map { $0 }
    }

    private static func localTime(from value: String?) -> String? {
        guard let value, let time = value.split(separator: "T").last else { return nil }
        let result = String(time.prefix(5))
        return result.count == 5 ? result : nil
    }
}

private enum AssistantServiceError: Error {
    case invalidURL
    case badResponse
    case unavailable
}

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let id: Int64
    let type: String
    let lat: Double?
    let lon: Double?
    let center: Center?
    let tags: [String: String]?

    struct Center: Decodable {
        let lat: Double
        let lon: Double
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: Current
    let daily: Daily?

    struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    struct Daily: Decodable {
        let sunrise: [String]?
        let sunset: [String]?
    }
}
