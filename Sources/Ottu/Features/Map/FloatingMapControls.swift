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

            zoomControlPill

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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .contentShape(Circle())
                .mapGlassCircleSurface(glassIntensity: glassIntensity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppLocalization.string(accessibilityKey, locale: locale)))
    }

    private var zoomControlPill: some View {
        VStack(spacing: 0) {
            zoomButton(
                systemName: "plus",
                accessibilityKey: "map.zoom_in",
                action: onZoomIn
            )

            Rectangle()
                .fill(Color.white.opacity(0.42))
                .frame(width: 24, height: 1)
                .allowsHitTesting(false)

            zoomButton(
                systemName: "minus",
                accessibilityKey: "map.zoom_out",
                action: onZoomOut
            )
        }
        .mapGlassSurface(cornerRadius: 22, glassIntensity: glassIntensity)
        .accessibilityElement(children: .contain)
    }

    private func zoomButton(
        systemName: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 42, height: 39)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppLocalization.string(accessibilityKey, locale: locale)))
    }
}
