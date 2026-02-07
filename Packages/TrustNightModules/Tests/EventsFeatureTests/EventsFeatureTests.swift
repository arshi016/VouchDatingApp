import XCTest
@testable import EventsFeature
import FoundationKit
import Networking

final class EventsFeatureTests: XCTestCase {
    func testLoadsMockEvents() {
        let viewModel = EventsViewModel(
            dependencies: EventsDependencies(
                apiClient: StubAPIClient(),
                analytics: StubAnalytics(),
                logger: StubLogger()
            )
        )
        XCTAssertFalse(viewModel.events.isEmpty)
    }
}

private struct StubAPIClient: APIClient {
    func request<Response>(_ endpoint: Endpoint<Response>) async throws -> Response where Response : Decodable {
        throw URLError(.badURL)
    }
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
