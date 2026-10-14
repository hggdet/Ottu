import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case location
    case categories
    case assistant
    case settings

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
        case .location: "CurvedLocation"
        case .categories: "CurvedCategories"
        case .settings: "CurvedSettings"
        case .assistant: "CurvedAssistant"
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

    private var selectedIconColor: Color {
        .green
    }

    private var selectedTextColor: Color {
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
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var adaptiveNavigationBar: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            navigationBar(useNativeGlass: true)
        } else {
            navigationBar(useNativeGlass: false)
        }
#else
        navigationBar(useNativeGlass: false)
#endif
    }

    private func navigationBar(useNativeGlass: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(5)
        .background {
            capsuleSurface(useNativeGlass: useNativeGlass)
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.64),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .clipShape(Capsule())
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12),
            radius: 9,
            x: 0,
            y: 3
        )
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let foreground = isSelected ? selectedTextColor : unselectedColor
        let title = AppLocalization.string(tab.titleKey, locale: locale)

        return Button {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82, blendDuration: 0.1)) {
                selection = tab
            }
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                tabIcon(for: tab)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Capsule()
                        .fill(selectionHighlightColor)
                        .matchedGeometryEffect(id: "selected-tab-capsule", in: selectionAnimation)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tabIcon(for tab: MapNavigationTab) -> some View {
        Image(tab.icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(selection == tab ? selectedIconColor : unselectedColor)
    }

    @ViewBuilder
    private func capsuleSurface(useNativeGlass: Bool) -> some View {
        ZStack {
            Capsule()
                .fill(opaqueSurfaceColor.opacity(1 - normalizedGlassIntensity))

            if normalizedGlassIntensity > 0 {
#if compiler(>=6.2)
                if #available(iOS 26.0, *), useNativeGlass {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular, in: Capsule())
                        .opacity(normalizedGlassIntensity)
                } else {
                    fallbackGlassSurface
                }
#else
                fallbackGlassSurface
#endif
            }
        }
    }

    private var fallbackGlassSurface: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule().fill(glassHighlight)
            }
            .opacity(normalizedGlassIntensity)
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

    private var selectionHighlightColor: Color {
        colorScheme == .dark ? .white.opacity(0.62) : .black.opacity(0.055)
    }
}
