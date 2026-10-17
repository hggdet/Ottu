import SwiftUI
import UIKit

struct FloatingMapControls: View {
    @Environment(\.locale) private var locale

    let glassIntensity: Double
    let onLocate: () -> Void
    let onSaveCar: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onOpenMapSettings: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            controlButton(
                systemName: "location.fill",
                accessibilityKey: "location.my_location",
                tint: .green,
                action: onLocate
            )

            controlButton(
                systemName: "car.fill",
                accessibilityKey: "parked_car.save",
                tint: .orange,
                action: onSaveCar
            )

            controlButton(
                systemName: "plus",
                accessibilityKey: "map.zoom_in",
                action: onZoomIn
            )

            controlButton(
                systemName: "minus",
                accessibilityKey: "map.zoom_out",
                action: onZoomOut
            )

            controlButton(
                systemName: "square.3.layers.3d",
                accessibilityKey: "map.settings.open",
                action: onOpenMapSettings
            )
        }
        .padding(5)
        .accessibilityElement(children: .contain)
    }

    private func controlButton(
        systemName: String,
        accessibilityKey: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
                .mapGlassCircleSurface(glassIntensity: glassIntensity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppLocalization.string(accessibilityKey, locale: locale)))
    }
}
