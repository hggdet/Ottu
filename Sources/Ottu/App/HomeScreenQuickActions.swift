import SwiftUI
import UIKit
import MessageUI

/// Keep the Home Screen menu and Settings pointed at the same existing support inbox.
enum SupportContact {
    static let email = "pbgpfk7ofwz729ekxamzqk@onmanus.ai"

    static func mailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

enum HomeScreenQuickAction: String, CaseIterable {
    // These identifiers must match UIApplicationShortcutItems in project.yml / Info.plist.
    case support = "iq.ottu.ios.quick-action.support"
    case stay = "iq.ottu.ios.quick-action.stay"
}

final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

/// SwiftUI still owns the window. This delegate only handles scene-specific shortcuts.
/// Present over the topmost controller so a shortcut works even if a map/settings sheet is open.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate, MFMailComposeViewControllerDelegate {
    private var pendingAction: HomeScreenQuickAction?
    private var presentationAttempts = 0

    private var locale: Locale {
        let language = UserDefaults.standard.string(forKey: "ottu.language") ?? "system"
        return language == "system" ? .autoupdatingCurrent : Locale(identifier: language)
    }

    private func text(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // A cold-launch shortcut arrives here, not in performActionFor.
        pendingAction = connectionOptions.shortcutItem.flatMap { HomeScreenQuickAction(rawValue: $0.type) }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        presentationAttempts = 0
        schedulePresentation(in: windowScene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let action = HomeScreenQuickAction(rawValue: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        pendingAction = action
        presentationAttempts = 0
        schedulePresentation(in: windowScene)
        completionHandler(true)
    }

    private func schedulePresentation(in scene: UIWindowScene) {
        // Wait for SwiftUI's root controller and any activation transition to be ready.
        DispatchQueue.main.async { [weak self, weak scene] in
            guard let self, let scene, scene.activationState == .foregroundActive,
                  let action = self.pendingAction else { return }
            guard let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
                self.retryPresentation(in: scene)
                return
            }
            let presenter = self.topmostController(from: root)
            guard presenter.viewIfLoaded?.window != nil,
                  !presenter.isBeingPresented, !presenter.isBeingDismissed,
                  presenter.transitionCoordinator == nil else {
                self.retryPresentation(in: scene)
                return
            }
            self.pendingAction = nil
            switch action {
            case .support:
                self.presentSupport(from: presenter)
            case .stay:
                let alert = UIAlertController(title: self.text("quick_action.stay.title"),
                                              message: self.text("quick_action.stay.message"),
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: self.text("quick_action.stay.keep"), style: .cancel))
                alert.addAction(UIAlertAction(title: self.text("quick_action.support.title"), style: .default) { [weak self, weak scene] _ in
                    guard let self, let scene else { return }
                    self.pendingAction = .support
                    self.presentationAttempts = 0
                    self.retryPresentation(in: scene)
                })
                presenter.present(alert, animated: true)
            }
        }
    }

    private func retryPresentation(in scene: UIWindowScene) {
        // Bounded retries handle launch/sheet animations without an endless timer.
        // If still unavailable, retain the request until the next scene activation.
        guard presentationAttempts < 10 else { return }
        presentationAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak scene] in
            guard let self, let scene else { return }
            self.schedulePresentation(in: scene)
        }
    }

    private func topmostController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topmostController(from: presented)
        }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return topmostController(from: visible)
        }
        if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController {
            return topmostController(from: selected)
        }
        return controller
    }

    private func presentSupport(from presenter: UIViewController) {
        let subject = text("quick_action.support.subject")
        let body = text("quick_action.support.body")
        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            composer.mailComposeDelegate = self
            composer.setToRecipients([SupportContact.email])
            composer.setSubject(subject)
            composer.setMessageBody(body, isHTML: false)
            presenter.present(composer, animated: true)
        } else if let url = SupportContact.mailURL(subject: subject, body: body) {
            // Opens a draft in the user's mail app. Never sends a message automatically.
            UIApplication.shared.open(url, options: [:]) { [weak self, weak presenter] opened in
                guard !opened else { return }
                DispatchQueue.main.async {
                    guard let self, let presenter else { return }
                    self.presentMailUnavailable(from: presenter)
                }
            }
        } else {
            presentMailUnavailable(from: presenter)
        }
    }

    private func presentMailUnavailable(from presenter: UIViewController) {
        let alert = UIAlertController(title: text("quick_action.support.title"),
                                      message: text("quick_action.support.unavailable") + "\n\n" + SupportContact.email,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: text("quick_action.support.copy"), style: .default) { _ in
            UIPasteboard.general.string = SupportContact.email
        })
        alert.addAction(UIAlertAction(title: text("common.ok"), style: .cancel))
        presenter.present(alert, animated: true)
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
