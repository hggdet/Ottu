import SwiftUI
import UIKit

struct PlaceDetailsSheet: View {
    @Environment(\.locale) private var locale
    let place: Place
    let isSaved: Bool
    let onToggleSaved: () -> Void
    let onDirections: () -> Void
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

            Button(action: onDirections) {
                AppLocalizedLabel("directions.start", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button(action: onToggleSaved) {
                    AppLocalizedLabel(isSaved ? "place.saved" : "place.save", systemImage: isSaved ? "bookmark.fill" : "bookmark", locale: locale)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                ShareLink(item: place.openStreetMapURL) {
                    AppLocalizedLabel("place.share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

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
