import SwiftUI

struct MapGlassSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let glassIntensity: Double

    private var normalizedIntensity: Double {
        min(max(glassIntensity, 0), 1)
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if colorScheme == .light {
                        shape.fill(Color.white.opacity(0.45))
                    }
                }
                .opacity(normalizedIntensity)
            }
            .overlay {
                Group {
                    if colorScheme == .light {
                        shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
                    } else {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    }
                }
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.12 : 0.08), radius: colorScheme == .light ? 14 : 12, y: 6)
    }
}

struct MapGlassCircleSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let glassIntensity: Double

    private var normalizedIntensity: Double {
        min(max(glassIntensity, 0), 1)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    if colorScheme == .light {
                        Circle().fill(Color.white.opacity(0.45))
                    }
                }
                .opacity(normalizedIntensity)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(colorScheme == .light ? 0.75 : 0.3), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.12 : 0.08), radius: colorScheme == .light ? 14 : 12, y: 6)
    }
}

extension View {
    func mapGlassSurface(cornerRadius: CGFloat = 24, glassIntensity: Double = 1) -> some View {
        modifier(MapGlassSurface(cornerRadius: cornerRadius, glassIntensity: glassIntensity))
    }

    func mapGlassCircleSurface(glassIntensity: Double = 1) -> some View {
        modifier(MapGlassCircleSurface(glassIntensity: glassIntensity))
    }
}
