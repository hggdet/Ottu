import XCTest
@testable import Ottu

final class HomeScreenQuickActionsTests: XCTestCase {
    func testUnknownShortcutIsNotHandled() {
        XCTAssertNil(HomeScreenQuickAction(rawValue: "unknown"))
        XCTAssertEqual(Set(HomeScreenQuickAction.allCases.map(\.rawValue)).count, 2)
    }

    func testBundledShortcutsMatchSupportedRoutes() throws {
        let items = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationShortcutItems") as? [[String: Any]])
        XCTAssertEqual(items.count, HomeScreenQuickAction.allCases.count)
        XCTAssertEqual(Set(items.compactMap { $0["UIApplicationShortcutItemType"] as? String }),
                       Set(HomeScreenQuickAction.allCases.map(\.rawValue)))
        for item in items {
            XCTAssertNotNil(item["UIApplicationShortcutItemIconType"] as? String)
        }
    }

    func testMailDraftPreservesUnicodeAndReservedCharacters() throws {
        let subject = "إبلاغ وين & ملاحظة؟ #1"
        let body = "هلا فريق وين،\n\nA+B & cc=not-a-recipient@example.com?"
        let url = try XCTUnwrap(SupportContact.mailURL(subject: subject, body: body))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, SupportContact.email)
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "subject", value: subject),
                                              URLQueryItem(name: "body", value: body)])
        XCTAssertNil(components.host)
    }

    func testExistingSupportAddressIsReused() {
        XCTAssertEqual(SupportContact.email, "pbgpfk7ofwz729ekxamzqk@onmanus.ai")
    }

    func testAllActionStringsAreLocalized() throws {
        let keys = ["quick_action.support.title", "quick_action.support.subtitle",
                    "quick_action.support.subject", "quick_action.support.body",
                    "quick_action.support.unavailable", "quick_action.support.copy",
                    "quick_action.stay.title", "quick_action.stay.subtitle",
                    "quick_action.stay.message", "quick_action.stay.keep"]
        for language in ["ar", "en", "ku"] {
            let locale = Locale(identifier: language)
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                let localized = AppLocalization.string(key, locale: locale)
                XCTAssertFalse(localized.isEmpty, "\(language): \(key)")
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: "MISSING", table: "Localizable"), "MISSING")
            }
            for key in ["quick_action.support.title", "quick_action.support.subtitle",
                        "quick_action.stay.title", "quick_action.stay.subtitle"] {
                XCTAssertEqual(bundle.localizedString(forKey: key, value: "MISSING", table: "InfoPlist"),
                               AppLocalization.string(key, locale: locale))
            }
        }
        XCTAssertEqual(AppLocalization.string("quick_action.stay.title", locale: Locale(identifier: "ar")),
                       "ليش تحذفني؟ 😢")
    }
}
