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
    @Environment(\.locale) private var locale
    let savedPlaces: [Place]
    let communityPlaces: [Place]
    let onSelect: (Place) -> Void
    let onDismiss: () -> Void
    let onRemoveSaved: (Place) -> Void
    let onRemoveCommunity: (Place) -> Void

    var body: some View {
        List {
            Section {
                if savedPlaces.isEmpty {
                    ContentUnavailableView {
                        AppLocalizedLabel("saved.empty", systemImage: "bookmark")
                    } description: {
                        AppLocalizedText("saved.empty_hint")
                    }
                } else {
                    ForEach(savedPlaces) { place in
                        placeRow(place, onRemove: onRemoveSaved)
                    }
                }
            } header: {
                AppLocalizedText("saved.section")
            }
            Section {
                if communityPlaces.isEmpty {
                    ContentUnavailableView {
                        AppLocalizedLabel("community.empty", systemImage: "mappin.and.ellipse")
                    } description: {
                        AppLocalizedText("community.empty_hint")
                    }
                } else {
                    ForEach(communityPlaces) { place in
                        placeRow(place, onRemove: onRemoveCommunity)
                    }
                }
            } header: {
                AppLocalizedText("community.section")
            }
        }
        .navigationTitle(Text(AppLocalization.string("saved.title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onDismiss) {
                    AppLocalizedLabel("common.done", systemImage: "checkmark")
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
                Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onRemove(place) } label: {
                AppLocalizedLabel("common.delete", systemImage: "trash")
            }
        }
    }
}
