import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case location
    case categories
    case settings
    case assistant

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .location: "location.my_location"
        case .categories: "navigation.categories"
        case .settings: "navigation.settings"
        case .assistant: "navigation.assistant"
        }
    }

    var icon: String {
        switch self {
        case .location: "IconlyLocation"
        case .categories: "IconlyCategory"
        case .settings: "IconlySetting"
        case .assistant: "sparkles"
        }
    }
}

struct FloatingGlassNavigationBar: View {
    @Binding var selection: MapNavigationTab
    var glassIntensity: Double = 1
    var onSelect: (MapNavigationTab) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Namespace private var selectionAnimation

    private var normalizedGlassIntensity: Double {
        min(max(glassIntensity, 0), 1)
    }

    private var selectedColor: Color {
        .black
    }

    private var unselectedColor: Color {
        .gray
    }

    private var opaqueSurfaceColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        adaptiveNavigationBar
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var adaptiveNavigationBar: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                navigationButtons(useNativeGlass: true)
            }
        } else {
            navigationButtons(useNativeGlass: false)
        }
#else
        navigationButtons(useNativeGlass: false)
#endif
    }

    private func navigationButtons(useNativeGlass: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab, useNativeGlass: useNativeGlass)
            }
        }
    }

    private func tabButton(for tab: MapNavigationTab, useNativeGlass: Bool) -> some View {
        let isSelected = selection == tab
        let foreground = isSelected ? selectedColor : unselectedColor
        let title = AppLocalization.string(tab.titleKey, locale: locale)

        return Button {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.72, blendDuration: 0.12)) {
                selection = tab
            }
            onSelect(tab)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(opaqueSurfaceColor.opacity(1 - normalizedGlassIntensity))

                    glassLayer(useNativeGlass: useNativeGlass)

                    if isSelected {
                        selectedHighlightCircle
                            .matchedGeometryEffect(id: "selected-tab-glass", in: selectionAnimation)
                    }

                    if tab == .assistant {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 18, height: 18)
                            .foregroundStyle(foreground)
                            .symbolEffect(.bounce, value: isSelected)
                            .contentTransition(.symbolEffect(.replace))
                            .scaleEffect(isSelected ? 1.04 : 1)
                    } else {
                        Image(tab.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(foreground)
                            .symbolEffect(.bounce, value: isSelected)
                            .contentTransition(.symbolEffect(.replace))
                            .scaleEffect(isSelected ? 1.04 : 1)
                    }
                }
                .frame(width: 50, height: 50)

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func glassLayer(useNativeGlass: Bool) -> some View {
        if normalizedGlassIntensity > 0 {
#if compiler(>=6.2)
            if #available(iOS 26.0, *), useNativeGlass {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .opacity(normalizedGlassIntensity)
            } else {
                fallbackGlassSurface
            }
#else
            fallbackGlassSurface
#endif
        }
    }

    private var fallbackGlassSurface: some View {
        decoratedGlassSurface(Circle().fill(.ultraThinMaterial))
    }

    private var glassHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.24 : 0.68),
                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.24),
                Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func decoratedGlassSurface<Surface: View>(_ surface: Surface) -> some View {
        surface
            .overlay {
                Circle().fill(glassHighlight)
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.38 : 0.74),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14),
                radius: 7,
                x: 0,
                y: 3
            )
            .opacity(normalizedGlassIntensity)
    }

    private var selectedHighlightCircle: some View {
        Circle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.045))
    }
}
