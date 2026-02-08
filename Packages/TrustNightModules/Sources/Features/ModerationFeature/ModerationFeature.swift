import SwiftUI
import DesignSystem
import FoundationKit
import Networking

public struct ModerationDependencies {
    public let apiClient: APIClient
    public let analytics: AnalyticsTracking
    public let logger: Logger

    public init(apiClient: APIClient, analytics: AnalyticsTracking, logger: Logger) {
        self.apiClient = apiClient
        self.analytics = analytics
        self.logger = logger
    }
}

@MainActor
public final class ModerationViewModel: ObservableObject {
    private let dependencies: ModerationDependencies

    public init(dependencies: ModerationDependencies) {
        self.dependencies = dependencies
    }

    public func reportUser() {
        dependencies.analytics.track(AnalyticsEvent(name: "moderation_report_submitted"))
        dependencies.logger.warn("Mock report submitted.")
    }
}

public struct ModerationView: View {
    @StateObject private var viewModel: ModerationViewModel

    public init(viewModel: ModerationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            Text("moderation_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text("moderation_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("moderation_submit", action: viewModel.reportUser)
        }
        .padding(TrustSpacing.lg)
    }
}
