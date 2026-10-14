import SwiftUI
import UserNotifications

struct FirstRunSetupView: View {
    @AppStorage("ottu.initialSetupCompleted") private var isSetupComplete = false
    @AppStorage("ottu.language") private var storedLanguage = "system"
    @AppStorage("ottu.distanceUnit") private var storedDistanceUnit = "km"

    @StateObject private var locationManager = UserLocationManager()
    @State private var step: SetupStep = .location
    @State private var languageChoice = FirstRunSetupView.preferredLanguage
    @State private var distanceChoice = "km"
    @State private var isRequestingNotifications = false

    private static var preferredLanguage: String {
        let preferredCode = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
        if let preferredCode, ["ar", "en", "ku"].contains(preferredCode) {
            return preferredCode
        }
        return "ar"
    }

    private var setupLocale: Locale {
        Locale(identifier: languageChoice)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppLocalizedText("app.name", locale: setupLocale)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(String(
                    format: AppLocalization.string("setup.progress_format", locale: setupLocale),
                    locale: setupLocale,
                    arguments: [step.number, 4]
                ))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            ProgressView(value: Double(step.number), total: 4)
                .tint(.accentColor)

            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 82, height: 82)
                        .background(.tint.opacity(0.1), in: Circle())
                        .padding(.top, 28)
                        .accessibilityHidden(true)

                    VStack(spacing: 9) {
                        AppLocalizedText(step.titleKey, locale: setupLocale)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        AppLocalizedText(step.messageKey, locale: setupLocale)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 440)

                    stepChoices
                        .frame(maxWidth: 440)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 12) {
                Button(action: performPrimaryAction) {
                    HStack(spacing: 9) {
                        if isRequestingNotifications {
                            ProgressView().tint(.white)
                        }
                        AppLocalizedText(primaryButtonTitle, locale: setupLocale)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingNotifications)

                if showsSecondaryAction {
                    Button(action: performSecondaryAction) {
                        AppLocalizedText(secondaryButtonTitle, locale: setupLocale)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 440)
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .environment(\.locale, setupLocale)
        .environment(\.layoutDirection, languageChoice == "ar" || languageChoice == "ku" ? .rightToLeft : .leftToRight)
        .onAppear {
            if ["ar", "en", "ku"].contains(storedLanguage) {
                languageChoice = storedLanguage
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            guard step == .location, status != .notDetermined else { return }
            advance()
        }
    }

    @ViewBuilder
    private var stepChoices: some View {
        switch step {
        case .language:
            VStack(spacing: 10) {
                choiceRow("العربية", isSelected: languageChoice == "ar") { languageChoice = "ar" }
                choiceRow("English", isSelected: languageChoice == "en") { languageChoice = "en" }
                choiceRow("کوردی (سۆرانی)", isSelected: languageChoice == "ku") { languageChoice = "ku" }
            }
        case .distance:
            VStack(spacing: 10) {
                choiceRow("setup.distance.kilometers", isSelected: distanceChoice == "km") { distanceChoice = "km" }
                choiceRow("setup.distance.miles", isSelected: distanceChoice == "mi") { distanceChoice = "mi" }
            }
        case .location, .notifications:
            EmptyView()
        }
    }

    private func choiceRow(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppLocalizedText(title, locale: setupLocale)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(.background, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var primaryButtonTitle: String {
        switch step {
        case .location:
            return locationManager.authorizationStatus == .notDetermined ? "setup.location.allow" : "setup.continue"
        case .language:
            return "setup.continue"
        case .notifications:
            return "setup.notifications.allow"
        case .distance:
            return "setup.finish"
        }
    }

    private var secondaryButtonTitle: String {
        step == .location ? "setup.location.skip" : "setup.notifications.skip"
    }

    private var showsSecondaryAction: Bool {
        step == .location || step == .notifications
    }

    private func performPrimaryAction() {
        switch step {
        case .location:
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestAuthorization()
            } else {
                advance()
            }
        case .language:
            storedLanguage = languageChoice
            advance()
        case .notifications:
            requestNotifications()
        case .distance:
            storedDistanceUnit = distanceChoice
            isSetupComplete = true
        }
    }

    private func performSecondaryAction() {
        advance()
    }

    private func requestNotifications() {
        isRequestingNotifications = true
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            isRequestingNotifications = false
            advance()
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch step {
            case .location: step = .language
            case .language: step = .notifications
            case .notifications: step = .distance
            case .distance: break
            }
        }
    }
}

private enum SetupStep {
    case location
    case language
    case notifications
    case distance

    var number: Int {
        switch self {
        case .location: 1
        case .language: 2
        case .notifications: 3
        case .distance: 4
        }
    }

    var symbol: String {
        switch self {
        case .location: "location.fill"
        case .language: "character.bubble"
        case .notifications: "bell.badge"
        case .distance: "ruler"
        }
    }

    var titleKey: String {
        switch self {
        case .location: "setup.location.title"
        case .language: "setup.language.title"
        case .notifications: "setup.notifications.title"
        case .distance: "setup.distance.title"
        }
    }

    var messageKey: String {
        switch self {
        case .location: "setup.location.message"
        case .language: "setup.language.message"
        case .notifications: "setup.notifications.message"
        case .distance: "setup.distance.message"
        }
    }
}
