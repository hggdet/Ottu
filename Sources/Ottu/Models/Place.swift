import CoreLocation
import Foundation

struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum QuickPlaceSlot: String, Codable, CaseIterable, Sendable {
    case home
    case work

    var localizationKey: String {
        switch self {
        case .home: "quick_places.home"
        case .work: "quick_places.work"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .work: "briefcase.fill"
        }
    }
}

struct Place: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let street: String?
    let locality: String?
    let district: String?
    let city: String?
    let country: String?
    let coordinate: GeoCoordinate

    init(
        id: String,
        name: String,
        street: String?,
        locality: String? = nil,
        district: String? = nil,
        city: String?,
        country: String?,
        coordinate: GeoCoordinate
    ) {
        self.id = id
        self.name = name
        self.street = street
        self.locality = locality
        self.district = district
        self.city = city
        self.country = country
        self.coordinate = coordinate
    }

    var subtitle: String {
        var previousComponent: String?
        return [street, locality, district, city, country]
            .compactMap { component -> String? in
                guard let value = component?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !value.isEmpty,
                      value != previousComponent else { return nil }
                previousComponent = value
                return value
            }
            .joined(separator: "، ")
    }

    var openStreetMapURL: URL {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        return URL(string: "https://www.openstreetmap.org/?mlat=\(lat)&mlon=\(lon)#map=17/\(lat)/\(lon)")!
    }
}

struct ParkedCarLocation: Codable, Hashable, Sendable {
    let coordinate: GeoCoordinate
    let savedAt: Date
}
