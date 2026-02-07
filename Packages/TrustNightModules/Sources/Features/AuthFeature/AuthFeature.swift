import SwiftUI
import DesignSystem
import FoundationKit
import Networking

public struct AuthDependencies {
    public let apiClient: APIClient
    public let secureStore: SecureStoring
    public let analytics: AnalyticsTracking
    public let logger: Logger

    public init(apiClient: APIClient, secureStore: SecureStoring, analytics: AnalyticsTracking, logger: Logger) {
        self.apiClient = apiClient
        self.secureStore = secureStore
        self.analytics = analytics
        self.logger = logger
    }
}

@MainActor
public final class AuthViewModel: ObservableObject {
    public enum State {
        case signedOut
        case signedIn
    }

    @Published public private(set) var state: State = .signedOut
    private let dependencies: AuthDependencies

    public init(dependencies: AuthDependencies) {
        self.dependencies = dependencies
    }

    public func signInMock() {
        dependencies.analytics.track(AnalyticsEvent(name: "auth_sign_in"))
        dependencies.logger.info("Mock sign-in complete.")
        state = .signedIn
    }
}

public struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel

    public init(viewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            TrustIconView(.shield, size: 44)
            Text("auth_title")
                .font(TrustTypography.title)
                .foregroundStyle(TrustColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.state == .signedIn ? "auth_state_signed_in" : "auth_state_signed_out")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("auth_sign_in", action: viewModel.signInMock)
        }
        .padding(TrustSpacing.lg)
        .accessibilityElement(children: .contain)
    }
}
