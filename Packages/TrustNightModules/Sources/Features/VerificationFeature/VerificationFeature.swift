import SwiftUI
import Foundation
import DesignSystem
import FoundationKit
import Domain

public struct VerificationDependencies {
    public let analytics: AnalyticsTracking
    public let secureStore: SecureStoring

    public init(analytics: AnalyticsTracking, secureStore: SecureStoring) {
        self.analytics = analytics
        self.secureStore = secureStore
    }
}

@MainActor
public final class VerificationViewModel: ObservableObject {
    public enum State {
        case idle
        case enrolled
        case verified
    }

    @Published public private(set) var state: State = .idle
    private let dependencies: VerificationDependencies
    private let templateKey = "face_template"

    public init(dependencies: VerificationDependencies) {
        self.dependencies = dependencies
    }

    public func enrollTemplate() {
        let template = FaceTemplate(data: Data("encrypted_template".utf8))
        if let data = try? JSONEncoder().encode(template) {
            try? dependencies.secureStore.set(data, for: templateKey)
            state = .enrolled
            dependencies.analytics.track(AnalyticsEvent(name: "verification_enrolled"))
        }
    }

    public func verifyLiveness() {
        state = .verified
        dependencies.analytics.track(AnalyticsEvent(name: "verification_liveness_complete"))
    }

    public func deleteTemplate() {
        try? dependencies.secureStore.deleteData(for: templateKey)
        state = .idle
        dependencies.analytics.track(AnalyticsEvent(name: "verification_template_deleted"))
    }
}

public struct VerificationView: View {
    @StateObject private var viewModel: VerificationViewModel

    public init(viewModel: VerificationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("verification_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text("verification_info")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            FeatureCard {
                Text(statusText)
                    .font(TrustTypography.body)
            }
            PrimaryButton("verification_enroll", action: viewModel.enrollTemplate)
            PrimaryButton("verification_liveness", action: viewModel.verifyLiveness)
            Button("verification_delete_template", action: viewModel.deleteTemplate)
                .foregroundStyle(TrustColors.accent)
                .accessibilityLabel(Text("verification_delete_template"))
        }
        .padding(TrustSpacing.lg)
    }

    private var statusText: String {
        let statusKey: String
        switch viewModel.state {
        case .idle:
            statusKey = "verification_status_idle"
        case .enrolled:
            statusKey = "verification_status_enrolled"
        case .verified:
            statusKey = "verification_status_verified"
        }

        let statusValue = NSLocalizedString(statusKey, comment: "")
        return String(format: NSLocalizedString("verification_status", comment: ""), statusValue)
    }
}
