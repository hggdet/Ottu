import SwiftUI

struct MapSettingsSheet: View {
    @Binding var voiceLanguage: String
    let locale: Locale
    let glassIntensity: Double

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        Text(AppLocalization.string("map.settings.type.standard", locale: locale))
                    } label: {
                        AppLocalizedLabel("map.settings.type", systemImage: "map", locale: locale)
                    }
                }

                Section {
                    Picker(selection: $voiceLanguage) {
                        voiceOption("auto", key: "map.settings.voice_language.auto")
                        voiceOption("ar", key: "map.settings.voice_language.ar")
                        voiceOption("en", key: "map.settings.voice_language.en")
                        voiceOption("ku", key: "map.settings.voice_language.ku")
                    } label: {
                        AppLocalizedLabel("map.settings.voice_language", systemImage: "waveform", locale: locale)
                    }
                } footer: {
                    AppLocalizedText("map.settings.voice_hint", locale: locale)
                }
            }
            .navigationTitle(Text(AppLocalization.string("map.settings.title", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.locale, locale)
    }

    private func voiceOption(_ value: String, key: String) -> some View {
        Text(AppLocalization.string(key, locale: locale)).tag(value)
    }
}
