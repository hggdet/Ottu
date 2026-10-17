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

    var body: some View {
        adaptiveNavigationBar
            .accessibilityElement(children: .contain)
    }

    private var adaptiveNavigationBar: some View {
        navigationBar
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .mapGlassSurface(cornerRadius: 24, glassIntensity: normalizedGlassIntensity)
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
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(selectionHighlightColor)
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

    private var selectionHighlightColor: Color {
        colorScheme == .dark ? .green.opacity(0.16) : .green.opacity(0.1)
    }
}
