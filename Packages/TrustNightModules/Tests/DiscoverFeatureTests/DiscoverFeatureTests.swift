import XCTest
@testable import DiscoverFeature
import FoundationKit

final class DiscoverFeatureTests: XCTestCase {
    func testPrimaryActionCallsCallback() {
        var didCall = false
        let viewModel = DiscoverViewModel(
            dependencies: DiscoverDependencies(
                analytics: StubAnalytics(),
                logger: StubLogger()
            ),
            onPrimaryAction: { didCall = true }
        )

        viewModel.primaryActionTapped()
        XCTAssertTrue(didCall)
    }
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
