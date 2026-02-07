import XCTest
@testable import ChatFeature
import FoundationKit
import Networking

final class ChatFeatureTests: XCTestCase {
    func testSendMessageUpdatesState() {
        let viewModel = ChatViewModel(
            dependencies: ChatDependencies(
                apiClient: StubAPIClient(),
                analytics: StubAnalytics()
            )
        )
        XCTAssertEqual(viewModel.lastMessageKey, "chat_empty")
        viewModel.sendMockMessage()
        XCTAssertEqual(viewModel.lastMessageKey, "chat_sent")
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
