import SwiftUI
import DesignSystem
import FoundationKit

public struct DiscoverDependencies {
    public let analytics: AnalyticsTracking
    public let logger: Logger

    public init(analytics: AnalyticsTracking, logger: Logger) {
        self.analytics = analytics
        self.logger = logger
    }
}

@MainActor
public final class DiscoverViewModel: ObservableObject {
    private let dependencies: DiscoverDependencies
    private let onPrimaryAction: () -> Void

    public init(dependencies: DiscoverDependencies, onPrimaryAction: @escaping () -> Void) {
        self.dependencies = dependencies
        self.onPrimaryAction = onPrimaryAction
    }

    public func primaryActionTapped() {
        dependencies.analytics.track(AnalyticsEvent(name: "discover_primary_action"))
        dependencies.logger.info("Discover primary action tapped.")
        onPrimaryAction()
    }
}

public struct DiscoverView: View {
    @StateObject private var viewModel: DiscoverViewModel

    public init(viewModel: DiscoverViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            TrustIconView(.heart, size: 48)
            Text("hello_trustnight")
                .font(TrustTypography.title)
                .accessibilityLabel(Text("hello_trustnight"))
            Text("home_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton("discover_view_events", action: viewModel.primaryActionTapped)
        }
        .padding(TrustSpacing.lg)
    }
}
