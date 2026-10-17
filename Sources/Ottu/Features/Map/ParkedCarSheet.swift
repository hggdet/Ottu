import SwiftUI

struct ParkedCarSheet: View {
    let parkedCar: ParkedCarLocation
    let locale: Locale
    let glassIntensity: Double
    let onWalkBack: () -> Void
    let onDelete: () -> Void

    private var savedAtText: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let time = formatter.string(from: parkedCar.savedAt)
        return String(
            format: AppLocalization.string("parked_car.saved_at", locale: locale),
            locale: locale,
            arguments: [time]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .mapGlassCircleSurface(glassIntensity: glassIntensity)

                VStack(alignment: .leading, spacing: 4) {
                    AppLocalizedText("parked_car.title", locale: locale)
                        .font(.title3.weight(.bold))
                    Text(savedAtText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Button(action: onWalkBack) {
                HStack(spacing: 9) {
                    Image(systemName: "figure.walk")
                    AppLocalizedText("parked_car.walk_back", locale: locale)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    AppLocalizedText("parked_car.delete", locale: locale)
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .mapGlassSurface(cornerRadius: 16, glassIntensity: glassIntensity)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapGlassSurface(cornerRadius: 26, glassIntensity: glassIntensity)
        .environment(\.locale, locale)
        .environment(\.layoutDirection, AppLocalization.isRightToLeft(locale) ? .rightToLeft : .leftToRight)
    }
}
