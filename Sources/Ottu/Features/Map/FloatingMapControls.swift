import SwiftUI
import UIKit

struct FloatingMapControls: View {
    @Environment(\.locale) private var locale

    let onLocate: () -> Void
    let onSaveCar: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 14) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onLocate()
                } label: {
                    Image(MapNavigationTab.location.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.primary)
                        .frame(width: 46, height: 46)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: Circle())
                .accessibilityIdentifier("mapTab.location")
                .accessibilityLabel(Text(AppLocalization.string("navigation.location", locale: locale)))

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSaveCar()
                } label: {
                    Image(systemName: "car.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .frame(width: 46, height: 46)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: Circle())
                .accessibilityIdentifier("mapSaveCar")
                .accessibilityLabel(Text(AppLocalization.string("parked_car.save", locale: locale)))
            }
        }
        .accessibilityElement(children: .contain)
    }
}
