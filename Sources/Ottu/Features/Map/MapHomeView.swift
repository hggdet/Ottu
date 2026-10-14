import Foundation
import SwiftUI

struct MapHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Binding var selectedLanguage: String
    @StateObject private var localStore = LocalDataStore()
    @StateObject private var locationManager = UserLocationManager()
    @StateObject private var offlineManager = OfflineMapManager()
    @StateObject private var iraqBuildingsManager = IraqBuildingFootprintsManager()

    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearchExpanded = false
    @State private var activeSheet: HomeSheet?
    @State private var isSettingsPresented = false
    @State private var placeToShowAfterSettings: Place?
    @State private var focusedPlace: Place?
    @State private var routePlan: RoutePlan?
    @State private var routeTarget: Place?
    @State private var routeTask: Task<Void, Never>?
    @State private var mapCenter = MapConfiguration.initialCenter
    @State private var selectedTab: MapNavigationTab = .location
    @State private var searchRetryToken = 0
    @State private var searchErrorMessage: String?
    @AppStorage("ottu.mapDisplayMode") private var mapDisplayMode = "2d"
    @AppStorage("ottu.liquidGlassIntensity") private var liquidGlassIntensity = 1.0
    @AppStorage("ottu.distanceUnit") private var distanceUnit = "km"
    @State private var isSearching = false
    @State private var isRouting = false
    @State private var locateWhenReady = false
    @State private var activeErrorTitle = ""
    @State private var activeErrorMessage: String?
    @FocusState private var searchFocused: Bool

    private let searchService: any PlaceSearchProviding = PhotonPlaceSearchService()
    private let assistantService: any MapAssistantProviding = OpenStreetMapAssistantService()
    private let routeService: any RoutingProviding = OSRMRouteService()

    private var currentLanguage: String {
        AppLocalization.languageCode(for: locale)
    }

    private var searchTaskKey: String {
        "\(currentLanguage):\(searchRetryToken):\(query)"
    }

    var body: some View {
        ZStack {
            OttuMapView(
                selectedPlace: focusedPlace,
                route: routePlan,
                styleURL: MapConfiguration.styleURL(isDark: colorScheme == .dark),
                is3D: mapDisplayMode == "3d",
                iraqBuildingsManager: iraqBuildingsManager,
                onLongPress: { coordinate in
                    searchFocused = false
                    activeSheet = .addPlace(coordinate)
                },
                onCenterChanged: { mapCenter = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer(minLength: 0)
                if let routeTarget {
                    routeSummary(for: routeTarget)
                }
                if let statusKey = offlineManager.statusKey {
                    HStack(spacing: 7) {
                        if offlineManager.progress.map({ $0 < 1 }) == true { ProgressView().controlSize(.mini) }
                        AppLocalizedText(statusKey)
                        if let progress = offlineManager.progress {
                            Text("\(Int(progress * 100))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .top) {
            GeometryReader { geometry in
                searchPanel(maxResultsHeight: max(180, geometry.size.height - 180))
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }
            .zIndex(10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingGlassNavigationBar(
                selection: $selectedTab,
                glassIntensity: liquidGlassIntensity,
                onSelect: selectNavigationTab
            )
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .task(id: searchTaskKey) {
            let taskKey = searchTaskKey
            await searchPlaces(for: query, taskKey: taskKey)
        }
        .onChange(of: locationManager.coordinate) { _, coordinate in
            guard locateWhenReady, let coordinate else { return }
            locateWhenReady = false
            focusMap(on: coordinate, named: AppLocalization.string("location.current", locale: locale))
        }
        .sheet(item: $activeSheet, onDismiss: {
            if selectedTab == .assistant { selectedTab = .location }
        }) { sheet in
            sheetContent(for: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isSettingsPresented, onDismiss: {
            if selectedTab == .settings { selectedTab = .location }
            if let place = placeToShowAfterSettings {
                placeToShowAfterSettings = nil
                activeSheet = .place(place)
            }
        }) {
            AppSettingsView(
                selectedLanguage: $selectedLanguage,
                locationManager: locationManager,
                iraqBuildingsManager: iraqBuildingsManager,
                savedPlaces: localStore.savedPlaces,
                communityPlaces: localStore.communityPlaces,
                offlineManager: offlineManager,
                mapCenter: mapCenter,
                isDark: colorScheme == .dark,
                onSelectPlace: { place in
                    focusedPlace = place
                    placeToShowAfterSettings = place
                    isSettingsPresented = false
                },
                onRemoveSavedPlace: { localStore.removeSavedPlace($0) },
                onRemoveCommunityPlace: { localStore.removeCommunityPlace($0) }
            )
        }
        .alert(Text(activeErrorTitle), isPresented: Binding(
            get: { activeErrorMessage != nil },
            set: { if !$0 { activeErrorMessage = nil } }
        )) {
            Button(role: .cancel) { activeErrorMessage = nil } label: {
                AppLocalizedLabel("common.ok", systemImage: "checkmark")
            }
        } message: {
            Text(activeErrorMessage ?? "")
        }
    }

    private func searchPanel(maxResultsHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(AppLocalization.string("search.placeholder", locale: locale), text: $query)
                    .focused($searchFocused)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("placeSearchField")
                if isSearching {
                    ProgressView().controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        searchErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(Text(AppLocalization.string("search.clear", locale: locale)))
                }
            }
            .padding(.horizontal, 17)
            .frame(height: 46)
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resultsPanel(maxHeight: maxResultsHeight)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchExpanded)
        .zIndex(10)
    }

    private func resultsPanel(maxHeight: CGFloat) -> some View {
        Group {
            if isSearchExpanded {
                ScrollView(.vertical) {
                    resultsContent
                }
                .scrollIndicators(.visible)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: maxHeight)
            } else {
                resultsContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }

    @ViewBuilder
    private var resultsContent: some View {
        VStack(spacing: 0) {
            if let searchErrorMessage {
                searchFailureRow(searchErrorMessage)
                if !results.isEmpty { Divider() }
            }
            if results.isEmpty {
                if isSearching {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(AppLocalization.string("search.loading", locale: locale)).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(16)
                } else if searchErrorMessage == nil {
                    Text(AppLocalization.string("search.no_results", locale: locale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                let visibleResults = isSearchExpanded ? results : Array(results.prefix(5))
                ForEach(visibleResults) { place in
                    Button {
                        searchFocused = false
                        focusedPlace = place
                        activeSheet = .place(place)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                if !place.subtitle.isEmpty {
                                    Text(place.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            if isLocal(place) {
                                Text(AppLocalization.string("community.local_badge", locale: locale))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if place.id != visibleResults.last?.id || results.count > 5 {
                        Divider().padding(.leading, 16)
                    }
                }
                if results.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text(AppLocalization.string(isSearchExpanded ? "search.less" : "search.more", locale: locale))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: isSearchExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func searchFailureRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                searchRetryToken += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel(Text(AppLocalization.string("search.retry", locale: locale)))
        }
        .padding(14)
    }

    private func routeSummary(for place: Place) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "car.fill").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let routePlan {
                    Text(routeSummaryText(for: routePlan))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isRouting {
                    AppLocalizedText("directions.calculating").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                routeTask?.cancel()
                isRouting = false
                routePlan = nil
                routeTarget = nil
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text(AppLocalization.string("common.close", locale: locale)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }

    private func routeSummaryText(for plan: RoutePlan) -> String {
        let usesMiles = distanceUnit == "mi"
        let distance = usesMiles ? plan.distanceKilometers * 0.621371 : plan.distanceKilometers
        let formatKey = usesMiles ? "directions.summary_format_miles" : "directions.summary_format"
        let format = AppLocalization.string(formatKey, locale: locale)
        return String(format: format, locale: locale, arguments: [distance, plan.durationMinutes])
    }

    @ViewBuilder
    private func sheetContent(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .place(let place):
            PlaceDetailsSheet(
                place: place,
                isSaved: localStore.isSaved(place),
                onToggleSaved: { localStore.toggleSaved(place) },
                onDirections: { startRoute(to: place) },
                onReport: { activeSheet = .report(place.coordinate) }
            )
        case .saved:
            SavedPlacesView(
                savedPlaces: localStore.savedPlaces,
                communityPlaces: localStore.communityPlaces,
                onSelect: { place in
                    focusedPlace = place
                    activeSheet = .place(place)
                },
                onDismiss: { activeSheet = nil },
                onRemoveSaved: { localStore.removeSavedPlace($0) },
                onRemoveCommunity: { localStore.removeCommunityPlace($0) }
            )
        case .addPlace(let coordinate):
            AddPlaceView(
                coordinate: coordinate,
                onSave: { place in
                    localStore.addCommunityPlace(place)
                    focusedPlace = place
                    activeSheet = .place(place)
                },
                onCancel: { activeSheet = nil }
            )
        case .report(let coordinate):
            ReportIncidentView(
                coordinate: coordinate,
                reports: localStore.incidentReports,
                onSave: { localStore.addIncident($0) },
                onCancel: { activeSheet = nil }
            )
        case .categories:
            MapCategoriesSheet(
                locale: locale,
                onSelectCategory: { category in
                    query = category
                    searchRetryToken += 1
                    searchFocused = false
                    selectedTab = .categories
                    activeSheet = nil
                },
                onSelectAction: { action in
                    switch action {
                    case .location:
                        activeSheet = nil
                        centerOnMyLocation()
                    case .saved:
                        activeSheet = .saved
                    case .addPlace:
                        activeSheet = .addPlace(mapCenter)
                    case .report:
                        activeSheet = .report(mapCenter)
                    case .offline:
                        activeSheet = nil
                        offlineManager.downloadArea(
                            around: mapCenter,
                            styleURL: MapConfiguration.styleURL(isDark: colorScheme == .dark)
                        )
                    }
                },
                onDismiss: { activeSheet = nil }
            )
        case .assistant:
            MapAssistantView(
                userCoordinate: locationManager.coordinate,
                mapCenter: mapCenter,
                language: currentLanguage,
                locale: locale,
                searchService: searchService,
                assistantService: assistantService,
                onRequestLocation: { locationManager.requestLocation() },
                onSelectPlace: { place in
                    searchFocused = false
                    query = ""
                    selectedTab = .location
                    activeSheet = .place(place)
                    routeTask?.cancel()
                    routePlan = nil
                    routeTarget = nil
                    focusedPlace = place
                }
            )
        }
    }

    private func selectNavigationTab(_ tab: MapNavigationTab) {
        switch tab {
        case .location:
            searchFocused = false
            activeSheet = nil
            centerOnMyLocation()
        case .categories:
            searchFocused = false
            activeSheet = .categories
        case .settings:
            searchFocused = false
            activeSheet = nil
            isSettingsPresented = true
        case .assistant:
            searchFocused = false
            if locationManager.coordinate == nil { locationManager.requestLocation() }
            activeSheet = .assistant
        }
    }

    @MainActor
    private func searchPlaces(for rawQuery: String, taskKey: String) async {
        guard searchTaskKey == taskKey else { return }
        let text = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        isSearchExpanded = false
        searchErrorMessage = nil
        guard text.count >= 2 else {
            isSearching = false
            return
        }
        isSearching = true
        let localMatches = (localStore.savedPlaces + localStore.communityPlaces).filter {
            $0.name.localizedCaseInsensitiveContains(text) || $0.subtitle.localizedCaseInsensitiveContains(text)
        }
        var localIDs = Set<String>()
        results = localMatches.filter { localIDs.insert($0.id).inserted }.prefix(20).map { $0 }
        defer {
            if searchTaskKey == taskKey {
                isSearching = false
            }
        }
        do {
            try await Task.sleep(nanoseconds: 180_000_000)
        } catch { return }
        guard !Task.isCancelled,
              searchTaskKey == taskKey,
              query.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }

        do {
            let remote = try await searchService.search(text, near: mapCenter, language: currentLanguage)
            guard !Task.isCancelled, searchTaskKey == taskKey else { return }
            var seen = Set<String>()
            results = (localMatches + remote).filter { seen.insert($0.id).inserted }.prefix(20).map { $0 }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, searchTaskKey == taskKey else { return }
            results = Array(results.prefix(20))
            searchErrorMessage = localizedSearchFailure(for: error)
        }
    }

    private func localizedSearchFailure(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return AppLocalization.string("search.offline_message", locale: locale)
        }
        return AppLocalization.string("search.service_error_message", locale: locale)
    }

    private func isLocal(_ place: Place) -> Bool {
        place.id.hasPrefix("local-")
    }

    private func centerOnMyLocation() {
        if let coordinate = locationManager.coordinate {
            focusMap(on: coordinate, named: AppLocalization.string("location.current", locale: locale))
        } else {
            locateWhenReady = true
            locationManager.requestLocation()
        }
    }

    private func focusMap(on coordinate: GeoCoordinate, named: String) {
        focusedPlace = Place(
            id: "focus-\(UUID().uuidString)",
            name: named,
            street: nil,
            city: nil,
            country: nil,
            coordinate: coordinate
        )
    }

    private func startRoute(to place: Place) {
        routeTask?.cancel()
        activeSheet = nil
        searchFocused = false
        isRouting = true
        routePlan = nil
        routeTarget = place
        let origin = locationManager.coordinate ?? mapCenter
        routeTask = Task {
            defer { isRouting = false }
            do {
                let result = try await routeService.route(from: origin, to: place.coordinate)
                guard !Task.isCancelled else { return }
                routePlan = result
                focusedPlace = place
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                routeTarget = nil
                activeErrorTitle = AppLocalization.string("directions.error_title", locale: locale)
                activeErrorMessage = AppLocalization.string("directions.error_message", locale: locale)
            }
        }
    }
}

private enum HomeSheet: Identifiable {
    case place(Place)
    case saved
    case addPlace(GeoCoordinate)
    case report(GeoCoordinate)
    case categories
    case assistant

    var id: String {
        switch self {
        case .place(let place): return "place-\(place.id)"
        case .saved: return "saved"
        case .addPlace(let coordinate): return "add-\(coordinate.latitude)-\(coordinate.longitude)"
        case .report(let coordinate): return "report-\(coordinate.latitude)-\(coordinate.longitude)"
        case .categories: return "categories"
        case .assistant: return "assistant"
        }
    }
}
