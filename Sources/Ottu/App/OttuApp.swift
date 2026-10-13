import SwiftUI

@main
struct OttuApp: App {
    private var isRightToLeft: Bool {
        let language = Locale.current.language.languageCode?.identifier ?? "ar"
        return language == "ar" || language == "ku"
    }

    var body: some Scene {
        WindowGroup {
            MapHomeView()
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                .preferredColorScheme(nil)
        }
    }
}
