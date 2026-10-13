import SwiftUI
import WidgetKit

private let ottuAppGroup = "group.iq.ottu.shared"

struct SavedPlacesEntry: TimelineEntry {
    let date: Date
    let places: [WidgetPlace]
}

struct WidgetPlace: Decodable, Identifiable {
    let id: String
    let name: String
    let city: String?
    let coordinate: WidgetCoordinate
}

struct WidgetCoordinate: Decodable {
    let latitude: Double
    let longitude: Double
}

struct SavedPlacesProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavedPlacesEntry {
        SavedPlacesEntry(date: .now, places: [WidgetPlace(id: "sample", name: "المكان المحفوظ", city: "بغداد", coordinate: .init(latitude: 33.3152, longitude: 44.3661))])
    }

    func getSnapshot(in context: Context, completion: @escaping (SavedPlacesEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavedPlacesEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .after(.now.addingTimeInterval(60 * 60))))
    }

    private func loadEntry() -> SavedPlacesEntry {
        let data = UserDefaults(suiteName: ottuAppGroup)?.data(forKey: "savedPlaces.v1")
        let places = (try? JSONDecoder().decode([WidgetPlace].self, from: data ?? Data())) ?? []
        return SavedPlacesEntry(date: .now, places: Array(places.prefix(3)))
    }
}

struct SavedPlacesWidgetView: View {
    let entry: SavedPlacesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.north.circle.fill").foregroundStyle(.blue)
                Text("وين").font(.headline)
                Spacer()
                Text("المحفوظة").font(.caption).foregroundStyle(.secondary)
            }
            if entry.places.isEmpty {
                Text("احفظ مكانًا من التطبيق ليظهر هنا")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.places) { place in
                    Link(destination: URL(string: "https://www.openstreetmap.org/?mlat=\(place.coordinate.latitude)&mlon=\(place.coordinate.longitude)#map=16/\(place.coordinate.latitude)/\(place.coordinate.longitude)")!) {
                        HStack(spacing: 7) {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                if let city = place.city, !city.isEmpty {
                                    Text(city).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

@main
struct OttuSavedPlacesWidget: Widget {
    let kind = "OttuSavedPlacesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavedPlacesProvider()) { entry in
            SavedPlacesWidgetView(entry: entry)
        }
        .configurationDisplayName("أماكن وين المحفوظة")
        .description("اختصارات سريعة إلى أماكنك المفضلة.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
