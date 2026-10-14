import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case location
    case assistant
    case categories
    case settings

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .location: "location.my_location"
        case .assistant: "navigation.assistant"
        case .categories: "navigation.categories"
        case .settings: "navigation.settings"
        }
    }

    var icon: String {
        switch self {
        case .location: "CurvedLocation"
        case .assistant: "CurvedAssistant"
        case .categories: "CurvedCategories"
        case .settings: "CurvedSettings"
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
        .primary
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
        HStack(spacing: 0) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background {
            capsuleSurface(useNativeGlass: useNativeGlass)
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.14 : 0.38),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .clipShape(Capsule())
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.09),
            radius: 12,
            x: 0,
            y: 3
        )
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let foreground = isSelected ? selectedTextColor : unselectedColor
        let title = AppLocalization.string(tab.titleKey, locale: locale)

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.06)) {
                selection = tab
            }
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                tabIcon(for: tab)
                    .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
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
            .opacity(normalizedGlassIntensity)
    }

    private var selectionHighlightColor: Color {
        colorScheme == .dark ? .black.opacity(0.24) : .black.opacity(0.055)
    }
}
