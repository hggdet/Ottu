import SwiftUI

enum AppLocalization {
    private static let supportedLanguages: Set<String> = ["ar", "en", "ku"]
    private static let missingValue = "__OTTU_LOCALIZATION_MISSING__"

    static func languageCode(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? "ar"
        if code == "ckb" { return "ku" }
        return supportedLanguages.contains(code) ? code : "en"
    }

    static func isRightToLeft(_ locale: Locale) -> Bool {
        let code = locale.language.languageCode?.identifier ?? "ar"
        return code == "ar" || code == "ku" || code == "ckb"
    }

    static func string(_ key: String, locale: Locale) -> String {
        let language = languageCode(for: locale)
        if let value = localizedValue(for: key, language: language) {
            return value
        }
        if language != "en", let value = localizedValue(for: key, language: "en") {
            return value
        }
        let bundleValue = Bundle.main.localizedString(forKey: key, value: missingValue, table: "Localizable")
        return bundleValue == missingValue ? "" : bundleValue
    }

    private static func localizedValue(for key: String, language: String) -> String? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        let value = bundle.localizedString(forKey: key, value: missingValue, table: "Localizable")
        return value == missingValue ? nil : value
    }
}

/// Resolves a key from the explicitly selected app locale, not the OS language.
struct AppLocalizedText: View {
    private let key: String
    private let localeOverride: Locale?
    @Environment(\.locale) private var environmentLocale

    init(_ key: String, locale: Locale? = nil) {
        self.key = key
        self.localeOverride = locale
    }

    var body: some View {
        Text(AppLocalization.string(key, locale: localeOverride ?? environmentLocale))
    }
}

struct AppLocalizedLabel: View {
    private let key: String
    private let systemImage: String
    private let localeOverride: Locale?

    init(_ key: String, systemImage: String, locale: Locale? = nil) {
        self.key = key
        self.systemImage = systemImage
        self.localeOverride = locale
    }

    var body: some View {
        Label {
            AppLocalizedText(key, locale: localeOverride)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}
