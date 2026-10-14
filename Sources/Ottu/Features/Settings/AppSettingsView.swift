import SwiftUI
import UIKit

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: String
    @ObservedObject var locationManager: UserLocationManager
    @ObservedObject var iraqBuildingsManager: IraqBuildingFootprintsManager
    @AppStorage("ottu.distanceUnit") private var distanceUnit = "km"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"
    @AppStorage("ottu.liquidGlassIntensity") private var liquidGlassIntensity = 1.0
    @AppStorage("ottu.mapDisplayMode") private var mapDisplayMode = "2d"
    @State private var isWaitingForLocation = false
    @State private var requestedLocationUpdateID = 0
    @State private var locationRequestTimeout: Task<Void, Never>?
    @State private var shareURL: URL?
    @State private var isShareSheetPresented = false
    @State private var isLocationAlertPresented = false
    @State private var shouldOfferAppSettings = false
    @State private var locationAlertTitleKey = "settings.location_unavailable_title"
    @State private var locationAlertMessageKey = "settings.location_unavailable_message"

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

                Picker(selection: $mapDisplayMode, label: Text(AppLocalization.string("settings.map_display", locale: interfaceLocale))) {
                    Label(AppLocalization.string("settings.map_display.2d", locale: interfaceLocale), systemImage: "map").tag("2d")
                    Label(AppLocalization.string("settings.map_display.3d", locale: interfaceLocale), systemImage: "view.3d").tag("3d")
                }
                Text(AppLocalization.string("settings.map_display_hint", locale: interfaceLocale))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Section {
                    Button(action: shareCurrentLocation) {
                        HStack(spacing: 12) {
                            Image(systemName: "location.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppLocalization.string("settings.share_location", locale: interfaceLocale))
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(AppLocalization.string("settings.share_location_hint", locale: interfaceLocale))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if isWaitingForLocation {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isWaitingForLocation)
                    .accessibilityHint(Text(AppLocalization.string("settings.share_location_hint", locale: interfaceLocale)))
                }

                Section {
                    Slider(value: $liquidGlassIntensity, in: 0...1, step: 0.01)
                        .accessibilityLabel(Text(AppLocalization.string("settings.liquid_glass", locale: interfaceLocale)))
                        .accessibilityValue(Text("\(Int((liquidGlassIntensity * 100).rounded()))%"))
                } header: {
                    Text(AppLocalization.string("settings.liquid_glass", locale: interfaceLocale))
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
                        iraqBuildings: iraqBuildingsManager,
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
                NavigationLink {
                    AboutView()
                } label: {
                    Label(AppLocalization.string("settings.about", locale: interfaceLocale), systemImage: "info.circle")
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
        .onChange(of: locationManager.locationUpdateID) { _, updateID in
            handleLocationUpdate(updateID)
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            guard isWaitingForLocation, status == .denied || status == .restricted else { return }
            presentPermissionAlert()
        }
        .sheet(isPresented: $isShareSheetPresented, onDismiss: { shareURL = nil }) {
            if let shareURL {
                LocationActivitySheet(activityItems: [shareURL])
            }
        }
        .alert(
            Text(AppLocalization.string(locationAlertTitleKey, locale: interfaceLocale)),
            isPresented: $isLocationAlertPresented
        ) {
            if shouldOfferAppSettings {
                Button {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                } label: {
                    Text(AppLocalization.string("settings.open_app_settings", locale: interfaceLocale))
                }
            }
            Button(role: .cancel) { } label: {
                Text(AppLocalization.string("common.ok", locale: interfaceLocale))
            }
        } message: {
            Text(AppLocalization.string(locationAlertMessageKey, locale: interfaceLocale))
        }
        .onDisappear {
            locationRequestTimeout?.cancel()
        }
    }

    private func shareCurrentLocation() {
        guard !isWaitingForLocation else { return }
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            presentPermissionAlert()
        case .notDetermined, .authorizedAlways, .authorizedWhenInUse:
            requestedLocationUpdateID = locationManager.locationUpdateID
            isWaitingForLocation = true
            locationManager.requestLocation()
            locationRequestTimeout?.cancel()
            locationRequestTimeout = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                } catch {
                    return
                }
                guard isWaitingForLocation else { return }
                presentLocationIssue()
            }
        @unknown default:
            presentLocationIssue()
        }
    }

    private func handleLocationUpdate(_ updateID: Int) {
        guard isWaitingForLocation, updateID != requestedLocationUpdateID,
              let coordinate = locationManager.coordinate,
              let timestamp = locationManager.lastLocationTimestamp else { return }

        let age = Date().timeIntervalSince(timestamp)
        guard age >= -30, age <= 120 else { return }

        isWaitingForLocation = false
        locationRequestTimeout?.cancel()
        shareURL = mapsURL(for: coordinate)
        guard shareURL != nil else {
            presentLocationIssue()
            return
        }
        isShareSheetPresented = true
    }

    private func mapsURL(for coordinate: GeoCoordinate) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: AppLocalization.string("location.current", locale: interfaceLocale))
        ]
        return components.url
    }

    private func presentLocationIssue() {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            presentPermissionAlert()
            return
        }
        isWaitingForLocation = false
        locationRequestTimeout?.cancel()
        shouldOfferAppSettings = false
        locationAlertTitleKey = "settings.location_unavailable_title"
        locationAlertMessageKey = "settings.location_unavailable_message"
        isLocationAlertPresented = true
    }

    private func presentPermissionAlert() {
        isWaitingForLocation = false
        locationRequestTimeout?.cancel()
        shouldOfferAppSettings = true
        locationAlertTitleKey = "settings.location_permission_title"
        locationAlertMessageKey = "settings.location_permission_message"
        isLocationAlertPresented = true
    }
}

