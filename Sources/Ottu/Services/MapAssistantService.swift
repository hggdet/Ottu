import CoreLocation
import Foundation
import OSLog

protocol MapAssistantProviding: Sendable {
    func nearbyPlaces(
        for category: AssistantPlaceCategory,
        near coordinate: GeoCoordinate,
        language: String
    ) async throws -> [Place]

    func weather(at coordinate: GeoCoordinate) async throws -> AssistantWeather
    func nearbyStreet(at coordinate: GeoCoordinate, language: String) async throws -> String?
}


enum AssistantPlaceCategory: String, CaseIterable, Identifiable, Equatable, Sendable {
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
    private let session: URLSession
    private let overpassEndpoints: [String]
    private let totalTimeout: TimeInterval
    private let endpointTimeout: TimeInterval
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Ottu", category: "MapAssistant")

    init(
        session: URLSession? = nil,
        overpassEndpoints: [String] = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter"
        ],
        totalTimeout: TimeInterval = 13,
        endpointTimeout: TimeInterval = 5
    ) {
        self.overpassEndpoints = overpassEndpoints
        self.totalTimeout = max(0, totalTimeout)
        self.endpointTimeout = max(0, endpointTimeout)

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = max(0.1, endpointTimeout)
            configuration.timeoutIntervalForResource = max(0.1, totalTimeout)
            self.session = URLSession(configuration: configuration)
        }
    }

    func nearbyPlaces(
        for category: AssistantPlaceCategory,
        near coordinate: GeoCoordinate,
        language: String
    ) async throws -> [Place] {
        let totalDeadline = ProcessInfo.processInfo.systemUptime + totalTimeout

        for endpoint in overpassEndpoints {
            try Task.checkCancellation()
            let remaining = totalDeadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { break }
            guard let url = URL(string: endpoint), let endpointLabel = Self.safeEndpointLabel(url) else {
                logger.error("Overpass endpoint configuration is invalid; endpoint omitted")
                continue
            }

            let requestBudget = min(endpointTimeout, remaining)
            guard requestBudget > 0 else { break }
            let overpassTimeout = max(1, Int(ceil(requestBudget)))
            let query = """
            [out:json][timeout:\(overpassTimeout)];
            (
            \(category.overpassStatements(near: coordinate, radius: searchRadiusMeters))
            );
            out center tags;
            """
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = requestBudget
            request.setValue("Wain/0.1.0 (iOS; nearby places)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var form = URLComponents()
            form.queryItems = [URLQueryItem(name: "data", value: query)]
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

            do {
                let (data, response) = try await Self.data(for: request, using: session, timeout: requestBudget)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse else {
                    logger.error("Overpass endpoint \(endpointLabel, privacy: .public) returned a non-HTTP response")
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    logger.error("Overpass endpoint \(endpointLabel, privacy: .public) returned HTTP \(http.statusCode, privacy: .public)")
                    continue
                }

                let decoded: OverpassResponse
                do {
                    decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
                } catch let decodingError as DecodingError {
                    logger.error("Overpass endpoint \(endpointLabel, privacy: .public) JSON decoding failed: \(Self.safeDecodingDescription(decodingError), privacy: .public)")
                    continue
                }
                if let remark = decoded.remark, !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let classification = Self.safeRemarkClassification(remark)
                    logger.error("Overpass endpoint \(endpointLabel, privacy: .public) returned a remark classified as \(classification, privacy: .public); rejecting response (raw remark withheld)")
                    continue
                }

                let places = sortedPlaces(from: decoded.elements, near: coordinate, language: language)
                if places.isEmpty {
                    logger.info("Overpass endpoint \(endpointLabel, privacy: .public) returned a valid response with no named places")
                }
                return places
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch AssistantServiceError.requestTimedOut {
                logger.error("Overpass endpoint \(endpointLabel, privacy: .public) timed out within its assigned \(requestBudget, privacy: .public) second budget")
            } catch let error as URLError {
                logger.error("Overpass endpoint \(endpointLabel, privacy: .public) failed with URLSession error code \(error.code.rawValue, privacy: .public)")
            } catch {
                if Task.isCancelled { throw CancellationError() }
                logger.error("Overpass endpoint \(endpointLabel, privacy: .public) failed with \(String(describing: type(of: error)), privacy: .public)")
            }
        }

        try Task.checkCancellation()
        throw AssistantServiceError.nearbyPlacesUnavailable
    }

    private static func data(
        for request: URLRequest,
        using session: URLSession,
        timeout: TimeInterval
    ) async throws -> (Data, URLResponse) {
        enum Outcome {
            case response(Data, URLResponse)
            case timedOut
        }

        let nanoseconds = UInt64(max(1, min(timeout, 60) * 1_000_000_000))
        return try await withThrowingTaskGroup(of: Outcome.self) { group in
            group.addTask {
                let (data, response) = try await session.data(for: request)
                return .response(data, response)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                return .timedOut
            }

            guard let outcome = try await group.next() else {
                throw AssistantServiceError.unavailable
            }
            group.cancelAll()
            switch outcome {
            case .response(let data, let response):
                return (data, response)
            case .timedOut:
                throw AssistantServiceError.requestTimedOut
            }
        }
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
            guard let name = (localizedName ?? tags["name"] ?? tags["name:\(language)"] ?? tags["name:en"] ?? tags["name:ar"])?
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

        return sortedByDistance(places, near: coordinate)
    }


    private func sortedByDistance(_ places: [Place], near coordinate: GeoCoordinate) -> [Place] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return places
            .filter { place in
                (-90.0...90.0).contains(place.coordinate.latitude) &&
                    (-180.0...180.0).contains(place.coordinate.longitude) &&
                    !place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    origin.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)) <= Double(searchRadiusMeters)
            }
            .sorted { lhs, rhs in
                origin.distance(from: CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude)) <
                    origin.distance(from: CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude))
            }
            .prefix(resultLimit)
            .map { $0 }
    }

    private static func safeEndpointLabel(_ url: URL) -> String? {
        guard let host = url.host else { return nil }
        let path = url.path.isEmpty ? "/" : url.path
        return "\(host)\(path)"
    }

    private static func safeDecodingDescription(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "missing key \(key.stringValue), coding path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "type mismatch for \(String(describing: type)), coding path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "missing value for \(String(describing: type)), coding path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return "corrupt JSON, coding path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default:
            return "unknown JSON decoding error"
        }
    }

    private static func safeRemarkClassification(_ remark: String) -> String {
        let text = remark.lowercased()
        if text.contains("timed out") || text.contains("timeout") { return "query timeout" }
        if text.contains("capacity") || text.contains("queue") { return "server capacity or queue exhaustion" }
        if text.contains("parse") || text.contains("syntax") { return "query parsing error" }
        if text.contains("runtime error") { return "runtime error" }
        if text.contains("rate limit") || text.contains("too many requests") { return "rate limited" }
        return "unclassified Overpass remark"
    }

    private static func localTime(from value: String?) -> String? {
        guard let value, let time = value.split(separator: "T").last else { return nil }
        let result = String(time.prefix(5))
        return result.count == 5 ? result : nil
    }
}

enum AssistantServiceError: Error {
    case invalidURL
    case badResponse
    case unavailable
    case requestTimedOut
    case nearbyPlacesUnavailable
    case malformedResponse
    case overpassRemark
    case httpStatus(Int)
}

private enum AsyncTimeoutOutcome<Value: Sendable>: Sendable {
    case value(Value)
    case timedOut
}

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
    let remark: String?
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
