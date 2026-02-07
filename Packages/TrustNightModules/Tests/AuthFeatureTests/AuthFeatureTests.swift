import XCTest
@testable import AuthFeature
import FoundationKit
import Networking

final class AuthFeatureTests: XCTestCase {
    func testSignInTransitionsState() {
        let viewModel = AuthViewModel(dependencies: AuthDependencies(
            apiClient: StubAPIClient(),
            secureStore: StubSecureStore(),
            analytics: StubAnalytics(),
            logger: StubLogger()
        ))

        XCTAssertEqual(viewModel.state, .signedOut)
        viewModel.signInMock()
        XCTAssertEqual(viewModel.state, .signedIn)
    }
}

private struct StubAPIClient: APIClient {
    func request<Response>(_ endpoint: Endpoint<Response>) async throws -> Response where Response : Decodable {
        throw URLError(.badURL)
    }
}

private final class StubSecureStore: SecureStoring {
    func set(_ data: Data, for key: String) throws {}
    func getData(for key: String) throws -> Data? { nil }
    func deleteData(for key: String) throws {}
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
