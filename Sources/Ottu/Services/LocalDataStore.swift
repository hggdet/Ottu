import Foundation
import Combine
import WidgetKit

@MainActor
final class LocalDataStore: ObservableObject {
    @Published private(set) var savedPlaces: [Place] = []
    @Published private(set) var communityPlaces: [Place] = []
    @Published private(set) var recentPlaces: [Place] = []
    @Published private(set) var incidentReports: [IncidentReport] = []
    @Published private(set) var homePlace: Place?
    @Published private(set) var workPlace: Place?
    @Published private(set) var parkedCarLocation: ParkedCarLocation?

    private let defaults: UserDefaults
    private let appGroupID = "group.iq.ottu.shared"

    init() {
        defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        savedPlaces = Self.decodePlaces(from: defaults.data(forKey: "savedPlaces.v1"))
        communityPlaces = Self.decodePlaces(from: defaults.data(forKey: "communityPlaces.v1"))
        recentPlaces = Array(Self.decodePlaces(from: defaults.data(forKey: "recentPlaces.v1")).prefix(10))
        incidentReports = Self.decodeReports(from: defaults.data(forKey: "incidentReports.v1"))
        homePlace = Self.decodePlace(from: defaults.data(forKey: "quickPlace.home.v1"))
        workPlace = Self.decodePlace(from: defaults.data(forKey: "quickPlace.work.v1"))
        parkedCarLocation = Self.decodeParkedCar(from: defaults.data(forKey: "parkedCarLocation.v1"))
        persist(recentPlaces, key: "recentPlaces.v1")
    }

    func isSaved(_ place: Place) -> Bool {
        savedPlaces.contains(where: { $0.id == place.id })
    }

    func toggleSaved(_ place: Place) {
        if let index = savedPlaces.firstIndex(where: { $0.id == place.id }) {
            savedPlaces.remove(at: index)
        } else {
            savedPlaces.insert(place, at: 0)
        }
        persist(savedPlaces, key: "savedPlaces.v1")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func removeSavedPlace(_ place: Place) {
        savedPlaces.removeAll { $0.id == place.id }
        persist(savedPlaces, key: "savedPlaces.v1")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addRecentPlace(_ place: Place) {
        recentPlaces.removeAll { $0.id == place.id }
        recentPlaces.insert(place, at: 0)
        recentPlaces = Array(recentPlaces.prefix(10))
        persist(recentPlaces, key: "recentPlaces.v1")
    }

    func clearRecentPlaces() {
        recentPlaces = []
        persist(recentPlaces, key: "recentPlaces.v1")
    }

    func saveParkedCar(at coordinate: GeoCoordinate, savedAt: Date = Date()) {
        let location = ParkedCarLocation(coordinate: coordinate, savedAt: savedAt)
        parkedCarLocation = location
        persist(location, key: "parkedCarLocation.v1")
    }

    func removeParkedCarLocation() {
        parkedCarLocation = nil
        defaults.removeObject(forKey: "parkedCarLocation.v1")
    }

    func addCommunityPlace(_ place: Place) {
        guard !communityPlaces.contains(where: { $0.id == place.id }) else { return }
        communityPlaces.insert(place, at: 0)
        persist(communityPlaces, key: "communityPlaces.v1")
    }

    func removeCommunityPlace(_ place: Place) {
        communityPlaces.removeAll { $0.id == place.id }
        persist(communityPlaces, key: "communityPlaces.v1")
    }

    func quickPlace(for slot: QuickPlaceSlot) -> Place? {
        switch slot {
        case .home: homePlace
        case .work: workPlace
        }
    }

    func setQuickPlace(_ place: Place, for slot: QuickPlaceSlot) {
        switch slot {
        case .home:
            homePlace = place
            persist(place, key: "quickPlace.home.v1")
        case .work:
            workPlace = place
            persist(place, key: "quickPlace.work.v1")
        }
    }

    func addIncident(_ incident: IncidentReport) {
        incidentReports.insert(incident, at: 0)
        incidentReports = Array(incidentReports.prefix(100))
        persist(incidentReports, key: "incidentReports.v1")
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decodePlaces(from data: Data?) -> [Place] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Place].self, from: data)) ?? []
    }

    private static func decodePlace(from data: Data?) -> Place? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    private static func decodeParkedCar(from data: Data?) -> ParkedCarLocation? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ParkedCarLocation.self, from: data)
    }

    private static func decodeReports(from data: Data?) -> [IncidentReport] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([IncidentReport].self, from: data)) ?? []
    }
}
