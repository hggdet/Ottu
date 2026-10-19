import Foundation

enum UserLocationIcon: String, CaseIterable, Identifiable {
    case arrow
    case car
    case walking
    case bicycle

    static let storageKey = "ottu.userLocationIcon"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .arrow: return "location.north.fill"
        case .car: return "car.fill"
        case .walking: return "figure.walk"
        case .bicycle: return "bicycle"
        }
    }

    var localizationKey: String {
        "map.settings.user_location_icon.\(rawValue)"
    }
}
