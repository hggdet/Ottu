import AVFoundation
import SwiftUI

@MainActor
final class NavigationVoiceGuidance: ObservableObject {
    @Published private(set) var isMuted = false

    private let synthesizer = AVSpeechSynthesizer()

    func toggleMuted() {
        isMuted.toggle()
        if isMuted {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func speak(_ message: String, languageCode: String) {
        guard !isMuted, !message.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: message)
        let speechLocale: String
        switch languageCode {
        case "ar": speechLocale = "ar-IQ"
        case "ku": speechLocale = "ku-IQ"
        default: speechLocale = "en-US"
        }
        // If iOS has no Kurdish voice installed, the system voice remains the fallback.
        utterance.voice = AVSpeechSynthesisVoice(language: speechLocale)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

struct ActiveNavigationInstructionPanel: View {
    @Environment(\.locale) private var locale
    let instruction: String
    let instructionSymbol: String
    let streetName: String
    let distanceToTurn: String
    let distanceLabelKey: String
    let glassIntensity: Double
    let isVoiceMuted: Bool
    let onToggleVoice: () -> Void
    let onAddStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: instructionSymbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    AppLocalizedText("navigation.next_instruction")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(instruction)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(streetName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(distanceToTurn)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                AppLocalizedText(distanceLabelKey)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: onToggleVoice) {
                Image(systemName: isVoiceMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isVoiceMuted ? Color.secondary : Color.accentColor)
                    .frame(width: 42, height: 42)
                    .mapGlassCircleSurface(glassIntensity: glassIntensity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppLocalization.string(
                isVoiceMuted ? "navigation.voice.unmute" : "navigation.voice.mute",
                locale: locale
            )))
            .accessibilityHint(Text(AppLocalization.string("navigation.voice.toggle_hint", locale: locale)))

            Button(action: onAddStop) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .mapGlassCircleSurface(glassIntensity: glassIntensity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppLocalization.string("navigation.add_stop", locale: locale)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapGlassSurface(cornerRadius: 24, glassIntensity: glassIntensity)
        .accessibilityElement(children: .contain)
    }
}

struct NavigationSpeedometerPill: View {
    @Environment(\.locale) private var locale
    let speedKilometersPerHour: Double?
    let glassIntensity: Double

    private var speedText: String {
        guard let speedKilometersPerHour, speedKilometersPerHour.isFinite else { return "—" }
        return String(format: "%.0f", locale: locale, arguments: [max(0, speedKilometersPerHour)])
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(speedText)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                AppLocalizedText("navigation.speed_unit")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .mapGlassSurface(cornerRadius: 18, glassIntensity: glassIntensity)
        .accessibilityElement(children: .combine)
    }
}

struct NavigationArrivalCard: View {
    @Environment(\.locale) private var locale
    let destinationName: String
    let glassIntensity: Double
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
            AppLocalizedText("navigation.arrival.title")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(destinationName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Button(action: onFinish) {
                AppLocalizedText("navigation.arrival.finish")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppLocalization.string("navigation.arrival.finish", locale: locale)))
        }
        .padding(20)
        .frame(maxWidth: 300)
        .mapGlassSurface(cornerRadius: 28, glassIntensity: glassIntensity)
        .accessibilityElement(children: .contain)
    }
}

struct ActiveNavigationSummaryBar: View {
    @Environment(\.locale) private var locale
    let eta: String
    let remainingDistance: String
    let shareItem: String
    let glassIntensity: Double
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            metric(titleKey: "navigation.eta", value: eta, symbol: "clock")
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1, height: 34)
            metric(titleKey: "navigation.distance_remaining", value: remainingDistance, symbol: "point.topleft.down.to.point.bottomright.curvepath")

            ShareLink(item: shareItem) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 48)
                    .mapGlassCircleSurface(glassIntensity: glassIntensity)
            }
            .accessibilityLabel(Text(AppLocalization.string("navigation.share_eta", locale: locale)))
            .buttonStyle(.plain)

            Button(action: onFinish) {
                VStack(spacing: 5) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .bold))
                    AppLocalizedText("navigation.finish")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .frame(width: 90, height: 58)
                .background(
                    LinearGradient(
                        colors: [Color.red.opacity(0.88), Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppLocalization.string("navigation.finish", locale: locale)))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .mapGlassSurface(cornerRadius: 25, glassIntensity: glassIntensity)
    }

    private func metric(titleKey: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                AppLocalizedText(titleKey)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.headline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
