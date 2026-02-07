import XCTest
@testable import Networking

final class NetworkingTests: XCTestCase {
    func testRetryPolicyAllowsRetryForServerErrors() {
        let policy = RetryPolicy.default
        let error = URLError(.timedOut)
        XCTAssertTrue(policy.shouldRetry(statusCode: 500, error: error, attempt: 0))
        XCTAssertFalse(policy.shouldRetry(statusCode: 400, error: error, attempt: 0))
    }
}
