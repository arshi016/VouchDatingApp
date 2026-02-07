import SwiftUI
import DesignSystem
import FoundationKit

public struct InvitesDependencies {
    public let analytics: AnalyticsTracking

    public init(analytics: AnalyticsTracking) {
        self.analytics = analytics
    }
}

@MainActor
public final class InvitesViewModel: ObservableObject {
    private let dependencies: InvitesDependencies

    public init(dependencies: InvitesDependencies) {
        self.dependencies = dependencies
    }

    public func sendInvite() {
        dependencies.analytics.track(AnalyticsEvent(name: "invite_sent"))
    }
}

public struct InvitesView: View {
    @StateObject private var viewModel: InvitesViewModel

    public init(viewModel: InvitesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            Text("invites_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text("invites_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("invites_send", action: viewModel.sendInvite)
        }
        .padding(TrustSpacing.lg)
    }
}
