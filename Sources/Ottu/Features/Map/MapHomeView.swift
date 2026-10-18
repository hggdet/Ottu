import Foundation
import CoreLocation
import SwiftUI
import UIKit

struct MapHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Binding var selectedLanguage: String
    @StateObject private var localStore = LocalDataStore()
    @StateObject private var locationManager = UserLocationManager()
    @StateObject private var voiceGuidance = NavigationVoiceGuidance()
    @StateObject private var offlineManager = OfflineMapManager()
    @StateObject private var iraqBuildingsManager = IraqBuildingFootprintsManager()
    @StateObject private var networkMonitor = NetworkStatusMonitor()

    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearchExpanded = false
    @State private var activeSheet: HomeSheet?
    @State private var isSettingsPresented = false
    @State private var placeToShowAfterSettings: Place?
    @State private var focusedPlace: Place?
    @State private var selectedQuickCategory: AssistantPlaceCategory?
    @State private var nearbyResults: [Place] = []
    @State private var isSearchingNearby = false
    @State private var nearbySearchError: String?
    @State private var nearbySearchTask: Task<Void, Never>?
    @State private var nearbySearchRequestID = UUID()
    @State private var routePlan: RoutePlan?
    @State private var routeAlternatives: [RoutePlan] = []
    @State private var routeTarget: Place?
    @State private var activeTransportMode = RouteTransportMode.driving
    @State private var navigationStops: [Place] = []
    @State private var routeTask: Task<Void, Never>?
    @State private var rerouteTask: Task<Void, Never>?
    @State private var isNavigationActive = false
    @State private var isRerouting = false
    @State private var lastRerouteAt: Date?
    @State private var offRouteFixCount = 0
    @State private var spokenGuidanceIDs = Set<String>()
    @State private var didTriggerArrivalHaptic = false
    @State private var routeProgressMeters = 0.0
    @State private var routePreviewPlan: RoutePlan?
    @State private var routePreviewOptions: [RoutePlan] = []
    @State private var routePreviewPlaceID: String?
    @State private var isPreviewingRoute = false
    @State private var routePreviewUnavailable = false
    @State private var routePreviewTask: Task<Void, Never>?
    @State private var routePreviewRequestID = UUID()
    @State private var stopSearchTask: Task<Void, Never>?
    @State private var stopSearchResults: [Place] = []
    @State private var selectedStopCategory: AssistantPlaceCategory?
    @State private var isSearchingStops = false
    @State private var stopSearchError: String?
    @State private var stopSearchRequestID = UUID()
    @State private var mapCenter = MapConfiguration.initialCenter
    @State private var selectedTab: MapNavigationTab = .location
    @State private var isMapMoving = false
    @State private var zoomInRequest = 0
    @State private var zoomOutRequest = 0
    @State private var searchRetryToken = 0
    @State private var searchErrorMessage: String?
    @AppStorage("ottu.mapDisplayMode") private var mapDisplayMode = "2d"
    @AppStorage("ottu.navigationVoiceLanguage") private var navigationVoiceLanguage = "auto"
    @AppStorage("ottu.liquidGlassIntensity") private var liquidGlassIntensity = 1.0
    @AppStorage("ottu.distanceUnit") private var distanceUnit = "km"
    @AppStorage("ottu.routing.transportMode") private var transportModeRawValue = RouteTransportMode.driving.rawValue
    @State private var isSearching = false
    @State private var isRouting = false
    @State private var locateWhenReady = false
    @State private var pendingQuickPlaceSlot: QuickPlaceSlot?
    @State private var activeErrorTitle = ""
    @State private var activeErrorMessage: String?
    @State private var isWaitingToSaveCarLocation = false
    @State private var parkedCarLocationRequestTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let searchService: any PlaceSearchProviding = PhotonPlaceSearchService()
    private let assistantService: any MapAssistantProviding = OpenStreetMapAssistantService()
    private let routeService: any RoutingProviding = OSRMRouteService()

    private let quickCategories: [AssistantPlaceCategory] = [.restaurant, .cafe, .fuel, .pharmacy]

    private var currentLanguage: String {
        AppLocalization.languageCode(for: locale)
    }

    private var speechLanguageCode: String {
        navigationVoiceLanguage == "auto" ? currentLanguage : navigationVoiceLanguage
    }

    private var selectedTransportMode: RouteTransportMode {
        RouteTransportMode(rawValue: transportModeRawValue) ?? .driving
    }

    private var searchTaskKey: String {
        "\(currentLanguage):\(searchRetryToken):\(query)"
    }

    var body: some View {
        ZStack {
            OttuMapView(
                selectedPlace: focusedPlace,
                parkedCarLocation: localStore.parkedCarLocation,
                parkedCarTitle: AppLocalization.string("parked_car.title", locale: locale),
                route: isNavigationActive ? routePlan : (focusedPlace == nil ? nil : routePreviewPlan),
                alternativeRoutes: isNavigationActive || focusedPlace == nil ? [] : previewAlternativeRoutes,
                alternativeRouteLabels: isNavigationActive || focusedPlace == nil ? [:] : previewAlternativeLabels,
                styleURL: MapConfiguration.styleURL(isDark: colorScheme == .dark),
                is3D: mapDisplayMode == "3d",
                isNavigationActive: isNavigationActive,
                navigationCoordinate: isNavigationActive ? (locationManager.coordinate ?? routePlan?.coordinates.first) : nil,
                navigationCourse: isNavigationActive ? locationManager.course : nil,
                reduceMotion: reduceMotion,
                zoomInRequest: zoomInRequest,
                zoomOutRequest: zoomOutRequest,
                iraqBuildingsManager: iraqBuildingsManager,
                onSelectAlternativeRoute: selectPreviewRoute,
                onSelectParkedCar: { activeSheet = .parkedCar },
                onLongPress: { coordinate in
                    searchFocused = false
                    activeSheet = .addPlace(coordinate)
                },
                onCenterChanged: { mapCenter = $0 },
                onMapMotionChanged: { isMapMoving = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer(minLength: 0)
                if !isNavigationActive, let statusKey = offlineManager.statusKey {
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
                    .mapGlassSurface(cornerRadius: 16, glassIntensity: liquidGlassIntensity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: offlineManager.statusKey != nil)
        }
        .overlay(alignment: .bottom) {
            selectedPlaceBottomSheetOverlay
        }
        .overlay(alignment: .trailing) {
            if isNavigationActive {
                NavigationSpeedometerPill(
                    speedKilometersPerHour: locationManager.speedMetersPerSecond.map { $0 * 3.6 },
                    glassIntensity: liquidGlassIntensity
                )
                .padding(.trailing, 14)
                .offset(y: 28)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                FloatingMapControls(
                    glassIntensity: liquidGlassIntensity,
                    onLocate: centerOnMyLocation,
                    onSaveCar: saveParkedCarLocation,
                    onZoomIn: { zoomInRequest += 1 },
                    onZoomOut: { zoomOutRequest += 1 },
                    onOpenMapSettings: {
                        searchFocused = false
                        activeSheet = .mapSettings
                    }
                )
                .padding(.trailing, 14)
            }
        }
        .overlay(alignment: .center) {
            if isAtDestination, let routeTarget {
                NavigationArrivalCard(
                    destinationName: routeTarget.name,
                    glassIntensity: liquidGlassIntensity,
                    onFinish: finishActiveNavigation
                )
                .padding(.horizontal, 24)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.4, dampingFraction: 0.86), value: isAtDestination)
        .overlay(alignment: .top) {
            GeometryReader { geometry in
                Group {
                    if isNavigationActive {
                        VStack(spacing: 8) {
                            ActiveNavigationInstructionPanel(
                                instruction: AppLocalization.string(activeInstructionKey, locale: locale),
                                instructionSymbol: activeInstructionSymbol,
                                streetName: activeStreetName,
                                distanceToTurn: navigationDistanceText(activeDistanceToTurnMeters),
                                distanceLabelKey: activeDistanceLabelKey,
                                glassIntensity: liquidGlassIntensity,
                                isVoiceMuted: voiceGuidance.isMuted,
                                onToggleVoice: voiceGuidance.toggleMuted,
                                onAddStop: openQuickStopPicker
                            )
                            if !networkMonitor.isConnected {
                                networkStatusBanner
                            }
                            if isRerouting {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    AppLocalizedText("navigation.rerouting")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .mapGlassSurface(cornerRadius: 18, glassIntensity: liquidGlassIntensity)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isRerouting)
                    } else {
                        VStack(spacing: 8) {
                            if !networkMonitor.isConnected {
                                networkStatusBanner
                            }
                            searchPanel(maxResultsHeight: max(180, geometry.size.height - 180))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .zIndex(10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if isNavigationActive {
                    ActiveNavigationSummaryBar(
                        eta: navigationETA,
                        remainingDistance: navigationDistanceText(activeRemainingDistanceMeters),
                        shareItem: navigationShareItem,
                        glassIntensity: liquidGlassIntensity,
                        onFinish: finishActiveNavigation
                    )
                } else {
                    FloatingGlassNavigationBar(
                        selection: $selectedTab,
                        glassIntensity: liquidGlassIntensity,
                        onSelect: selectNavigationTab
                    )
                }
            }
                .padding(.horizontal, isNavigationActive ? 14 : 24)
                .padding(.top, 8)
                .padding(.bottom, 6)
        }
        .task(id: searchTaskKey) {
            let taskKey = searchTaskKey
            await searchPlaces(for: query, taskKey: taskKey)
        }
        .onChange(of: locationManager.locationUpdateID) { _, _ in
            guard let coordinate = navigationOrigin else { return }
            if isWaitingToSaveCarLocation {
                isWaitingToSaveCarLocation = false
                parkedCarLocationRequestTask?.cancel()
                parkedCarLocationRequestTask = nil
                localStore.saveParkedCar(at: coordinate)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            if let slot = pendingQuickPlaceSlot {
                pendingQuickPlaceSlot = nil
                saveQuickPlace(slot, at: coordinate)
            }
            if isNavigationActive, let routePlan {
                let currentProgress = routePlan.progressMeters(near: coordinate)
                navigationStops = NavigationLocationPolicy.remainingStops(
                    navigationStops, on: routePlan, coordinate: coordinate,
                    accuracy: locationManager.horizontalAccuracyMeters,
                    currentProgress: currentProgress
                )
                routeProgressMeters = max(routeProgressMeters, currentProgress)
                if isAtDestination {
                    triggerArrivalFeedbackIfNeeded()
                } else {
                    checkForOffRouteLocation(coordinate, routePlan: routePlan)
                }
                updateVoiceGuidance()
            }
            guard locateWhenReady else { return }
            locateWhenReady = false
            focusMap(on: coordinate, named: AppLocalization.string("location.current", locale: locale))
        }
        .onChange(of: navigationVoiceLanguage) { _, _ in
            guard isNavigationActive else { return }
            spokenGuidanceIDs.removeAll()
            updateVoiceGuidance()
        }
        .onChange(of: query) { _, newQuery in
            guard !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  selectedQuickCategory != nil else { return }
            clearNearbySearch()
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
                selectPlace(place)
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

    @ViewBuilder
    private var selectedPlaceBottomSheetOverlay: some View {
        Group {
            if !isNavigationActive, let place = focusedPlace, !place.id.hasPrefix("focus-") {
                let previewPlan = routePreviewPlaceID == place.id ? routePreviewPlan : nil
                SelectedPlaceBottomSheet(
                    place: place,
                    routeSummary: previewPlan.map(routeSummaryText),
                    isEstimatingRoute: routePreviewPlaceID == place.id && isPreviewingRoute,
                    routeEstimateUnavailable: routePreviewPlaceID == place.id && routePreviewUnavailable,
                    isStartingRoute: routeTarget?.id == place.id && isRouting,
                    isSaved: localStore.isSaved(place),
                    isHomePlace: localStore.homePlace == place,
                    isWorkPlace: localStore.workPlace == place,
                    transportMode: selectedTransportMode,
                    glassIntensity: liquidGlassIntensity,
                    onStartTrip: { startRoute(to: place) },
                    onToggleSaved: { localStore.toggleSaved(place) },
                    onSetHome: { localStore.setQuickPlace(place, for: .home) },
                    onSetWork: { localStore.setQuickPlace(place, for: .work) },
                    onSelectTransportMode: setTransportMode,
                    onShowDetails: { activeSheet = .place(place) },
                    onDismiss: {
                        routePreviewTask?.cancel()
                        focusedPlace = nil
                    }
                )
                .id(place.id)
                .padding(.horizontal, 14)
                .padding(.bottom, 88)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.84), value: focusedPlace?.id)
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
            .mapGlassSurface(cornerRadius: 24, glassIntensity: liquidGlassIntensity)
            if searchFocused, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                quickPlacesRow
                    .transition(.opacity)
            }
            if !isMapMoving, !isRouting {
                quickCategoryChips
                    .transition(.opacity)
            }
            if searchFocused,
               query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !localStore.recentPlaces.isEmpty {
                recentPlacesPanel(maxHeight: maxResultsHeight)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            if selectedQuickCategory != nil {
                nearbyResultsPanel(maxHeight: maxResultsHeight)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resultsPanel(maxHeight: maxResultsHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: isSearchExpanded)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isMapMoving)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isRouting)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: searchFocused)
        .zIndex(10)
    }

    private var networkStatusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            AppLocalizedText(
                isNavigationActive && routePlan != nil ? "network.offline.pill.route" : "network.offline.pill.general",
                locale: locale
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 340, alignment: .leading)
        .mapGlassSurface(cornerRadius: 20, glassIntensity: liquidGlassIntensity)
        .accessibilityElement(children: .combine)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: networkMonitor.isConnected)
    }

    private func recentPlacesPanel(maxHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                AppLocalizedText("search.recent", locale: locale)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    localStore.clearRecentPlaces()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        AppLocalizedText("search.clear_history", locale: locale)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AppLocalization.string("search.clear_history", locale: locale)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            Divider()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(localStore.recentPlaces.prefix(10))) { place in
                        Button {
                            selectPlace(place)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
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
                                Image(systemName: "arrow.up.left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if place.id != localStore.recentPlaces.prefix(10).last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: min(maxHeight, 280))
        }
        .frame(maxWidth: .infinity)
        .mapGlassSurface(cornerRadius: 24, glassIntensity: liquidGlassIntensity)
    }

    private var quickPlacesRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(QuickPlaceSlot.allCases, id: \.rawValue) { slot in
                    let isSaved = localStore.quickPlace(for: slot) != nil
                    Button {
                        openQuickPlace(slot)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: slot.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            AppLocalizedText(slot.localizationKey, locale: locale)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            if isSaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 35)
                        .mapGlassSurface(cornerRadius: 18, glassIntensity: liquidGlassIntensity)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    searchFocused = false
                    activeSheet = .saved
                } label: {
                    AppLocalizedLabel("quick_places.favorites", systemImage: "heart.fill", locale: locale)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 35)
                        .mapGlassSurface(cornerRadius: 18, glassIntensity: liquidGlassIntensity)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    private var quickCategoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(quickCategories) { category in
                    let isSelected = selectedQuickCategory == category
                    Button {
                        searchNearbyPlaces(for: category)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: categorySymbol(for: category))
                                .font(.system(size: 11, weight: .semibold))
                            AppLocalizedText(category.titleKey, locale: locale)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .mapGlassSurface(cornerRadius: 17, glassIntensity: liquidGlassIntensity)
                        .overlay {
                            Capsule()
                                .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AppLocalization.string(category.titleKey, locale: locale)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 0)
        }
        .frame(height: 34)
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selectedQuickCategory)
    }

    private func categorySymbol(for category: AssistantPlaceCategory) -> String {
        switch category {
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer"
        case .fuel: "fuelpump"
        case .pharmacy: "cross.case"
        case .hospital: "cross"
        case .hotel: "bed.double"
        case .park: "tree"
        case .market: "basket"
        }
    }

    private func nearbyResultsPanel(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let selectedQuickCategory {
                HStack {
                    AppLocalizedText(selectedQuickCategory.titleKey, locale: locale)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if isSearchingNearby { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                Divider()
            }

            if isSearchingNearby {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    AppLocalizedText("map.category.loading", locale: locale)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(15)
            } else if let nearbySearchError {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(nearbySearchError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        if let selectedQuickCategory { searchNearbyPlaces(for: selectedQuickCategory) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(Text(AppLocalization.string("search.retry", locale: locale)))
                }
                .padding(14)
            } else if nearbyResults.isEmpty {
                AppLocalizedText("map.category.empty", locale: locale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
            } else {
                ForEach(nearbyResults) { place in
                    Button {
                        selectPlace(place)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if !place.subtitle.isEmpty {
                                    Text(place.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if place.id != nearbyResults.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxHeight)
        .mapGlassSurface(cornerRadius: 24, glassIntensity: liquidGlassIntensity)
    }

    private func searchNearbyPlaces(for category: AssistantPlaceCategory) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        searchFocused = false
        query = ""
        results = []
        isSearchExpanded = false
        focusedPlace = nil
        routePreviewTask?.cancel()
        routePreviewPlan = nil
        routePreviewPlaceID = nil
        isPreviewingRoute = false
        routePreviewUnavailable = false
        selectedQuickCategory = category
        nearbyResults = []
        nearbySearchError = nil
        isSearchingNearby = true
        nearbySearchTask?.cancel()

        let requestID = UUID()
        nearbySearchRequestID = requestID
        let origin = locationManager.coordinate ?? mapCenter
        let language = currentLanguage
        nearbySearchTask = Task {
            do {
                let matches = try await assistantService.nearbyPlaces(
                    for: category,
                    near: origin,
                    language: language
                )
                guard !Task.isCancelled, nearbySearchRequestID == requestID else { return }
                nearbyResults = matches
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, nearbySearchRequestID == requestID else { return }
                nearbySearchError = localizedSearchFailure(for: error)
            }
            guard nearbySearchRequestID == requestID else { return }
            isSearchingNearby = false
        }
    }

    private func clearNearbySearch() {
        nearbySearchTask?.cancel()
        nearbySearchRequestID = UUID()
        selectedQuickCategory = nil
        nearbyResults = []
        nearbySearchError = nil
        isSearchingNearby = false
    }

    private func selectPlace(_ place: Place) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        localStore.addRecentPlace(place)
        searchFocused = false
        query = ""
        isSearchExpanded = false
        clearNearbySearch()
        activeSheet = nil

        routeTask?.cancel()
        routePlan = nil
        routeAlternatives = []
        routeTarget = nil
        isRouting = false
        routePreviewTask?.cancel()
        routePreviewPlan = nil
        routePreviewOptions = []
        routePreviewPlaceID = place.id
        routePreviewUnavailable = false
        isPreviewingRoute = true
        focusedPlace = place
        requestRoutePreview(for: place)
    }

    private func requestRoutePreview(for place: Place) {
        routePreviewTask?.cancel()
        routePreviewPlan = nil
        routePreviewOptions = []
        routePreviewPlaceID = place.id
        routePreviewUnavailable = false
        isPreviewingRoute = true
        let origin = locationManager.coordinate ?? mapCenter
        let mode = selectedTransportMode
        let requestID = UUID()
        routePreviewRequestID = requestID
        routePreviewTask = Task {
            do {
                let options = try await routeService.routes(
                    from: origin,
                    to: place.coordinate,
                    mode: mode,
                    alternatives: true,
                    waypoints: []
                )
                guard !Task.isCancelled,
                      routePreviewPlaceID == place.id,
                      routePreviewRequestID == requestID else { return }
                routePreviewOptions = options
                routePreviewPlan = options.first
                routePreviewUnavailable = options.isEmpty
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      routePreviewPlaceID == place.id,
                      routePreviewRequestID == requestID else { return }
                routePreviewUnavailable = true
            }
            guard routePreviewPlaceID == place.id, routePreviewRequestID == requestID else { return }
            isPreviewingRoute = false
        }
    }

    private func setTransportMode(_ mode: RouteTransportMode) {
        guard selectedTransportMode != mode else { return }
        transportModeRawValue = mode.rawValue
        guard !isNavigationActive, let place = focusedPlace, !place.id.hasPrefix("focus-") else { return }
        requestRoutePreview(for: place)
    }

    private func selectPreviewRoute(_ routeID: UUID) {
        guard let route = routePreviewOptions.first(where: { $0.id == routeID }) else { return }
        routePreviewPlan = route
        UISelectionFeedbackGenerator().selectionChanged()
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
        .mapGlassSurface(cornerRadius: 24, glassIntensity: liquidGlassIntensity)
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
                        selectPlace(place)
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
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
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

    private var activeRouteStep: RouteStep? {
        routePlan?.nextStep(after: routeProgressMeters)
    }

    private var isAtDestination: Bool {
        guard isNavigationActive,
              let destination = routeTarget?.coordinate,
              let coordinate = locationManager.coordinate,
              (locationManager.horizontalAccuracyMeters ?? .greatestFiniteMagnitude) <= 40 else { return false }
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let endpoint = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return current.distance(from: endpoint) < 25
    }

    private var activeInstructionKey: String {
        if let activeRouteStep { return activeRouteStep.instructionLocalizationKey }
        if let routePlan, routeProgressMeters >= routePlan.distanceMeters - 25 {
            return "navigation.maneuver.arrive"
        }
        return "navigation.maneuver.continue"
    }

    private var activeInstructionSymbol: String {
        if let maneuverType = activeRouteStep?.maneuverType,
           ["roundabout", "rotary"].contains(maneuverType) {
            return "arrow.clockwise"
        }
        guard let modifier = activeRouteStep?.maneuverModifier?.lowercased() else {
            return activeRouteStep?.maneuverType == "arrive" ? "mappin.and.ellipse" : "arrow.up"
        }
        if modifier.contains("left") { return "arrow.turn.up.left" }
        if modifier.contains("right") { return "arrow.turn.up.right" }
        if modifier == "uturn" { return "arrow.uturn.backward" }
        return "arrow.up"
    }

    private var activeDistanceLabelKey: String {
        activeRouteStep == nil || activeRouteStep?.maneuverType == "arrive"
            ? "navigation.distance_to_destination"
            : "navigation.distance_to_turn"
    }

    private var activeStreetName: String {
        activeRouteStep?.streetName
            ?? routeTarget?.street
            ?? AppLocalization.string("navigation.street_unavailable", locale: locale)
    }

    private var activeRemainingDistanceMeters: Double {
        guard let routePlan else { return 0 }
        return max(0, routePlan.distanceMeters - routeProgressMeters)
    }

    private var previewAlternativeRoutes: [RoutePlan] {
        guard let selectedID = routePreviewPlan?.id else { return routePreviewOptions }
        return routePreviewOptions.filter { $0.id != selectedID }
    }

    private var previewAlternativeLabels: [UUID: String] {
        guard let selected = routePreviewPlan else { return [:] }
        return Dictionary(uniqueKeysWithValues: previewAlternativeRoutes.map { route in
            let difference = route.durationMinutes - selected.durationMinutes
            let key = difference == 0
                ? "directions.alternative_time_similar"
                : "directions.alternative_time_difference_format"
            let format = AppLocalization.string(key, locale: locale)
            let arguments: [CVarArg] = difference == 0 ? [] : [difference]
            let label = difference == 0
                ? format
                : String(format: format, locale: locale, arguments: arguments)
            return (route.id, label)
        })
    }

    private var activeDistanceToTurnMeters: Double {
        guard let activeRouteStep else { return activeRemainingDistanceMeters }
        return max(0, activeRouteStep.distanceFromStartMeters - routeProgressMeters)
    }

    private func updateVoiceGuidance() {
        guard isNavigationActive,
              !voiceGuidance.isMuted,
              let routePlan,
              let step = activeRouteStep else { return }
        let distance = max(0, step.distanceFromStartMeters - routeProgressMeters)
        guard distance <= 500 else { return }

        let phase = distance <= 150 ? "near" : "upcoming"
        let announcementID = "\(routePlan.id.uuidString):\(step.id):\(phase)"
        guard !spokenGuidanceIDs.contains(announcementID) else { return }
        spokenGuidanceIDs.insert(announcementID)

        let speechLocale = Locale(identifier: speechLanguageCode)
        let maneuver = AppLocalization.string(step.instructionLocalizationKey, locale: speechLocale)
        let format = AppLocalization.string("navigation.voice.in_distance_format", locale: speechLocale)
        let message = String(
            format: format,
            locale: speechLocale,
            arguments: [navigationDistanceText(distance, formatLocale: speechLocale), maneuver]
        )
        voiceGuidance.speak(message, languageCode: speechLanguageCode)
    }

    private var navigationETA: String {
        guard let routePlan, routePlan.distanceMeters > 0 else {
            return String(format: AppLocalization.string("navigation.remaining_minutes_format", locale: locale), locale: locale, arguments: [0])
        }
        let remainingFraction = activeRemainingDistanceMeters / routePlan.distanceMeters
        let minutes = Int(ceil(routePlan.durationSeconds * remainingFraction / 60))
        return String(format: AppLocalization.string("navigation.remaining_minutes_format", locale: locale), locale: locale, arguments: [max(0, minutes)])
    }

    private var navigationShareItem: String {
        let destination = routeTarget
        let coordinateText: String
        if let coordinate = destination?.coordinate {
            coordinateText = String(
                format: AppLocalization.string("place.coordinates_format", locale: locale),
                locale: locale,
                arguments: [coordinate.latitude, coordinate.longitude]
            )
        } else {
            coordinateText = ""
        }
        let format = AppLocalization.string("navigation.share_eta_message_format", locale: locale)
        return String(
            format: format,
            locale: locale,
            arguments: [navigationETA, destination?.name ?? "", coordinateText]
        )
    }

    private func navigationDistanceText(_ meters: Double, formatLocale: Locale? = nil) -> String {
        let displayLocale = formatLocale ?? locale
        let formatKey: String
        let value: Double
        if meters < 1_000 {
            formatKey = "navigation.distance_meters_format"
            value = meters
        } else if distanceUnit == "mi" {
            formatKey = "navigation.distance_miles_format"
            value = meters / 1_609.344
        } else {
            formatKey = "navigation.distance_km_format"
            value = meters / 1_000
        }
        return String(format: AppLocalization.string(formatKey, locale: displayLocale), locale: displayLocale, arguments: [value])
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
                    selectPlace(place)
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
                    selectPlace(place)
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
        case .quickStops:
            QuickStopPickerSheet(
                places: stopSearchResults,
                selectedCategory: selectedStopCategory,
                isSearching: isSearchingStops,
                errorMessage: stopSearchError,
                glassIntensity: liquidGlassIntensity,
                onSearch: searchStops,
                onSelect: addStopAndUpdateRoute,
                onDismiss: closeQuickStopPicker
            )
        case .mapSettings:
            MapSettingsSheet(
                mapDisplayMode: $mapDisplayMode,
                voiceLanguage: $navigationVoiceLanguage,
                selectedLanguage: $selectedLanguage,
                locale: locale,
                glassIntensity: liquidGlassIntensity
            )
        case .parkedCar:
            if let parkedCar = localStore.parkedCarLocation {
                ParkedCarSheet(
                    parkedCar: parkedCar,
                    locale: locale,
                    glassIntensity: liquidGlassIntensity,
                    onWalkBack: {
                        let destination = Place(
                            id: "parked-car",
                            name: AppLocalization.string("parked_car.title", locale: locale),
                            street: nil,
                            city: nil,
                            country: nil,
                            coordinate: parkedCar.coordinate
                        )
                        startRoute(to: destination, mode: .walking)
                    },
                    onDelete: {
                        localStore.removeParkedCarLocation()
                        activeSheet = nil
                    }
                )
            } else {
                EmptyView()
            }
        case .categories:
            MapCategoriesSheet(
                locale: locale,
                onSelectCategory: { category in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    selectedTab = .location
                    selectPlace(place)
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

    private func openQuickPlace(_ slot: QuickPlaceSlot) {
        if let place = localStore.quickPlace(for: slot) {
            startRoute(to: place)
            return
        }
        if let focusedPlace {
            localStore.setQuickPlace(focusedPlace, for: slot)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if let coordinate = locationManager.coordinate {
            saveQuickPlace(slot, at: coordinate)
        } else {
            pendingQuickPlaceSlot = slot
            locationManager.requestLocation()
        }
    }

    private func saveQuickPlace(_ slot: QuickPlaceSlot, at coordinate: GeoCoordinate) {
        let place = Place(
            id: "quick-\(slot.rawValue)",
            name: AppLocalization.string(slot.localizationKey, locale: locale),
            street: nil,
            city: nil,
            country: nil,
            coordinate: coordinate
        )
        localStore.setQuickPlace(place, for: slot)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func openQuickStopPicker() {
        searchFocused = false
        stopSearchTask?.cancel()
        stopSearchTask = nil
        stopSearchRequestID = UUID()
        stopSearchResults = []
        selectedStopCategory = nil
        stopSearchError = nil
        isSearchingStops = false
        activeSheet = .quickStops
    }

    private func closeQuickStopPicker() {
        stopSearchTask?.cancel()
        stopSearchTask = nil
        stopSearchRequestID = UUID()
        stopSearchResults = []
        selectedStopCategory = nil
        stopSearchError = nil
        isSearchingStops = false
        activeSheet = nil
    }

    private func searchStops(for category: AssistantPlaceCategory) {
        stopSearchTask?.cancel()
        selectedStopCategory = category
        stopSearchResults = []
        stopSearchError = nil
        isSearchingStops = true
        let requestID = UUID()
        stopSearchRequestID = requestID
        let origin = routePlan?.coordinate(atProgressMeters: routeProgressMeters + 1_500)
            ?? locationManager.coordinate
            ?? mapCenter
        let language = currentLanguage
        stopSearchTask = Task {
            do {
                let matches = try await assistantService.nearbyPlaces(
                    for: category,
                    near: origin,
                    language: language
                )
                guard !Task.isCancelled, stopSearchRequestID == requestID else { return }
                if let routePlan {
                    stopSearchResults = matches.filter {
                        routePlan.distanceFromRouteMeters(near: $0.coordinate) <= 350
                            && routePlan.progressMeters(near: $0.coordinate) >= max(0, routeProgressMeters - 200)
                    }
                } else {
                    stopSearchResults = matches
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, stopSearchRequestID == requestID else { return }
                stopSearchError = localizedSearchFailure(for: error)
            }
            guard stopSearchRequestID == requestID else { return }
            isSearchingStops = false
        }
    }

    private func addStopAndUpdateRoute(_ place: Place) {
        guard isNavigationActive, let destination = routeTarget else { return }
        guard !navigationStops.contains(where: { $0.id == place.id }) else {
            activeSheet = nil
            return
        }
        guard let origin = navigationOrigin else {
            showNavigationLocationUnavailable()
            return
        }
        let targetID = destination.id
        let stops = navigationStops + [place]
        navigationStops = stops
        activeSheet = nil
        stopSearchTask?.cancel()
        isRerouting = true
        rerouteTask?.cancel()
        rerouteTask = Task {
            do {
                let options = try await routeService.routes(
                    from: origin,
                    to: destination.coordinate,
                    mode: activeTransportMode,
                    alternatives: false,
                    waypoints: stops.map(\.coordinate)
                )
                guard !Task.isCancelled, isNavigationActive, routeTarget?.id == targetID else { return }
                guard NavigationLocationPolicy.routeMatchesRemainingStops(
                    requested: stops, remaining: navigationStops
                ) else {
                    restartRerouteForRemainingStops()
                    return
                }
                guard let updatedPlan = options.first else { throw RouteError.noRoute }
                withAnimation(.easeInOut(duration: 0.3)) {
                    routePlan = updatedPlan
                    routeAlternatives = Array(options.dropFirst())
                    routeProgressMeters = 0
                }
                spokenGuidanceIDs.removeAll()
                updateVoiceGuidance()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, routeTarget?.id == targetID else { return }
                navigationStops.removeAll { $0.id == place.id }
                activeErrorTitle = AppLocalization.string("directions.error_title", locale: locale)
                activeErrorMessage = AppLocalization.string("directions.error_message", locale: locale)
            }
            guard !Task.isCancelled, routeTarget?.id == targetID else { return }
            isRerouting = false
            rerouteTask = nil
        }
    }

    private func saveParkedCarLocation() {
        guard !isWaitingToSaveCarLocation else { return }
        if let coordinate = locationManager.coordinate {
            localStore.saveParkedCar(at: coordinate)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            activeErrorTitle = AppLocalization.string("settings.location_permission_title", locale: locale)
            activeErrorMessage = AppLocalization.string("settings.location_permission_message", locale: locale)
            return
        }

        isWaitingToSaveCarLocation = true
        locationManager.requestLocation()
        parkedCarLocationRequestTask?.cancel()
        parkedCarLocationRequestTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 15_000_000_000)
            } catch {
                return
            }
            guard isWaitingToSaveCarLocation else { return }
            isWaitingToSaveCarLocation = false
            activeErrorTitle = AppLocalization.string("settings.location_unavailable_title", locale: locale)
            activeErrorMessage = AppLocalization.string("settings.location_unavailable_message", locale: locale)
        }
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

    private func checkForOffRouteLocation(_ coordinate: GeoCoordinate, routePlan: RoutePlan) {
        guard (locationManager.horizontalAccuracyMeters ?? .greatestFiniteMagnitude) <= 50 else {
            offRouteFixCount = 0
            return
        }
        if routePlan.distanceFromRouteMeters(near: coordinate) > 55 {
            offRouteFixCount += 1
        } else {
            offRouteFixCount = 0
        }
        guard offRouteFixCount >= 2 else { return }
        if let lastRerouteAt, Date().timeIntervalSince(lastRerouteAt) < 20 { return }
        requestAutomaticReroute(from: coordinate)
    }

    private func requestAutomaticReroute(from origin: GeoCoordinate) {
        guard isNavigationActive, !isRerouting, let destination = routeTarget else { return }
        let targetID = destination.id
        isRerouting = true
        lastRerouteAt = Date()
        offRouteFixCount = 0
        let stops = navigationStops
        rerouteTask?.cancel()
        rerouteTask = Task {
            do {
                let options = try await routeService.routes(
                    from: origin,
                    to: destination.coordinate,
                    mode: activeTransportMode,
                    alternatives: false,
                    waypoints: stops.map(\.coordinate)
                )
                guard !Task.isCancelled,
                      isNavigationActive,
                      routeTarget?.id == targetID else { return }
                guard NavigationLocationPolicy.routeMatchesRemainingStops(
                    requested: stops, remaining: navigationStops
                ) else {
                    restartRerouteForRemainingStops()
                    return
                }
                guard let updatedPlan = options.first else { throw RouteError.noRoute }
                withAnimation(.easeInOut(duration: 0.3)) {
                    routePlan = updatedPlan
                    routeAlternatives = Array(options.dropFirst())
                    routeProgressMeters = 0
                }
                routePreviewPlan = updatedPlan
                routePreviewPlaceID = targetID
                spokenGuidanceIDs.removeAll()
                updateVoiceGuidance()
            } catch {
                // Keep following the existing route if a fresh route cannot be fetched.
            }
            guard !Task.isCancelled, routeTarget?.id == targetID else { return }
            isRerouting = false
            rerouteTask = nil
        }
    }

    private func restartRerouteForRemainingStops() {
        isRerouting = false
        rerouteTask = nil
        guard let origin = navigationOrigin else { return }
        requestAutomaticReroute(from: origin)
    }

    private func triggerArrivalFeedbackIfNeeded() {
        guard isAtDestination, !didTriggerArrivalHaptic else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        didTriggerArrivalHaptic = true
        let arrival = AppLocalization.string("navigation.arrival.title", locale: Locale(identifier: speechLanguageCode))
        voiceGuidance.speak(arrival, languageCode: speechLanguageCode)
    }

    private func startRoute(to place: Place, mode: RouteTransportMode? = nil) {
        guard let origin = navigationOrigin else {
            showNavigationLocationUnavailable()
            return
        }
        if place.id != "parked-car" {
            localStore.addRecentPlace(place)
        }
        let requestedMode = mode ?? selectedTransportMode
        activeTransportMode = requestedMode
        routeTask?.cancel()
        rerouteTask?.cancel()
        isRerouting = false
        offRouteFixCount = 0
        lastRerouteAt = nil
        spokenGuidanceIDs.removeAll()
        didTriggerArrivalHaptic = false
        voiceGuidance.stop()
        routePreviewTask?.cancel()
        navigationStops = []
        activeSheet = nil
        searchFocused = false
        if isNavigationActive {
            locationManager.stopNavigationTracking()
            isNavigationActive = false
        }
        routeProgressMeters = 0
        isRouting = true
        routeTarget = place
        isPreviewingRoute = false
        routePreviewUnavailable = false
        // Previews may start at the browsed map center. Fetch the active route
        // from the validated user fix instead of reusing that preview.
        routePlan = nil
        routeAlternatives = []
        routeTask = Task {
            defer { isRouting = false }
            do {
                let options = try await routeService.routes(
                    from: origin,
                    to: place.coordinate,
                    mode: requestedMode,
                    alternatives: true,
                    waypoints: []
                )
                guard !Task.isCancelled else { return }
                guard let result = options.first else { throw RouteError.noRoute }
                routePlan = result
                routeAlternatives = Array(options.dropFirst())
                routePreviewPlan = result
                routePreviewOptions = options
                routePreviewPlaceID = place.id
                focusedPlace = place
                beginActiveNavigation()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                locationManager.stopNavigationTracking()
                isNavigationActive = false
                routeTarget = nil
                routePreviewUnavailable = true
                activeErrorTitle = AppLocalization.string("directions.error_title", locale: locale)
                activeErrorMessage = AppLocalization.string("directions.error_message", locale: locale)
            }
        }
    }

    private var navigationOrigin: GeoCoordinate? {
        NavigationLocationPolicy.origin(
            coordinate: locationManager.coordinate,
            timestamp: locationManager.lastLocationTimestamp,
            accuracy: locationManager.horizontalAccuracyMeters,
            isAuthorized: locationManager.authorizationStatus == .authorizedAlways
                || locationManager.authorizationStatus == .authorizedWhenInUse
        )
    }

    private func showNavigationLocationUnavailable() {
        locationManager.requestLocation()
        activeErrorTitle = AppLocalization.string("settings.location_unavailable_title", locale: locale)
        activeErrorMessage = AppLocalization.string("settings.location_unavailable_message", locale: locale)
    }

    private func beginActiveNavigation() {
        routeProgressMeters = 0
        isNavigationActive = true
        locationManager.startNavigationTracking()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        updateVoiceGuidance()
        triggerArrivalFeedbackIfNeeded()
    }

    private func finishActiveNavigation() {
        rerouteTask?.cancel()
        rerouteTask = nil
        stopSearchTask?.cancel()
        stopSearchRequestID = UUID()
        isSearchingStops = false
        isRerouting = false
        voiceGuidance.stop()
        locationManager.stopNavigationTracking()
        isNavigationActive = false
        routePlan = nil
        routeAlternatives = []
        routeTarget = nil
        navigationStops = []
        routeProgressMeters = 0
        isRouting = false
        offRouteFixCount = 0
        didTriggerArrivalHaptic = false
    }
}

private enum HomeSheet: Identifiable {
    case place(Place)
    case saved
    case addPlace(GeoCoordinate)
    case report(GeoCoordinate)
    case quickStops
    case mapSettings
    case parkedCar
    case categories
    case assistant

    var id: String {
        switch self {
        case .place(let place): return "place-\(place.id)"
        case .saved: return "saved"
        case .addPlace(let coordinate): return "add-\(coordinate.latitude)-\(coordinate.longitude)"
        case .report(let coordinate): return "report-\(coordinate.latitude)-\(coordinate.longitude)"
        case .quickStops: return "quick-stops"
        case .mapSettings: return "map-settings"
        case .parkedCar: return "parked-car"
        case .categories: return "categories"
        case .assistant: return "assistant"
        }
    }
}
