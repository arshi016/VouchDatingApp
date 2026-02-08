import XCTest
@testable import ModerationFeature
import FoundationKit
import Networking

final class ModerationFeatureTests: XCTestCase {
    func testReportTracksEvent() {
        let analytics = StubAnalytics()
        let viewModel = ModerationViewModel(
            dependencies: ModerationDependencies(
                apiClient: StubAPIClient(),
                analytics: analytics,
                logger: StubLogger()
            )
        )
        viewModel.reportUser()
        XCTAssertTrue(analytics.didTrack)
    }
}

private struct StubAPIClient: APIClient {
    func request<Response: Decodable, Body: Encodable>(_ endpoint: Endpoint<Response, Body>) async throws -> Response {
        throw URLError(.badURL)
    }
}

private final class StubAnalytics: AnalyticsTracking {
    var didTrack = false
    func track(_ event: AnalyticsEvent) { didTrack = true }
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
