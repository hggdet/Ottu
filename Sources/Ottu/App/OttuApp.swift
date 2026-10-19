import SwiftUI

@main
struct OttuApp: App {
    @UIApplicationDelegateAdaptor(QuickActionAppDelegate.self) private var quickActionDelegate
    @AppStorage("ottu.language") private var selectedLanguage = "system"
    @AppStorage("ottu.appearance") private var selectedAppearance = "system"
    @AppStorage("ottu.initialSetupCompleted") private var isInitialSetupComplete = false
    @AppStorage("ottu.welcomeMotionCompleted") private var hasSeenWelcomeMotion = false
    @State private var shouldShowWelcomeMotion = !UserDefaults.standard.bool(forKey: "ottu.welcomeMotionCompleted")

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
                if isInitialSetupComplete {
                    MapHomeView(selectedLanguage: $selectedLanguage)
                } else if shouldShowWelcomeMotion {
                    WelcomeMotionView {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            shouldShowWelcomeMotion = false
                        }
                    }
                    .onAppear {
                        hasSeenWelcomeMotion = true
                    }
                } else {
                    FirstRunSetupView()
                }
            }
                .environment(\.locale, interfaceLocale)
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                .preferredColorScheme(preferredScheme)
        }
    }
}
