import SwiftUI

struct SavedPlacesView: View {
    let savedPlaces: [Place]
    let communityPlaces: [Place]
    let onSelect: (Place) -> Void
    let onDismiss: () -> Void
    let onRemoveSaved: (Place) -> Void
    let onRemoveCommunity: (Place) -> Void

    var body: some View {
        NavigationStack {
            SavedPlacesListView(
                savedPlaces: savedPlaces,
                communityPlaces: communityPlaces,
                onSelect: onSelect,
                onDismiss: onDismiss,
                onRemoveSaved: onRemoveSaved,
                onRemoveCommunity: onRemoveCommunity
            )
        }
    }
}

struct SavedPlacesListView: View {
    let savedPlaces: [Place]
    let communityPlaces: [Place]
    let onSelect: (Place) -> Void
    let onDismiss: () -> Void
    let onRemoveSaved: (Place) -> Void
    let onRemoveCommunity: (Place) -> Void

    var body: some View {
        List {
            Section("saved.section") {
                if savedPlaces.isEmpty {
                    ContentUnavailableView("saved.empty", systemImage: "bookmark", description: Text("saved.empty_hint"))
                } else {
                    ForEach(savedPlaces) { place in
                        placeRow(place, onRemove: onRemoveSaved)
                    }
                }
            }
            Section("community.section") {
                if communityPlaces.isEmpty {
                    ContentUnavailableView("community.empty", systemImage: "mappin.and.ellipse", description: Text("community.empty_hint"))
                } else {
                    ForEach(communityPlaces) { place in
                        placeRow(place, onRemove: onRemoveCommunity)
                    }
                }
            }
        }
        .navigationTitle("saved.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onDismiss) {
                    Label("common.done", systemImage: "checkmark")
                }
            }
        }
    }

    private func placeRow(_ place: Place, onRemove: @escaping (Place) -> Void) -> some View {
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onRemove(place) } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }
}
