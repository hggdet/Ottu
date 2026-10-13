import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ottu.language") private var selectedLanguage = "system"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"

    let savedPlaces: [Place]
    let communityPlaces: [Place]
    let offlineManager: OfflineMapManager
    let mapCenter: GeoCoordinate
    let isDark: Bool
    let onSelectPlace: (Place) -> Void
    let onRemoveSavedPlace: (Place) -> Void
    let onRemoveCommunityPlace: (Place) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.preferences") {
                    Picker("settings.language", selection: $selectedLanguage) {
                        Text("settings.language.system").tag("system")
                        Text("settings.language.arabic").tag("ar")
                        Text("settings.language.english").tag("en")
                        Text("settings.language.kurdish").tag("ku")
                    }
                    Picker("settings.appearance", selection: $selectedAppearance) {
                        Label("settings.appearance.system", systemImage: "iphone").tag("system")
                        Label("settings.appearance.light", systemImage: "sun.max").tag("light")
                        Label("settings.appearance.dark", systemImage: "moon").tag("dark")
                    }
                }

                Section("settings.management") {
                    NavigationLink {
                        SavedPlacesListView(
                            savedPlaces: savedPlaces,
                            communityPlaces: communityPlaces,
                            onSelect: onSelectPlace,
                            onDismiss: { dismiss() },
                            onRemoveSaved: onRemoveSavedPlace,
                            onRemoveCommunity: onRemoveCommunityPlace
                        )
                    } label: {
                        Label("settings.manage_places", systemImage: "mappin.and.ellipse")
                    }
                    NavigationLink {
                        OfflineMapsSettingsView(
                            manager: offlineManager,
                            mapCenter: mapCenter,
                            isDark: isDark
                        )
                    } label: {
                        Label("settings.manage_maps", systemImage: "map")
                    }
                }

                Section {
                    Text("settings.local_data_note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Label("common.done", systemImage: "checkmark")
                    }
                }
            }
        }
    }
}

private struct OfflineMapsSettingsView: View {
    @ObservedObject var manager: OfflineMapManager
    let mapCenter: GeoCoordinate
    let isDark: Bool

    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section("settings.offline_maps") {
                if manager.hasOfflineArea {
                    Label {
                        Text(LocalizedStringKey(manager.statusKey ?? (manager.isDownloading ? "offline.downloading" : "offline.complete")))
                    } icon: {
                        Image(systemName: manager.isDownloading ? "arrow.down.circle" : "checkmark.circle.fill")
                    }
                    .foregroundStyle(manager.isDownloading ? .secondary : .green)

                    if let progress = manager.progress, manager.isDownloading {
                        ProgressView(value: progress)
                    }
                    if let size = manager.offlineAreaSize {
                        LabeledContent("settings.storage_used", value: size)
                    }
                    Button(role: .destructive) {
                        confirmRemove = true
                    } label: {
                        Label("offline.remove", systemImage: "trash")
                    }
                } else {
                    ContentUnavailableView(
                        "offline.empty_title",
                        systemImage: "map",
                        description: Text("offline.empty_hint")
                    )
                    Button {
                        manager.downloadArea(
                            around: mapCenter,
                            styleURL: MapConfiguration.styleURL(isDark: isDark)
                        )
                    } label: {
                        Label("offline.download", systemImage: "arrow.down.circle")
                    }
                }
                if let statusKey = manager.statusKey, !manager.hasOfflineArea {
                    Text(LocalizedStringKey(statusKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("settings.offline_note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.offline_maps")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "offline.remove_confirmation_title",
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("offline.remove", role: .destructive) {
                manager.removeDownloadedArea()
            }
            Button(role: .cancel) { } label: {
                Label("common.cancel", systemImage: "xmark")
            }
        } message: {
            Text("offline.remove_confirmation_message")
        }
    }
}
