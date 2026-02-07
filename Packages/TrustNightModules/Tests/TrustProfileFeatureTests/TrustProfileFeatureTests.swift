import XCTest
@testable import TrustProfileFeature
import FoundationKit
import Domain

final class TrustProfileFeatureTests: XCTestCase {
    func testLoadProfileCreatesDefault() async {
        let repository = StubUserProfileRepository()
        let viewModel = TrustProfileViewModel(
            dependencies: TrustProfileDependencies(
                repository: repository,
                analytics: StubAnalytics()
            )
        )

        await viewModel.loadProfile()
        XCTAssertNotNil(viewModel.profile)
        XCTAssertTrue(repository.didSaveProfile)
    }
}

private final class StubUserProfileRepository: UserProfileRepository {
    var storedProfile: UserProfile?
    var didSaveProfile = false

    func fetchProfile(userID: UserID) async throws -> UserProfile? {
        storedProfile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        storedProfile = profile
        didSaveProfile = true
    }
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}
