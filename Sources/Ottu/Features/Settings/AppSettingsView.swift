import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: String
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
        AppLocalization.isRightToLeft(interfaceLocale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $selectedLanguage, label: Text(AppLocalization.string("settings.language", locale: interfaceLocale))) {
                    Text(AppLocalization.string("settings.language.system", locale: interfaceLocale)).tag("system")
                    Text(AppLocalization.string("settings.language.arabic", locale: interfaceLocale)).tag("ar")
                    Text(AppLocalization.string("settings.language.english", locale: interfaceLocale)).tag("en")
                    Text(AppLocalization.string("settings.language.kurdish", locale: interfaceLocale)).tag("ku")
                }

                Picker(selection: $distanceUnit, label: Text(AppLocalization.string("settings.distance_unit", locale: interfaceLocale))) {
                    Text(AppLocalization.string("settings.distance.kilometers", locale: interfaceLocale)).tag("km")
                    Text(AppLocalization.string("settings.distance.miles", locale: interfaceLocale)).tag("mi")
                }

                Picker(selection: $selectedAppearance, label: Text(AppLocalization.string("settings.appearance", locale: interfaceLocale))) {
                    Label(AppLocalization.string("settings.appearance.system", locale: interfaceLocale), systemImage: "iphone").tag("system")
                    Label(AppLocalization.string("settings.appearance.light", locale: interfaceLocale), systemImage: "sun.max").tag("light")
                    Label(AppLocalization.string("settings.appearance.dark", locale: interfaceLocale), systemImage: "moon").tag("dark")
                }

                Section {
                    VStack(spacing: 8) {
                        Slider(value: $liquidGlassIntensity, in: 0...1, step: 0.01)
                            .accessibilityLabel(Text(AppLocalization.string("settings.liquid_glass", locale: interfaceLocale)))
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
                        Text(AppLocalization.string("settings.liquid_glass", locale: interfaceLocale))
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
                    Label(AppLocalization.string("navigation.saved", locale: interfaceLocale), systemImage: "bookmark.fill")
                }

                NavigationLink {
                    OfflineMapsSettingsView(
                        manager: offlineManager,
                        mapCenter: mapCenter,
                        isDark: isDark
                    )
                } label: {
                    Label {
                        Text(AppLocalization.string("settings.manage_maps", locale: interfaceLocale))
                    } icon: {
                        Image("IconlyLocation")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                }
                Link(destination: URL(string: "mailto:pbgpfk7ofwz729ekxamzqk@onmanus.ai")!) {
                    Label(AppLocalization.string("settings.contact_report", locale: interfaceLocale), systemImage: "envelope")
                }
            }
            .navigationTitle(Text(AppLocalization.string("settings.title", locale: interfaceLocale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image("IconlySetting")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                        Text(AppLocalization.string("settings.title", locale: interfaceLocale))
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityElement(children: .combine)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        AppLocalizedLabel("common.done", systemImage: "checkmark", locale: interfaceLocale)
                    }
                }
            }
        }
        .environment(\.locale, interfaceLocale)
        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

private struct OfflineMapsSettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var manager: OfflineMapManager
    let mapCenter: GeoCoordinate
    let isDark: Bool

    @State private var confirmRemove = false

    var body: some View {
        Form {
            if manager.hasOfflineArea {
                Label {
                    AppLocalizedText(manager.statusKey ?? (manager.isDownloading ? "offline.downloading" : "offline.complete"))
                } icon: {
                    Image(systemName: manager.isDownloading ? "arrow.down.circle" : "checkmark.circle.fill")
                }
                .foregroundStyle(manager.isDownloading ? Color.secondary : Color.green)

                if let progress = manager.progress, manager.isDownloading {
                    ProgressView(value: progress)
                }
                if let size = manager.offlineAreaSize {
                    LabeledContent {
                        Text(size)
                    } label: {
                        AppLocalizedText("settings.storage_used")
                    }
                }
                Button(role: .destructive) {
                    confirmRemove = true
                } label: {
                    AppLocalizedLabel("offline.remove", systemImage: "trash")
                }
            } else {
                ContentUnavailableView {
                    AppLocalizedLabel("offline.empty_title", systemImage: "map")
                } description: {
                    AppLocalizedText("offline.empty_hint")
                }
                Button {
                    manager.downloadArea(
                        around: mapCenter,
                        styleURL: MapConfiguration.styleURL(isDark: isDark)
                    )
                } label: {
                    AppLocalizedLabel("offline.download", systemImage: "arrow.down.circle")
                }
            }

            if let statusKey = manager.statusKey, !manager.hasOfflineArea {
                AppLocalizedText(statusKey)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(AppLocalization.string("settings.offline_maps", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            Text(AppLocalization.string("offline.remove_confirmation_title", locale: locale)),
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                manager.removeDownloadedArea()
            } label: {
                AppLocalizedText("offline.remove")
            }
            Button(role: .cancel) { } label: {
                AppLocalizedLabel("common.cancel", systemImage: "xmark")
            }
        } message: {
            AppLocalizedText("offline.remove_confirmation_message")
        }
    }
}
