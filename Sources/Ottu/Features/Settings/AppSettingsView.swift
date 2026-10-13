import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ottu.language") private var selectedLanguage = "system"
    @AppStorage("ottu.distanceUnit") private var distanceUnit = "km"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"
    @AppStorage("ottu.liquidGlassIntensity") private var liquidGlassIntensity = 1.0

    let savedPlaces: [Place]
    let communityPlaces: [Place]
    let offlineManager: OfflineMapManager
    let mapCenter: GeoCoordinate
    let isDark: Bool
    let onSelectPlace: (Place) -> Void
    let onRemoveSavedPlace: (Place) -> Void
    let onRemoveCommunityPlace: (Place) -> Void

    private var interfaceLocale: Locale {
        selectedLanguage == "system" ? Locale.autoupdatingCurrent : Locale(identifier: selectedLanguage)
    }

    private var isRightToLeft: Bool {
        let language = interfaceLocale.language.languageCode?.identifier ?? "ar"
        return language == "ar" || language == "ku"
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("settings.language", selection: $selectedLanguage) {
                    Text("settings.language.system").tag("system")
                    Text("settings.language.arabic").tag("ar")
                    Text("settings.language.english").tag("en")
                    Text("settings.language.kurdish").tag("ku")
                }

                Picker("settings.distance_unit", selection: $distanceUnit) {
                    Text("settings.distance.kilometers").tag("km")
                    Text("settings.distance.miles").tag("mi")
                }

                Picker("settings.appearance", selection: $selectedAppearance) {
                    Label("settings.appearance.system", systemImage: "iphone").tag("system")
                    Label("settings.appearance.light", systemImage: "sun.max").tag("light")
                    Label("settings.appearance.dark", systemImage: "moon").tag("dark")
                }

                Section {
                    VStack(spacing: 8) {
                        Slider(value: $liquidGlassIntensity, in: 0...1, step: 0.01)
                            .accessibilityLabel(Text("settings.liquid_glass"))
                            .accessibilityValue(Text("\(Int((liquidGlassIntensity * 100).rounded()))%"))

                        HStack {
                            Text("0%")
                            Spacer()
                            Text("100%")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("settings.liquid_glass")
                        Spacer()
                        Text("\(Int((liquidGlassIntensity * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

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
                    Label("navigation.saved", systemImage: "bookmark.fill")
                }

                NavigationLink {
                    OfflineMapsSettingsView(
                        manager: offlineManager,
                        mapCenter: mapCenter,
                        isDark: isDark
                    )
                } label: {
                    Label {
                        Text("settings.manage_maps")
                    } icon: {
                        Image("IconlyLocation")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                }
                Link(destination: URL(string: "mailto:pbgpfk7ofwz729ekxamzqk@onmanus.ai")!) {
                    Label("settings.contact_report", systemImage: "envelope")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image("IconlySetting")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                        Text("settings.title")
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityElement(children: .combine)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Label("common.done", systemImage: "checkmark")
                    }
                }
            }
        }
        .environment(\.locale, interfaceLocale)
        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

private struct OfflineMapsSettingsView: View {
    @ObservedObject var manager: OfflineMapManager
    let mapCenter: GeoCoordinate
    let isDark: Bool

    @State private var confirmRemove = false

    var body: some View {
        Form {
            if manager.hasOfflineArea {
                Label {
                    Text(LocalizedStringKey(manager.statusKey ?? (manager.isDownloading ? "offline.downloading" : "offline.complete")))
                } icon: {
                    Image(systemName: manager.isDownloading ? "arrow.down.circle" : "checkmark.circle.fill")
                }
                .foregroundStyle(manager.isDownloading ? Color.secondary : Color.green)

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
