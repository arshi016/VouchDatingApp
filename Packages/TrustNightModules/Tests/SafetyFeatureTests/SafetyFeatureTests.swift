import XCTest
@testable import SafetyFeature
import FoundationKit

final class SafetyFeatureTests: XCTestCase {
    func testOpenSafetyCenterTracksEvent() {
        let analytics = StubAnalytics()
        let viewModel = SafetyViewModel(
            dependencies: SafetyDependencies(analytics: analytics)
        )
        viewModel.openSafetyCenter()
        XCTAssertTrue(analytics.didTrack)
    }
}

private final class StubAnalytics: AnalyticsTracking {
    var didTrack = false
    func track(_ event: AnalyticsEvent) { didTrack = true }
}
