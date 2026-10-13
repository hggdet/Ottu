import SwiftUI

struct SavedPlacesView: View {
    let savedPlaces: [Place]
    let communityPlaces: [Place]
    let onSelect: (Place) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("saved.section") {
                    if savedPlaces.isEmpty {
                        ContentUnavailableView("saved.empty", systemImage: "bookmark", description: Text("saved.empty_hint"))
                    } else {
                        ForEach(savedPlaces) { place in
                            placeRow(place)
                        }
                    }
                }
                Section("community.section") {
                    if communityPlaces.isEmpty {
                        ContentUnavailableView("community.empty", systemImage: "mappin.and.ellipse", description: Text("community.empty_hint"))
                    } else {
                        ForEach(communityPlaces) { place in
                            placeRow(place)
                        }
                    }
                }
            }
            .navigationTitle("saved.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done", action: onDismiss)
                }
            }
        }
    }

    private func placeRow(_ place: Place) -> some View {
        Button { onSelect(place) } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.left").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
