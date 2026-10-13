import Foundation

struct IncidentReport: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let kind: IncidentKind
    let note: String
    let coordinate: GeoCoordinate
    let createdAt: Date

    init(kind: IncidentKind, note: String, coordinate: GeoCoordinate, createdAt: Date = .now) {
        self.id = UUID()
        self.kind = kind
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.coordinate = coordinate
        self.createdAt = createdAt
    }
}

enum IncidentKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case traffic
    case checkpoint
    case roadClosed
    case hazard

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .traffic: return "incident.traffic"
        case .checkpoint: return "incident.checkpoint"
        case .roadClosed: return "incident.road_closed"
        case .hazard: return "incident.hazard"
        }
    }

    var symbol: String {
        switch self {
        case .traffic: "car.2.fill"
        case .checkpoint: "shield.lefthalf.filled"
        case .roadClosed: "road.lanes.curved.left"
        case .hazard: "exclamationmark.triangle.fill"
        }
    }
}
