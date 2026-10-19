import SwiftUI

/// Native iOS 26 Liquid Glass. Never layer an opaque fill, a material fallback,
/// or a simulated highlight over the system's optical rendering.
struct MapGlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct MapGlassCircleSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: Circle())
    }
}

extension View {
    // Preserve the shared call-site signature while retiring the old opacity
    // slider. The system controls glass rendering and accessibility contrast.
    func mapGlassSurface(cornerRadius: CGFloat = 24, glassIntensity: Double = 1) -> some View {
        modifier(MapGlassSurface(cornerRadius: cornerRadius))
    }

    func mapGlassCircleSurface(glassIntensity: Double = 1) -> some View {
        modifier(MapGlassCircleSurface())
    }
}
