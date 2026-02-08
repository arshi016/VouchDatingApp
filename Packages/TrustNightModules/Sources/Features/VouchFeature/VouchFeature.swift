import SwiftUI
import Foundation
import DesignSystem
import FoundationKit
import Domain

public struct VouchDependencies {
    public let analytics: AnalyticsTracking
    public let calculator: TrustScoreCalculating

    public init(analytics: AnalyticsTracking, calculator: TrustScoreCalculating) {
        self.analytics = analytics
        self.calculator = calculator
    }
}

@MainActor
public final class VouchViewModel: ObservableObject {
    @Published public private(set) var score: TrustScore = TrustScore(value: 0)
    private let dependencies: VouchDependencies

    public init(dependencies: VouchDependencies) {
        self.dependencies = dependencies
        recalculate(endorsements: 3, reports: 0)
    }

    public func recalculate(endorsements: Int, reports: Int) {
        score = dependencies.calculator.score(endorsements: endorsements, reports: reports)
        dependencies.analytics.track(AnalyticsEvent(name: "vouch_score_updated"))
    }
}

public struct VouchView: View {
    @StateObject private var viewModel: VouchViewModel

    public init(viewModel: VouchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            Text("vouch_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(String(format: NSLocalizedString("vouch_score", comment: ""), viewModel.score.value))
                .font(TrustTypography.headline)
                .foregroundStyle(TrustColors.primary)
            PrimaryButton("vouch_recalculate", action: { viewModel.recalculate(endorsements: 4, reports: 1) })
        }
        .padding(TrustSpacing.lg)
    }
}
