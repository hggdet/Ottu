import SwiftUI

@main
struct OttuApp: App {
    @AppStorage("ottu.language") private var selectedLanguage = "system"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"

    private var interfaceLocale: Locale {
        selectedLanguage == "system" ? Locale.autoupdatingCurrent : Locale(identifier: selectedLanguage)
    }

    private var isRightToLeft: Bool {
        let language = interfaceLocale.language.languageCode?.identifier ?? "ar"
        return language == "ar" || language == "ku"
    }

    private var preferredScheme: ColorScheme? {
        switch selectedAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            MapHomeView()
                .environment(\.locale, interfaceLocale)
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                .preferredColorScheme(preferredScheme)
        }
    }
}
