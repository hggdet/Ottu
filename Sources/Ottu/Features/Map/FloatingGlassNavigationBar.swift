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
        case .location: "FlaticonLocationPin"
        case .assistant: "FlaticonAssistantOutline"
        case .categories: "FlaticonCategories"
        case .settings: "FlaticonSettings"
        }
    }

    // Account for each original PNG's transparent margins and visual density.
    var iconSize: CGFloat {
        switch self {
        case .location: 22
        case .assistant: 20
        case .categories, .settings: 24
        }
    }
}

struct FloatingGlassNavigationBar: View {
    @Binding var selection: MapNavigationTab
    var glassIntensity: Double = 1
    var onSelect: (MapNavigationTab) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(alignment: .bottom) {
                tabButton(for: .assistant)
                Spacer(minLength: 16)
                VStack(spacing: 14) {
                    tabButton(for: .categories)
                    tabButton(for: .settings)
                }
            }
        }
        // Keep the controls on the same physical side in every interface language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityIdentifier("mapNavigationBar")
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let title = AppLocalization.string(tab.titleKey, locale: locale)

        return Button {
            selection = tab
            onSelect(tab)
        } label: {
            Image(tab.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: tab.iconSize, height: tab.iconSize)
                .foregroundStyle(isSelected ? Color.green : Color.primary)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityIdentifier("mapTab.\(tab.rawValue)")
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
