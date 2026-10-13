import CoreLocation
import Foundation

struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct Place: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let street: String?
    let city: String?
    let country: String?
    let coordinate: GeoCoordinate

    var subtitle: String {
        [street, city, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "، ")
    }

    var openStreetMapURL: URL {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        return URL(string: "https://www.openstreetmap.org/?mlat=\(lat)&mlon=\(lon)#map=17/\(lat)/\(lon)")!
    }
}
