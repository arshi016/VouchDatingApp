import XCTest
@testable import OnboardingFeature
import FoundationKit

final class OnboardingFeatureTests: XCTestCase {
    func testContinueCapturesConsent() {
        let secureStore = StubSecureStore()
        let viewModel = OnboardingViewModel(
            dependencies: OnboardingDependencies(
                analytics: StubAnalytics(),
                logger: StubLogger(),
                secureStore: secureStore
            )
        )
        viewModel.biometricsAllowed = true
        viewModel.cameraAllowed = true
        viewModel.continueTapped()
        XCTAssertTrue(secureStore.didWrite)
    }
}

private final class StubSecureStore: SecureStoring {
    var didWrite = false
    func set(_ data: Data, for key: String) throws { didWrite = true }
    func getData(for key: String) throws -> Data? { nil }
    func deleteData(for key: String) throws {}
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
