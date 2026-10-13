import CoreLocation
import Foundation

enum MapConfiguration {
    static let lightStyleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    static let darkStyleURL = URL(string: "https://tiles.openfreemap.org/styles/dark")!

    static func styleURL(isDark: Bool) -> URL {
        isDark ? darkStyleURL : lightStyleURL
    }
    static let initialCenter = GeoCoordinate(latitude: 33.3152, longitude: 44.3661)
    static let initialZoom = 11.5
}
