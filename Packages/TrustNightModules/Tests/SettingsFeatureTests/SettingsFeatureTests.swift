import XCTest
@testable import SettingsFeature
import FoundationKit

final class SettingsFeatureTests: XCTestCase {
    func testClearSecureDataDeletesKeys() {
        let secureStore = StubSecureStore()
        let viewModel = SettingsViewModel(
            dependencies: SettingsDependencies(
                featureFlags: StubFeatureFlags(),
                secureStore: secureStore,
                analytics: StubAnalytics()
            )
        )
        viewModel.clearSecureData()
        XCTAssertTrue(secureStore.didDelete)
    }
}

private struct StubFeatureFlags: FeatureFlagging {
    func isEnabled(_ key: FeatureFlagKey) -> Bool { false }
}

private final class StubSecureStore: SecureStoring {
    var didDelete = false
    func set(_ data: Data, for key: String) throws {}
    func getData(for key: String) throws -> Data? { nil }
    func deleteData(for key: String) throws { didDelete = true }
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}
