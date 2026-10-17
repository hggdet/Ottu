import SwiftUI

struct MapSettingsSheet: View {
    @Binding var mapDisplayMode: String
    @Binding var voiceLanguage: String
    @Binding var selectedLanguage: String

    let locale: Locale
    let glassIntensity: Double

    private var selectedVoiceLanguageKey: String {
        switch voiceLanguage {
        case "ar": "map.settings.voice_language.ar"
        case "en": "map.settings.voice_language.en"
        case "ku": "map.settings.voice_language.ku"
        default: "map.settings.voice_language.auto"
        }
    }

    private var selectedAppLanguageKey: String {
        switch selectedLanguage {
        case "ar": "settings.language.arabic"
        case "en": "settings.language.english"
        case "ku": "settings.language.kurdish"
        default: "settings.language.system"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    AppLocalizedText("map.settings.title", locale: locale)
                        .font(.title3.weight(.bold))
                    Spacer()
                }
                .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 10) {
                    AppLocalizedText("map.settings.type", locale: locale)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: "map")
                            .foregroundStyle(Color.accentColor)
                        AppLocalizedText("map.settings.type.standard", locale: locale)
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                    .padding(14)
                    .mapGlassSurface(cornerRadius: 18, glassIntensity: glassIntensity)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isSelected)
                }

                VStack(alignment: .leading, spacing: 10) {
                    AppLocalizedText("map.settings.app_language", locale: locale)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        Picker(selection: $selectedLanguage) {
                            languageOption("system", key: "settings.language.system")
                            languageOption("ar", key: "settings.language.arabic")
                            languageOption("en", key: "settings.language.english")
                            languageOption("ku", key: "settings.language.kurdish")
                        } label: {
                            AppLocalizedText("map.settings.app_language", locale: locale)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .foregroundStyle(Color.accentColor)
                            AppLocalizedText(selectedAppLanguageKey, locale: locale)
                                .font(.body.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                        .mapGlassSurface(cornerRadius: 18, glassIntensity: glassIntensity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AppLocalization.string("map.settings.app_language", locale: locale)))
                    .accessibilityValue(Text(AppLocalization.string(selectedAppLanguageKey, locale: locale)))
                }

                VStack(alignment: .leading, spacing: 10) {
                    AppLocalizedText("settings.map_display", locale: locale)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Toggle(isOn: Binding(
                        get: { mapDisplayMode == "3d" },
                        set: { mapDisplayMode = $0 ? "3d" : "2d" }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            AppLocalizedText("map.settings.3d", locale: locale)
                                .font(.body.weight(.medium))
                            AppLocalizedText("settings.map_display_hint", locale: locale)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(.accentColor)
                    .padding(14)
                    .mapGlassSurface(cornerRadius: 18, glassIntensity: glassIntensity)
                }

                VStack(alignment: .leading, spacing: 10) {
                    AppLocalizedText("map.settings.voice_language", locale: locale)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        Picker(selection: $voiceLanguage) {
                            voiceOption("auto", key: "map.settings.voice_language.auto")
                            voiceOption("ar", key: "map.settings.voice_language.ar")
                            voiceOption("en", key: "map.settings.voice_language.en")
                            voiceOption("ku", key: "map.settings.voice_language.ku")
                        } label: {
                            AppLocalizedText("map.settings.voice_language", locale: locale)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform")
                                .foregroundStyle(Color.accentColor)
                            AppLocalizedText(selectedVoiceLanguageKey, locale: locale)
                                .font(.body.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                        .mapGlassSurface(cornerRadius: 18, glassIntensity: glassIntensity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AppLocalization.string("map.settings.voice_language", locale: locale)))
                    .accessibilityValue(Text(AppLocalization.string(selectedVoiceLanguageKey, locale: locale)))

                    AppLocalizedText("map.settings.voice_hint", locale: locale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
        }
        .scrollIndicators(.hidden)
        .mapGlassSurface(cornerRadius: 26, glassIntensity: glassIntensity)
    }

    private func voiceOption(_ value: String, key: String) -> some View {
        Text(AppLocalization.string(key, locale: locale))
            .tag(value)
    }

    private func languageOption(_ value: String, key: String) -> some View {
        Text(AppLocalization.string(key, locale: locale))
            .tag(value)
    }
}
