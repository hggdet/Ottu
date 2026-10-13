import SwiftUI

struct MapHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var localStore = LocalDataStore()
    @StateObject private var locationManager = UserLocationManager()
    @StateObject private var offlineManager = OfflineMapManager()

    @State private var query = ""
    @State private var results: [Place] = []
    @State private var activeSheet: HomeSheet?
    @State private var focusedPlace: Place?
    @State private var routePlan: RoutePlan?
    @State private var routeTarget: Place?
    @State private var routeUsesCurrentLocation = false
    @State private var routeTask: Task<Void, Never>?
    @State private var mapCenter = MapConfiguration.initialCenter
    @State private var isSearching = false
    @State private var isRouting = false
    @State private var locateWhenReady = false
    @State private var activeErrorTitle: LocalizedStringKey = "search.error_title"
    @State private var activeErrorMessage: String?
    @FocusState private var searchFocused: Bool

    private let searchService: any PlaceSearchProviding = PhotonPlaceSearchService()
    private let routeService: any RoutingProviding = OSRMRouteService()

    private var currentLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "ar"
    }

    var body: some View {
        ZStack {
            OttuMapView(
                selectedPlace: focusedPlace,
                route: routePlan,
                styleURL: MapConfiguration.styleURL(isDark: colorScheme == .dark),
                onLongPress: { coordinate in
                    searchFocused = false
                    activeSheet = .addPlace(coordinate)
                },
                onCenterChanged: { mapCenter = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                Spacer(minLength: 0)
                if let routeTarget {
                    routeSummary(for: routeTarget)
                }
                searchPanel
                controlsPanel
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .task(id: query) { await searchPlaces(for: query) }
        .onChange(of: locationManager.coordinate) { _, coordinate in
            guard locateWhenReady, let coordinate else { return }
            locateWhenReady = false
            focusMap(on: coordinate, named: String(localized: "location.current"))
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(activeErrorTitle, isPresented: Binding(
            get: { activeErrorMessage != nil },
            set: { if !$0 { activeErrorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { activeErrorMessage = nil }
        } message: {
            Text(activeErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "location.north.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("app.name")
                .font(.headline.weight(.semibold))
            Spacer(minLength: 0)
            Text("map.city")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Button {
                activeSheet = .saved
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.subheadline)
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel(Text("saved.title"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .frame(height: 50)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resultsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("search.placeholder", text: $query)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("placeSearchField")
                if isSearching {
                    ProgressView().controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(Text("search.clear"))
                }
            }
            .padding(.horizontal, 17)
            .frame(minHeight: 52)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .animation(.easeInOut(duration: 0.2), value: results.count)
    }

    private var resultsPanel: some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                if isSearching {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("search.loading").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(16)
                } else {
                    Text("search.no_results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                ForEach(results) { place in
                    Button {
                        searchFocused = false
                        focusedPlace = place
                        activeSheet = .place(place)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isLocal(place) ? "mappin.and.ellipse" : "mappin.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
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
                                Text("community.local_badge")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if place.id != results.last?.id { Divider().padding(.leading, 48) }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .frame(maxHeight: 280)
    }

    private var controlsPanel: some View {
        VStack(spacing: 7) {
            if let statusKey = offlineManager.statusKey {
                HStack(spacing: 7) {
                    if offlineManager.progress.map({ $0 < 1 }) == true { ProgressView().controlSize(.mini) }
                    Text(LocalizedStringKey(statusKey))
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    controlChip("location.my_location", symbol: "location.fill") { centerOnMyLocation() }
                    controlChip("saved.title", symbol: "bookmark") { activeSheet = .saved }
                    controlChip("community.add_place", symbol: "plus") { activeSheet = .addPlace(mapCenter) }
                    controlChip("incident.report", symbol: "exclamationmark.bubble") { activeSheet = .report(mapCenter) }
                    controlChip("offline.download", symbol: "arrow.down.circle") {
                        offlineManager.downloadArea(around: mapCenter, styleURL: MapConfiguration.styleURL(isDark: colorScheme == .dark))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func routeSummary(for place: Place) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "car.fill").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let routePlan {
                    Text(String(format: String(localized: "directions.summary_format"), routePlan.distanceKilometers, routePlan.durationMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isRouting {
                    Text("directions.calculating").font(.caption).foregroundStyle(.secondary)
                }
                Text(routeUsesCurrentLocation ? "directions.from_my_location" : "directions.from_map_center")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
            .accessibilityLabel(Text("common.close"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }

    private func controlChip(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .frame(height: 39)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
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
                onDismiss: { activeSheet = nil }
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
        }
    }

    @MainActor
    private func searchPlaces(for rawQuery: String) async {
        let text = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        defer {
            if query.trimmingCharacters(in: .whitespacesAndNewlines) == text {
                isSearching = false
            }
        }
        do {
            try await Task.sleep(nanoseconds: 350_000_000)
        } catch { return }
        guard !Task.isCancelled,
              query.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }

        let localMatches = (localStore.savedPlaces + localStore.communityPlaces).filter {
            $0.name.localizedCaseInsensitiveContains(text) || $0.subtitle.localizedCaseInsensitiveContains(text)
        }
        do {
            let remote = try await searchService.search(text, near: mapCenter, language: currentLanguage)
            guard !Task.isCancelled else { return }
            var seen = Set<String>()
            results = (localMatches + remote).filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            results = Array(localMatches.prefix(8))
            if localMatches.isEmpty {
                activeErrorTitle = "search.error_title"
                activeErrorMessage = String(localized: "search.error_message")
            }
        }
    }

    private func isLocal(_ place: Place) -> Bool {
        place.id.hasPrefix("local-")
    }

    private func centerOnMyLocation() {
        if let coordinate = locationManager.coordinate {
            focusMap(on: coordinate, named: String(localized: "location.current"))
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
        routeUsesCurrentLocation = locationManager.coordinate != nil
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
                activeErrorTitle = "directions.error_title"
                activeErrorMessage = String(localized: "directions.error_message")
            }
        }
    }
}

private enum HomeSheet: Identifiable {
    case place(Place)
    case saved
    case addPlace(GeoCoordinate)
    case report(GeoCoordinate)

    var id: String {
        switch self {
        case .place(let place): return "place-\(place.id)"
        case .saved: return "saved"
        case .addPlace(let coordinate): return "add-\(coordinate.latitude)-\(coordinate.longitude)"
        case .report(let coordinate): return "report-\(coordinate.latitude)-\(coordinate.longitude)"
        }
    }
}
