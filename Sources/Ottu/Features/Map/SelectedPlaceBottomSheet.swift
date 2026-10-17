import SwiftUI

struct SelectedPlaceBottomSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var isExpanded = true

    let place: Place
    let routeSummary: String?
    let isEstimatingRoute: Bool
    let routeEstimateUnavailable: Bool
    let isStartingRoute: Bool
    let isSaved: Bool
    let isHomePlace: Bool
    let isWorkPlace: Bool
    let transportMode: RouteTransportMode
    let glassIntensity: Double
    let onStartTrip: () -> Void
    let onToggleSaved: () -> Void
    let onSetHome: () -> Void
    let onSetWork: () -> Void
    let onSelectTransportMode: (RouteTransportMode) -> Void
    let onShowDetails: () -> Void
    let onDismiss: () -> Void

    private var cardAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.84)
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(cardAnimation) { isExpanded.toggle() }
            } label: {
                Capsule()
                    .fill(Color.primary.opacity(0.24))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppLocalization.string("map.sheet.drag_hint", locale: locale)))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onShowDetails) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AppLocalization.string("place.details", locale: locale)))

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AppLocalization.string("common.close", locale: locale)))
            }

            if isExpanded {
                transportModePicker

                routeEstimate
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onStartTrip) {
                    HStack(spacing: 9) {
                        if isStartingRoute {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                        AppLocalizedText(isStartingRoute ? "directions.calculating" : "directions.start_trip", locale: locale)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isStartingRoute)

                HStack(spacing: 10) {
                    Button(action: onToggleSaved) {
                        AppLocalizedLabel(
                            isSaved ? "place.saved" : "place.save",
                            systemImage: isSaved ? "bookmark.fill" : "bookmark",
                            locale: locale
                        )
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: place.openStreetMapURL) {
                        AppLocalizedLabel("place.share", systemImage: "square.and.arrow.up", locale: locale)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    quickPlaceButton(
                        titleKey: isHomePlace ? "quick_places.home" : "quick_places.set_home",
                        symbol: "house.fill",
                        isSelected: isHomePlace,
                        action: onSetHome
                    )
                    quickPlaceButton(
                        titleKey: isWorkPlace ? "quick_places.work" : "quick_places.set_work",
                        symbol: "briefcase.fill",
                        isSelected: isWorkPlace,
                        action: onSetWork
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .mapGlassSurface(cornerRadius: 28, glassIntensity: glassIntensity)
        .offset(y: max(0, dragTranslation * 0.16))
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height > 48 {
                        withAnimation(cardAnimation) { isExpanded = false }
                    } else if value.translation.height < -48 {
                        withAnimation(cardAnimation) { isExpanded = true }
                    }
                }
        )
        .animation(cardAnimation, value: isExpanded)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var routeEstimate: some View {
        HStack(spacing: 8) {
            Image(systemName: transportMode.systemImage)
                .foregroundStyle(.tint)
            if let routeSummary {
                Text(routeSummary)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.primary)
            } else if isEstimatingRoute {
                AppLocalizedText("directions.calculating", locale: locale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if routeEstimateUnavailable {
                AppLocalizedText("directions.estimate_unavailable", locale: locale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 20)
    }

    private var transportModePicker: some View {
        HStack(spacing: 8) {
            ForEach(RouteTransportMode.allCases, id: \.rawValue) { mode in
                let isSelected = transportMode == mode
                Button {
                    onSelectTransportMode(mode)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                        AppLocalizedText(mode.localizationKey, locale: locale)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .mapGlassSurface(cornerRadius: 16, glassIntensity: glassIntensity)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func quickPlaceButton(
        titleKey: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            AppLocalizedLabel(titleKey, systemImage: symbol, locale: locale)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .mapGlassSurface(cornerRadius: 14, glassIntensity: glassIntensity)
        }
        .buttonStyle(.plain)
    }
}
