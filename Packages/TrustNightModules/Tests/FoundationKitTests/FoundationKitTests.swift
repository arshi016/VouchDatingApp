import XCTest
@testable import FoundationKit

final class FoundationKitTests: XCTestCase {
    func testFeatureFlagging() {
        let key = FeatureFlagKey("test_flag")
        let flags = InMemoryFeatureFlags()
        XCTAssertFalse(flags.isEnabled(key))
        flags.set(key, enabled: true)
        XCTAssertTrue(flags.isEnabled(key))
    }
}
