import XCTest
@testable import VerificationFeature
import FoundationKit

final class VerificationFeatureTests: XCTestCase {
    func testEnrollTemplateStoresData() {
        let secureStore = StubSecureStore()
        let viewModel = VerificationViewModel(
            dependencies: VerificationDependencies(
                analytics: StubAnalytics(),
                secureStore: secureStore
            )
        )

        viewModel.enrollTemplate()
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
