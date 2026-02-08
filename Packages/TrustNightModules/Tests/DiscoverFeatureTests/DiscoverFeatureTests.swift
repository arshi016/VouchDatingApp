import XCTest
@testable import DiscoverFeature
import FoundationKit
import Persistence
import Domain
import Networking

final class DiscoverFeatureTests: XCTestCase {
    func testWaveLimitMessage() async {
        let waveRepo = StubWaveQuotaRepository(quota: WaveQuota(count: 5, lastReset: Date()))
        let viewModel = DiscoverViewModel(
            dependencies: DiscoverDependencies(
                apiClient: MockAPIClient(),
                discoverRepository: StubDiscoverRepository(),
                waveQuotaRepository: waveRepo,
                preferencesRepository: StubPreferencesRepository(),
                analytics: StubAnalytics(),
                logger: StubLogger()
            ),
            onInvite: { _ in }
        )

        let profile = DiscoverProfile(
            id: "1",
            displayName: "A",
            age: 30,
            distanceBucket: "2-5km",
            badges: [],
            isHumanVerified: true,
            isIRLVerified: false,
            intent: .eventsOnly,
            photoURL: nil,
            isBlurred: false,
            summary: "Analyst"
        )

        viewModel.wave(at: profile)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.waveRemainingMessageKey, "discover_wave_limit")
    }
}

private final class StubDiscoverRepository: DiscoverRepository {
    func fetchCache() async throws -> DiscoverCache { DiscoverCache(profiles: [], lastUpdated: nil) }
    func saveProfiles(_ profiles: [DiscoverProfile], updatedAt: Date) async throws {}
    func clearProfiles() async throws {}
}

private final class StubWaveQuotaRepository: WaveQuotaRepository {
    private var quota: WaveQuota

    init(quota: WaveQuota) {
        self.quota = quota
    }

    func fetchQuota() async throws -> WaveQuota { quota }
    func saveQuota(_ quota: WaveQuota) async throws { self.quota = quota }
}

private final class StubPreferencesRepository: OnboardingPreferencesRepository {
    func fetchPreferences() async throws -> OnboardingPreferences? { nil }
    func savePreferences(_ preferences: OnboardingPreferences) async throws {}
    func clearPreferences() async throws {}
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
