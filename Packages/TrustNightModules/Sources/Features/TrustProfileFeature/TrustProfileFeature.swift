import SwiftUI
import Foundation
import DesignSystem
import FoundationKit
import Persistence
import Domain

public struct TrustProfileDependencies {
    public let repository: UserProfileRepository
    public let analytics: AnalyticsTracking

    public init(repository: UserProfileRepository, analytics: AnalyticsTracking) {
        self.repository = repository
        self.analytics = analytics
    }
}

@MainActor
public final class TrustProfileViewModel: ObservableObject {
    @Published public private(set) var profile: UserProfile?
    private let dependencies: TrustProfileDependencies

    public init(dependencies: TrustProfileDependencies) {
        self.dependencies = dependencies
        Task { await loadProfile() }
    }

    public func loadProfile() async {
        dependencies.analytics.track(AnalyticsEvent(name: "trust_profile_loaded"))
        do {
            profile = try await dependencies.repository.fetchProfile(userID: UserID("local-user"))
            if profile == nil {
                let newProfile = UserProfile(id: UserID("local-user"), displayName: "TrustNight User", location: CoarseLocation(regionCode: "DE"))
                try await dependencies.repository.saveProfile(newProfile)
                profile = newProfile
            }
        } catch {
            profile = nil
        }
    }
}

public struct TrustProfileView: View {
    @StateObject private var viewModel: TrustProfileViewModel

    public init(viewModel: TrustProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("trust_profile_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            FeatureCard {
                Text(viewModel.profile?.displayName ?? NSLocalizedString("trust_profile_empty", comment: ""))
                    .font(TrustTypography.headline)
                Text(regionText)
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
            }
        }
        .padding(TrustSpacing.lg)
    }

    private var regionText: String {
        let region = viewModel.profile?.location?.regionCode ?? NSLocalizedString("region_unknown", comment: "")
        return String(format: NSLocalizedString("region_label", comment: ""), region)
    }
}
