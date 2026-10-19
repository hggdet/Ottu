import SwiftUI

struct MapSettingsView: View {
    @Binding var voiceLanguage: String
    @Binding var mapDisplayMode: String
    let locale: Locale

    var body: some View {
        Section {
            LabeledContent {
                Text(AppLocalization.string("map.settings.type.standard", locale: locale))
            } label: {
                AppLocalizedLabel("map.settings.current_style", systemImage: "map", locale: locale)
            }
        } header: {
            AppLocalizedText("map.settings.title", locale: locale)
        }

        Section {
            Toggle(isOn: Binding(
                get: { mapDisplayMode == "3d" },
                set: { mapDisplayMode = $0 ? "3d" : "2d" }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    AppLocalizedText("map.settings.3d", locale: locale)
                    AppLocalizedText("settings.map_display_hint", locale: locale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.accentColor)
        } header: {
            AppLocalizedText("settings.map_display", locale: locale)
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

    private func voiceOption(_ value: String, key: String) -> some View {
        Text(AppLocalization.string(key, locale: locale)).tag(value)
    }
}
