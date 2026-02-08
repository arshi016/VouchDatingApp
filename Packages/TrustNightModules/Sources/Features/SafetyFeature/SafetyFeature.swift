import SwiftUI
import DesignSystem
import FoundationKit

public struct SafetyDependencies {
    public let analytics: AnalyticsTracking

    public init(analytics: AnalyticsTracking) {
        self.analytics = analytics
    }
}

@MainActor
public final class SafetyViewModel: ObservableObject {
    private let dependencies: SafetyDependencies

    public init(dependencies: SafetyDependencies) {
        self.dependencies = dependencies
    }

    public func openSafetyCenter() {
        dependencies.analytics.track(AnalyticsEvent(name: "safety_center_opened"))
    }
}

public struct SafetyView: View {
    @StateObject private var viewModel: SafetyViewModel

    public init(viewModel: SafetyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            Text("safety_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text("safety_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("safety_open_center", action: viewModel.openSafetyCenter)
        }
        .padding(TrustSpacing.lg)
    }
}
