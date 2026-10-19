import SwiftUI
import UIKit

struct FloatingMapControls: View {
    @Environment(\.locale) private var locale

    let glassIntensity: Double
    let onSaveCar: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onOpenMapSettings: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 14) {
                // Location already has a dedicated bottom tab; do not repeat it.
                controlButton(
                    systemName: "car.fill",
                    accessibilityKey: "parked_car.save",
                    action: onSaveCar
                )

                zoomControlPill

                controlButton(
                    systemName: "slider.horizontal.3",
                    accessibilityKey: "map.settings.open",
                    action: onOpenMapSettings
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func controlButton(
        systemName: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Circle())
        .accessibilityLabel(Text(AppLocalization.string(accessibilityKey, locale: locale)))
    }

    private var zoomControlPill: some View {
        VStack(spacing: 0) {
            zoomButton(systemName: "plus", accessibilityKey: "map.zoom_in", action: onZoomIn)
            Divider().frame(width: 22).allowsHitTesting(false)
            zoomButton(systemName: "minus", accessibilityKey: "map.zoom_out", action: onZoomOut)
        }
        .glassEffect(.clear.interactive(), in: Capsule())
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 46, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppLocalization.string(accessibilityKey, locale: locale)))
    }
}
