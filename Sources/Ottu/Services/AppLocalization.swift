import Foundation

enum AppLocalization {
    static func string(_ key: String, locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "ar"

        if let bundle = localizedBundle(for: language) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                return value
            }
        }

        if language != "en", let englishBundle = localizedBundle(for: "en") {
            let englishValue = englishBundle.localizedString(forKey: key, value: nil, table: nil)
            if englishValue != key {
                return englishValue
            }
        }

        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    private static func localizedBundle(for language: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
