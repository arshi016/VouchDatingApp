import SwiftUI
import DesignSystem
import FoundationKit

public struct OnboardingDependencies {
    public let analytics: AnalyticsTracking
    public let logger: Logger
    public let secureStore: SecureStoring

    public init(analytics: AnalyticsTracking, logger: Logger, secureStore: SecureStoring) {
        self.analytics = analytics
        self.logger = logger
        self.secureStore = secureStore
    }
}

struct ConsentState: Codable {
    let biometricsAllowed: Bool
    let cameraAllowed: Bool
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public var biometricsAllowed = false
    @Published public var cameraAllowed = false

    private let dependencies: OnboardingDependencies

    public init(dependencies: OnboardingDependencies) {
        self.dependencies = dependencies
    }

    public func continueTapped() {
        let consent = ConsentState(biometricsAllowed: biometricsAllowed, cameraAllowed: cameraAllowed)
        if let data = try? JSONEncoder().encode(consent) {
            try? dependencies.secureStore.set(data, for: "consent_state")
        }
        dependencies.analytics.track(AnalyticsEvent(name: "consent_completed"))
        dependencies.logger.info("Consent captured.")
    }
}

public struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                TrustIconView(.shield, size: 40)
                Text("consent_title")
                    .font(TrustTypography.title)
                    .accessibilityAddTraits(.isHeader)

                Text("consent_intro")
                    .font(TrustTypography.body)
                    .foregroundStyle(TrustColors.textSecondary)

                Toggle("consent_biometrics", isOn: $viewModel.biometricsAllowed)
                    .toggleStyle(SwitchToggleStyle(tint: TrustColors.primary))
                    .accessibilityLabel(Text("consent_biometrics"))

                Toggle("consent_camera", isOn: $viewModel.cameraAllowed)
                    .toggleStyle(SwitchToggleStyle(tint: TrustColors.primary))
                    .accessibilityLabel(Text("consent_camera"))

                PrimaryButton("consent_continue", action: viewModel.continueTapped)
            }
            .padding(TrustSpacing.lg)
        }
    }
}
