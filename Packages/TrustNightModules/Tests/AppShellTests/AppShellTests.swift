import XCTest
@testable import AppShell

final class AppShellTests: XCTestCase {
    func testRouterPushAddsRoute() {
        let router = AppRouter()
        XCTAssertTrue(router.path.isEmpty)
        router.push(.events)
        XCTAssertFalse(router.path.isEmpty)
    }
}
