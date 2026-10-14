import XCTest
@testable import Ottu

final class NavigationTests: XCTestCase {
    func testNavigationTabsKeepRequestedRightToLeftOrder() {
        XCTAssertEqual(
            MapNavigationTab.allCases.map(\.rawValue),
            ["location", "assistant", "categories", "settings"]
        )
    }
}
