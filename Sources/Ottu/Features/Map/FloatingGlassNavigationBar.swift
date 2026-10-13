import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case location
    case categories
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .location: "location.my_location"
        case .categories: "navigation.categories"
        case .settings: "navigation.settings"
        }
    }

    var icon: String {
        switch self {
        case .location: "IconlyLocation"
        case .categories: "IconlyCategory"
        case .settings: "IconlySetting"
        }
    }
}

struct FloatingGlassNavigationBar: View {
    @Binding var selection: MapNavigationTab
    var glassIntensity: Double = 1
    var onSelect: (MapNavigationTab) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionAnimation

    private var normalizedGlassIntensity: Double {
        min(max(glassIntensity, 0), 1)
    }

    private var selectedColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }

    private var unselectedColor: Color {
        colorScheme == .dark ? .white.opacity(0.68) : Color.black.opacity(0.56)
    }

    private var opaqueSurfaceColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let foreground = isSelected ? selectedColor : unselectedColor

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

                    glassLayer

                    if isSelected {
                        selectedHighlightCircle
                            .matchedGeometryEffect(id: "selected-tab-glass", in: selectionAnimation)
                    }

                    Image(tab.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(foreground)
                        .symbolEffect(.bounce, value: isSelected)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 58, height: 58)

                Text(tab.title)
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
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var glassLayer: some View {
        if normalizedGlassIntensity > 0 {
            if #available(iOS 26.0, *) {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .opacity(normalizedGlassIntensity)
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(normalizedGlassIntensity)
            }
        }
    }

    private var selectedHighlightCircle: some View {
        Circle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.045))
    }
}
