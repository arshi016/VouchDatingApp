import XCTest
@testable import VouchFeature
import FoundationKit
import Domain

final class VouchFeatureTests: XCTestCase {
    func testRecalculateUpdatesScore() {
        let viewModel = VouchViewModel(
            dependencies: VouchDependencies(
                analytics: StubAnalytics(),
                calculator: TrustScoreCalculator()
            )
        )
        viewModel.recalculate(endorsements: 5, reports: 0)
        XCTAssertGreaterThan(viewModel.score.value, 0)
    }
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}
