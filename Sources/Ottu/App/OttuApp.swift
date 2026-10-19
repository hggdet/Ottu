import SwiftUI

@main
struct OttuApp: App {
    @UIApplicationDelegateAdaptor(QuickActionAppDelegate.self) private var quickActionDelegate
    @AppStorage("ottu.language") private var selectedLanguage = "system"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"
    @AppStorage("ottu.welcomeMotionCompleted") private var hasSeenWelcomeMotion = false
    // Existing users who finished the old setup should not see the intro again.
    @State private var shouldShowWelcomeMotion = !UserDefaults.standard.bool(forKey: "ottu.welcomeMotionCompleted")
        && !UserDefaults.standard.bool(forKey: "ottu.initialSetupCompleted")

    private var interfaceLocale: Locale {
        selectedLanguage == "system" ? Locale.autoupdatingCurrent : Locale(identifier: selectedLanguage)
    }

    private var isRightToLeft: Bool {
        AppLocalization.isRightToLeft(interfaceLocale)
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
                if shouldShowWelcomeMotion {
                    WelcomeMotionView {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            shouldShowWelcomeMotion = false
                        }
                    }
                    .onAppear {
                        hasSeenWelcomeMotion = true
                    }
                } else {
                    MapHomeView(selectedLanguage: $selectedLanguage)
                }
            }
                .environment(\.locale, interfaceLocale)
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                .preferredColorScheme(preferredScheme)
        }
    }
}
