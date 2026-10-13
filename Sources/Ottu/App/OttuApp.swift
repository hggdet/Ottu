import SwiftUI

@main
struct OttuApp: App {
    @AppStorage("ottu.language") private var selectedLanguage = "system"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"
    @AppStorage("ottu.initialSetupCompleted") private var isInitialSetupComplete = false
    @AppStorage("ottu.welcomeMotionCompleted") private var hasSeenWelcomeMotion = false

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
            Group {
                if isInitialSetupComplete {
                    MapHomeView()
                } else if hasSeenWelcomeMotion {
                    FirstRunSetupView()
                } else {
                    WelcomeMotionView {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            hasSeenWelcomeMotion = true
                        }
                    }
                }
            }
                .environment(\.locale, interfaceLocale)
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                .preferredColorScheme(preferredScheme)
        }
    }
}
