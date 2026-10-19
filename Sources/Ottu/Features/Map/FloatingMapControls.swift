import SwiftUI
import UIKit

struct FloatingMapControls: View {
    @Binding var selection: MapNavigationTab
    @Environment(\.locale) private var locale

    let onSelect: (MapNavigationTab) -> Void

    private let orderedTabs: [MapNavigationTab] = [
        .location,
        .assistant,
        .categories,
        .settings
    ]

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 12) {
                ForEach(orderedTabs) { tab in
                    tabButton(for: tab)
                }
            }
        }
        .accessibilityIdentifier("mapNavigationBar")
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let title = AppLocalization.string(tab.titleKey, locale: locale)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .glassEffect(.clear.interactive(), in: Circle())
        .accessibilityIdentifier("mapTab.\(tab.rawValue)")
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