private struct LocationActivitySheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

private struct OfflineMapsSettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var manager: OfflineMapManager
    @ObservedObject var iraqBuildings: IraqBuildingFootprintsManager
    let mapCenter: GeoCoordinate
    let isDark: Bool

    @State private var confirmRemove = false
    @State private var confirmRemoveIraq = false

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

            Section {
                Toggle(isOn: $iraqBuildings.isVisible) {
                    AppLocalizedText("iraq.show")
                }
                .disabled(!iraqBuildings.hasDownloadedTiles)

                AppLocalizedText("iraq.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                AppLocalizedText("iraq.zoom_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent {
                    Text("\(iraqBuildings.completedTileCount)/\(iraqBuildings.totalTileCount) · \(iraqBuildings.formattedDownloadedSize) / \(iraqBuildings.formattedTotalSize)")
                        .font(.footnote.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                } label: {
                    AppLocalizedText("iraq.storage")
                }

                if iraqBuildings.hasDownloadedTiles {
                    ProgressView(value: iraqBuildings.downloadProgress)
                }

                Button {
                    if iraqBuildings.isDownloading {
                        iraqBuildings.cancelDownload()
                    } else {
                        iraqBuildings.downloadIraq()
                    }
                } label: {
                    AppLocalizedLabel(
                        iraqBuildings.isDownloading ? "iraq.cancel_download" : (iraqBuildings.isComplete ? "iraq.downloaded" : (iraqBuildings.hasDownloadedTiles ? "iraq.resume" : "iraq.download")),
                        systemImage: iraqBuildings.isDownloading ? "pause.circle" : "arrow.down.circle"
                    )
                }
                .disabled(iraqBuildings.isComplete || iraqBuildings.totalTileCount == 0)

                if let statusKey = iraqBuildings.statusKey {
                    AppLocalizedText(statusKey)
                        .font(.footnote)
                        .foregroundStyle(iraqBuildings.failedTileCount > 0 ? .orange : .secondary)
                }

                if iraqBuildings.hasDownloadedTiles {
                    Button(role: .destructive) {
                        confirmRemoveIraq = true
                    } label: {
                        AppLocalizedLabel("iraq.remove", systemImage: "trash")
                    }
                    .disabled(iraqBuildings.isDownloading)
                }
            } header: {
                AppLocalizedText("iraq.section")
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
        .alert(
            Text(AppLocalization.string("iraq.remove_title", locale: locale)),
            isPresented: $confirmRemoveIraq
        ) {
            Button(role: .destructive) {
                iraqBuildings.removeIraqPackage()
            } label: {
                AppLocalizedText("iraq.remove")
            }
            Button(role: .cancel) { } label: {
                AppLocalizedLabel("common.cancel", systemImage: "xmark")
            }
        } message: {
            AppLocalizedText("iraq.remove_message")
        }
    }
}
