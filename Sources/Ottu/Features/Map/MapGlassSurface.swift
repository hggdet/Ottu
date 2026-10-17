import SwiftUI

struct MapGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let glassIntensity: Double

    private var normalizedIntensity: Double {
        min(max(glassIntensity, 0), 1)
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(normalizedIntensity)
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }
}

struct MapGlassCircleSurface: ViewModifier {
    let glassIntensity: Double

    private var normalizedIntensity: Double {
        min(max(glassIntensity, 0), 1)
    }

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(normalizedIntensity)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
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
