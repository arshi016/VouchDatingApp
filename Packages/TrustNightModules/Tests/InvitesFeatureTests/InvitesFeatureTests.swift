import XCTest
@testable import InvitesFeature
import FoundationKit

final class InvitesFeatureTests: XCTestCase {
    func testSendInviteTracksEvent() {
        let analytics = StubAnalytics()
        let viewModel = InvitesViewModel(
            dependencies: InvitesDependencies(analytics: analytics)
        )
        viewModel.sendInvite()
        XCTAssertTrue(analytics.didTrack)
    }
}

private final class StubAnalytics: AnalyticsTracking {
    var didTrack = false
    func track(_ event: AnalyticsEvent) { didTrack = true }
}
