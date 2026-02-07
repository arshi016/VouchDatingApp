import XCTest
@testable import DesignSystem

final class DesignSystemTests: XCTestCase {
    func testSpacingScaleAscending() {
        XCTAssertLessThan(TrustSpacing.sm, TrustSpacing.md)
        XCTAssertLessThan(TrustSpacing.md, TrustSpacing.lg)
    }
}
