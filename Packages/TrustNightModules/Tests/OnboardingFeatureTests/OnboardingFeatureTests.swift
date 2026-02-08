import XCTest
@testable import OnboardingFeature
import FoundationKit
import Persistence
import Domain

final class OnboardingFeatureTests: XCTestCase {
    func testConsentBlocksAdvance() {
        let viewModel = OnboardingViewModel(
            dependencies: OnboardingDependencies(
                analytics: StubAnalytics(),
                logger: StubLogger(),
                preferencesRepository: StubPreferencesRepository(),
                permissionClient: StubPermissionClient(),
                notificationScheduler: StubNotificationScheduler()
            )
        )

        XCTAssertEqual(viewModel.step, .intro)
        viewModel.next()
        XCTAssertEqual(viewModel.step, .consent)
        viewModel.next()
        XCTAssertEqual(viewModel.step, .consent)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private final class StubPreferencesRepository: OnboardingPreferencesRepository {
    func fetchPreferences() async throws -> OnboardingPreferences? { nil }
    func savePreferences(_ preferences: OnboardingPreferences) async throws {}
    func clearPreferences() async throws {}
}

private final class StubPermissionClient: PermissionRequesting {
    var cameraStatus: PermissionState { .notDetermined }
    var locationStatus: PermissionState { .notDetermined }
    func requestCameraPermission() async -> PermissionState { .granted }
    func requestLocationPermission() async -> PermissionState { .granted }
}

private final class StubNotificationScheduler: NotificationScheduling {
    func requestAuthorization() async -> Bool { true }
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
