import SwiftUI

struct MapSettingsView: View {
    @Binding var voiceLanguage: String
    @Binding var mapDisplayMode: String
    @AppStorage(UserLocationIcon.storageKey) private var userLocationIconRawValue = UserLocationIcon.arrow.rawValue
    let locale: Locale

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(AppLocalization.string("map.settings.type.standard", locale: locale))
                } label: {
                    AppLocalizedLabel("map.settings.type", systemImage: "map", locale: locale)
                }
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
                Picker(selection: $userLocationIconRawValue) {
                    ForEach(UserLocationIcon.allCases) { icon in
                        Text(AppLocalization.string(icon.localizationKey, locale: locale))
                            .tag(icon.rawValue)
                    }
                } label: {
                    AppLocalizedLabel("map.settings.user_location_icon", systemImage: "location.fill", locale: locale)
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
        .environment(\.locale, locale)
    }

    private func voiceOption(_ value: String, key: String) -> some View {
        Text(AppLocalization.string(key, locale: locale)).tag(value)
    }
}
