import SwiftUI
import UIKit

struct PlaceDetailsSheet: View {
    @Environment(\.locale) private var locale
    let place: Place
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(place.name)
                        .font(.title3.weight(.semibold))
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            Text(String(
                format: AppLocalization.string("place.coordinates_format", locale: locale),
                place.coordinate.latitude,
                place.coordinate.longitude
            ))
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)

            Button(action: onReport) {
                AppLocalizedLabel("incident.report", systemImage: "exclamationmark.bubble")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }
}
