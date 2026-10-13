import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case home
    case categories
    case settings
    case saved

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: "navigation.home"
        case .categories: "navigation.categories"
        case .settings: "navigation.settings"
        case .saved: "navigation.saved"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .categories: "square.grid.2x2.fill"
        case .settings: "gearshape.fill"
        case .saved: "bookmark.fill"
        }
    }
}

struct FloatingGlassNavigationBar: View {
    @Binding var selection: MapNavigationTab
    var onSelect: (MapNavigationTab) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionAnimation

    private var selectedColor: Color { .black }
    private var unselectedColor: Color { .gray }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.14 : 0.52),
                                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.38 : 0.90),
                                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.12), radius: 20, x: 0, y: 9)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.04 : 0.58), radius: 1, x: 0, y: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: MapNavigationTab) -> some View {
        let isSelected = selection == tab
        let foreground = isSelected ? selectedColor : unselectedColor

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selection = tab
            }
            onSelect(tab)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(foreground)
                    .frame(width: 48, height: 38)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(colorScheme == .dark ? 0.26 : 0.76),
                                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.30)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .overlay {
                                    Capsule()
                                        .strokeBorder(
                                            Color.white.opacity(colorScheme == .dark ? 0.30 : 0.76),
                                            lineWidth: 1
                                        )
                                }
                                .matchedGeometryEffect(id: "selected-tab-glass", in: selectionAnimation)
                        }
                    }

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
}
