import SwiftUI

enum MapNavigationTab: String, CaseIterable, Identifiable {
    case home
    case search
    case categories

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: "navigation.home"
        case .search: "navigation.search"
        case .categories: "navigation.categories"
        }
    }

    var icon: MapNavigationIcon.Kind {
        switch self {
        case .home: .home
        case .search: .search
        case .categories: .categories
        }
    }
}

struct FloatingGlassNavigationBar: View {
    @Binding var selection: MapNavigationTab
    var onSelect: (MapNavigationTab) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionAnimation

    private var selectedColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }

    private var unselectedColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.58) : Color.gray.opacity(0.78)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MapNavigationTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
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
                MapNavigationIcon(kind: tab.icon)
                    .stroke(
                        foreground,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 23, height: 23)

                Text(tab.title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.045))
                        .matchedGeometryEffect(id: "selected-tab", in: selectionAnimation)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MapNavigationIcon: Shape {
    enum Kind {
        case home
        case search
        case categories
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let originX = rect.midX - side / 2
        let originY = rect.midY - side / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + side * x, y: originY + side * y)
        }

        var path = Path()

        switch kind {
        case .home:
            path.move(to: point(0.14, 0.48))
            path.addQuadCurve(to: point(0.24, 0.30), control: point(0.15, 0.36))
            path.addLine(to: point(0.44, 0.13))
            path.addQuadCurve(to: point(0.56, 0.13), control: point(0.50, 0.08))
            path.addLine(to: point(0.76, 0.30))
            path.addQuadCurve(to: point(0.86, 0.48), control: point(0.85, 0.36))
            path.addLine(to: point(0.82, 0.78))
            path.addQuadCurve(to: point(0.72, 0.88), control: point(0.81, 0.88))
            path.addLine(to: point(0.28, 0.88))
            path.addQuadCurve(to: point(0.18, 0.78), control: point(0.19, 0.88))
            path.closeSubpath()
            path.move(to: point(0.41, 0.87))
            path.addLine(to: point(0.41, 0.69))
            path.addQuadCurve(to: point(0.59, 0.69), control: point(0.50, 0.59))
            path.addLine(to: point(0.59, 0.87))

        case .search:
            path.addEllipse(in: CGRect(x: originX + side * 0.14, y: originY + side * 0.12, width: side * 0.55, height: side * 0.55))
            path.move(to: point(0.59, 0.59))
            path.addQuadCurve(to: point(0.86, 0.86), control: point(0.73, 0.73))

        case .categories:
            let tileSize = side * 0.30
            let corner = CGSize(width: side * 0.09, height: side * 0.09)
            let tileOrigins: [(CGFloat, CGFloat)] = [
                (0.17, 0.17), (0.53, 0.17),
                (0.17, 0.53), (0.53, 0.53)
            ]
            for (x, y) in tileOrigins {
                path.addRoundedRect(
                    in: CGRect(x: originX + side * x, y: originY + side * y, width: tileSize, height: tileSize),
                    cornerSize: corner,
                    style: .continuous
                )
            }
        }

        return path
    }
}
