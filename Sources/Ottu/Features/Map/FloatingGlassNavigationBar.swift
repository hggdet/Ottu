import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case location
    case assistant
    case categories
    case settings

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .location: "navigation.location"
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

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    private var selectionAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.86)
    }

    var body: some View {
        // Case order is semantic. SwiftUI mirrors it for RTL, placing location
        // at the right, then assistant, categories and settings to its left.
        HStack(spacing: 0) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(5)
        // Clear is Apple's native glass variant for a rich background (the map).
        // No white overlay, custom border, blur, clipping or opacity is applied.
        .glassEffect(.clear.interactive(), in: Capsule())
        .accessibilityIdentifier("mapNavigationBar")
        .accessibilityElement(children: .contain)
        .animation(reduceMotion ? nil : selectionAnimation, value: selection)
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let title = AppLocalization.string(tab.titleKey, locale: locale)

        return Button {
            selection = tab
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(tab.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Color.blue : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.blue.opacity(0.12))
                        .matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("mapTab.\(tab.rawValue)")
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
