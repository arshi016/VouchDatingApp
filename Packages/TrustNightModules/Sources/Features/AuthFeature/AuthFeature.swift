import SwiftUI
import AuthenticationServices
import DesignSystem
import FoundationKit
import Networking

public struct AuthDependencies {
    public let authService: AuthService
    public let analytics: AnalyticsTracking
    public let logger: Logger
    public let isMockMode: Bool

    public init(authService: AuthService, analytics: AnalyticsTracking, logger: Logger, isMockMode: Bool = false) {
        self.authService = authService
        self.analytics = analytics
        self.logger = logger
        self.isMockMode = isMockMode
    }
}

public struct AuthSession: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let isNewUser: Bool
}

public protocol AuthService {
    func restoreSession() async -> AuthSession?
    func signInWithApple(identityToken: String, authorizationCode: String, nonce: String?) async throws -> AuthSession
    func requestEmailOTP(email: String) async throws
    func verifyEmailOTP(email: String, otp: String) async throws -> AuthSession
    func logout() async
    func requestAccountDeletion() async throws
}

public final class NetworkAuthService: AuthService {
    private let apiClient: APIClient
    private let secureStore: SecureStoring
    private let logger: Logger

    public init(apiClient: APIClient, secureStore: SecureStoring, logger: Logger) {
        self.apiClient = apiClient
        self.secureStore = secureStore
        self.logger = logger
    }

    public func restoreSession() async -> AuthSession? {
        guard let accessToken = SecureTokenStore.readString(from: secureStore, key: AuthStorageKeys.accessToken),
              let refreshToken = SecureTokenStore.readString(from: secureStore, key: AuthStorageKeys.refreshToken) else {
            return nil
        }
        let hasLoggedIn = SecureTokenStore.readString(from: secureStore, key: AuthStorageKeys.hasLoggedIn) != nil
        return AuthSession(accessToken: accessToken, refreshToken: refreshToken, isNewUser: !hasLoggedIn)
    }

    public func signInWithApple(identityToken: String, authorizationCode: String, nonce: String?) async throws -> AuthSession {
        let request = AppleSignInRequest(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce)
        let response: AuthResponse = try await apiClient.request(
            Endpoint(path: "auth/apple", method: .post, body: request, requiresAuth: false)
        )
        return try persistSession(from: response)
    }

    public func requestEmailOTP(email: String) async throws {
        let request = EmailOTPRequest(email: email)
        let _: EmptyResponse = try await apiClient.request(
            Endpoint(path: "auth/otp/request", method: .post, body: request, requiresAuth: false)
        )
    }

    public func verifyEmailOTP(email: String, otp: String) async throws -> AuthSession {
        let request = EmailOTPVerifyRequest(email: email, otp: otp)
        let response: AuthResponse = try await apiClient.request(
            Endpoint(path: "auth/otp/verify", method: .post, body: request, requiresAuth: false)
        )
        return try persistSession(from: response)
    }

    public func logout() async {
        let endpoint = Endpoint<EmptyResponse>(path: "auth/logout", method: .post, requiresAuth: true)
        _ = try? await apiClient.request(endpoint)
        SecureTokenStore.clear(secureStore)
    }

    public func requestAccountDeletion() async throws {
        let endpoint = Endpoint<EmptyResponse>(path: "account/delete-request", method: .post, requiresAuth: true)
        _ = try await apiClient.request(endpoint)
    }

    private func persistSession(from response: AuthResponse) throws -> AuthSession {
        try SecureTokenStore.saveString(response.accessToken, in: secureStore, key: AuthStorageKeys.accessToken)
        try SecureTokenStore.saveString(response.refreshToken, in: secureStore, key: AuthStorageKeys.refreshToken)

        let hasLoggedIn = SecureTokenStore.readString(from: secureStore, key: AuthStorageKeys.hasLoggedIn) != nil
        try SecureTokenStore.saveString("true", in: secureStore, key: AuthStorageKeys.hasLoggedIn)

        let isNewUser = response.isNewUser ?? !hasLoggedIn
        logger.info("Auth session persisted. New user: \(isNewUser)")
        return AuthSession(accessToken: response.accessToken, refreshToken: response.refreshToken, isNewUser: isNewUser)
    }
}

public final class MockAuthService: AuthService {
    private var session: AuthSession?

    public init() {}

    public func restoreSession() async -> AuthSession? {
        session
    }

    public func signInWithApple(identityToken: String, authorizationCode: String, nonce: String?) async throws -> AuthSession {
        let newSession = AuthSession(accessToken: "mock_access", refreshToken: "mock_refresh", isNewUser: true)
        session = newSession
        return newSession
    }

    public func requestEmailOTP(email: String) async throws {}

    public func verifyEmailOTP(email: String, otp: String) async throws -> AuthSession {
        let newSession = AuthSession(accessToken: "mock_access", refreshToken: "mock_refresh", isNewUser: false)
        session = newSession
        return newSession
    }

    public func logout() async {
        session = nil
    }

    public func requestAccountDeletion() async throws {}
}

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public private(set) var session: AuthSession?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var email = ""
    @Published public var otpCode = ""
    @Published public var didSendOTP = false
    @Published public var showEmailFlow = false
    @Published public var showDeletionAlert = false
    @Published public var deletionRequested = false

    public let isMockMode: Bool
    private let dependencies: AuthDependencies

    public init(dependencies: AuthDependencies) {
        self.dependencies = dependencies
        self.isMockMode = dependencies.isMockMode
        Task { await restoreSession() }
    }

    public func restoreSession() async {
        let restored = await dependencies.authService.restoreSession()
        if let restored {
            session = restored
        }
    }

    public func signInWithApple(identityToken: String, authorizationCode: String, nonce: String?) {
        Task { await signInWithAppleAsync(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce) }
    }

    public func signInMock() {
        Task { await signInWithMockAsync() }
    }

    public func requestEmailOTP() {
        Task { await requestEmailOTPAsync() }
    }

    public func verifyEmailOTP() {
        Task { await verifyEmailOTPAsync() }
    }

    public func logout() {
        Task { await logoutAsync() }
    }

    public func requestAccountDeletion() {
        Task { await requestAccountDeletionAsync() }
    }

    private func signInWithAppleAsync(identityToken: String, authorizationCode: String, nonce: String?) async {
        await clearError()
        await setLoading(true)
        do {
            let session = try await dependencies.authService.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            )
            dependencies.analytics.track(AnalyticsEvent(name: "auth_sign_in"))
            await setSession(session)
        } catch {
            await setError(error)
        }
        await setLoading(false)
    }

    private func signInWithMockAsync() async {
        await clearError()
        await setLoading(true)
        do {
            let session = try await dependencies.authService.signInWithApple(
                identityToken: "mock_identity",
                authorizationCode: "mock_code",
                nonce: nil
            )
            await setSession(session)
        } catch {
            await setError(error)
        }
        await setLoading(false)
    }

    private func requestEmailOTPAsync() async {
        await clearError()
        await setLoading(true)
        do {
            try await dependencies.authService.requestEmailOTP(email: email)
            didSendOTP = true
        } catch {
            await setError(error)
        }
        await setLoading(false)
    }

    private func verifyEmailOTPAsync() async {
        await clearError()
        await setLoading(true)
        do {
            let session = try await dependencies.authService.verifyEmailOTP(email: email, otp: otpCode)
            dependencies.analytics.track(AnalyticsEvent(name: "auth_email_verified"))
            await setSession(session)
        } catch {
            await setError(error)
        }
        await setLoading(false)
    }

    private func logoutAsync() async {
        await dependencies.authService.logout()
        session = nil
        didSendOTP = false
        otpCode = ""
        email = ""
        showEmailFlow = false
        deletionRequested = false
    }

    private func requestAccountDeletionAsync() async {
        await clearError()
        await setLoading(true)
        do {
            try await dependencies.authService.requestAccountDeletion()
            deletionRequested = true
        } catch {
            await setError(error)
        }
        await setLoading(false)
    }

    private func setSession(_ session: AuthSession) async {
        await MainActor.run {
            self.session = session
            self.errorMessage = nil
            self.showEmailFlow = false
        }
    }

    private func setError(_ error: Error) async {
        await MainActor.run {
            self.errorMessage = AuthErrorPresenter.message(for: error)
        }
    }

    private func clearError() async {
        await MainActor.run { self.errorMessage = nil }
    }

    private func setLoading(_ loading: Bool) async {
        await MainActor.run { self.isLoading = loading }
    }
}

public struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel
    private let onAuthenticated: ((AuthSession) -> Void)?

    public init(viewModel: AuthViewModel, onAuthenticated: ((AuthSession) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        content
            .navigationDestination(isPresented: $viewModel.showEmailFlow) {
                EmailFallbackView(viewModel: viewModel)
            }
            .onChange(of: viewModel.session) { session in
                guard let session else { return }
                onAuthenticated?(session)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let session = viewModel.session {
            AuthenticatedView(
                session: session,
                onLogout: viewModel.logout,
                onDelete: { viewModel.showDeletionAlert = true },
                deletionRequested: viewModel.deletionRequested
            )
            .alert("auth_delete_title", isPresented: $viewModel.showDeletionAlert) {
                Button("auth_delete_confirm", role: .destructive, action: viewModel.requestAccountDeletion)
                Button("auth_cancel", role: .cancel) {}
            } message: {
                Text("auth_delete_message")
            }
        } else {
            WelcomeView(viewModel: viewModel)
        }
    }
}

private struct WelcomeView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                TrustIconView(.shield, size: 48)
                Text("auth_welcome_title")
                    .font(TrustTypography.title)
                    .foregroundStyle(TrustColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("auth_welcome_subtitle")
                    .font(TrustTypography.body)
                    .foregroundStyle(TrustColors.textSecondary)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(Text("auth_sign_in_apple"))

                SecondaryButton("auth_continue_email") {
                    viewModel.didSendOTP = false
                    viewModel.showEmailFlow = true
                }

                if viewModel.isMockMode {
                    PrimaryButton("auth_mock_sign_in", action: viewModel.signInMock)
                }

                if viewModel.isLoading {
                    LoadingSpinner()
                }
            }
            .padding(TrustSpacing.lg)
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                viewModel.errorMessage = NSLocalizedString("auth_error_generic", comment: "")
                return
            }
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            guard let identityToken, let authCode else {
                viewModel.errorMessage = NSLocalizedString("auth_error_generic", comment: "")
                return
            }
            viewModel.signInWithApple(identityToken: identityToken, authorizationCode: authCode, nonce: nil)
        case .failure(let error):
            viewModel.errorMessage = AuthErrorPresenter.message(for: error)
        }
    }
}

private struct EmailFallbackView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                Text("auth_email_title")
                    .font(TrustTypography.title)
                    .accessibilityAddTraits(.isHeader)
                Text("auth_email_subtitle")
                    .font(TrustTypography.body)
                    .foregroundStyle(TrustColors.textSecondary)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                TrustTextField("auth_email_label", placeholderKey: "auth_email_placeholder", text: $viewModel.email)

                if viewModel.didSendOTP {
                    TrustTextField("auth_otp_label", placeholderKey: "auth_otp_placeholder", text: $viewModel.otpCode)
                }

                PrimaryButton(viewModel.didSendOTP ? "auth_verify_code" : "auth_send_link") {
                    if viewModel.didSendOTP {
                        viewModel.verifyEmailOTP()
                    } else {
                        viewModel.requestEmailOTP()
                    }
                }

                if viewModel.didSendOTP {
                    SecondaryButton("auth_resend_code", action: viewModel.requestEmailOTP)
                }

                if viewModel.isLoading {
                    LoadingSpinner()
                }
            }
            .padding(TrustSpacing.lg)
        }
        .navigationTitle(Text("auth_email_nav"))
    }
}

private struct AuthenticatedView: View {
    let session: AuthSession
    let onLogout: () -> Void
    let onDelete: () -> Void
    let deletionRequested: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("auth_logged_in_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(session.isNewUser ? "auth_logged_in_new_user" : "auth_logged_in_returning")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)

            if deletionRequested {
                Toast(titleKey: "auth_delete_requested", messageKey: "auth_delete_requested_detail", style: .info)
            }

            PrimaryButton("auth_logout", action: onLogout)
            DestructiveButton("auth_delete_request", action: onDelete)
        }
        .padding(TrustSpacing.lg)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: TrustSpacing.sm) {
            TrustIconView(.warning, size: 18)
            Text(message)
                .font(TrustTypography.caption)
                .foregroundStyle(TrustColors.danger)
            Spacer(minLength: 0)
        }
        .padding(TrustSpacing.sm)
        .background(TrustColors.danger.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private enum AuthStorageKeys {
    static let accessToken = "auth_access_token"
    static let refreshToken = "auth_refresh_token"
    static let hasLoggedIn = "auth_has_logged_in"
}

private enum SecureTokenStore {
    static func saveString(_ value: String, in store: SecureStoring, key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try store.set(data, for: key)
    }

    static func readString(from store: SecureStoring, key: String) -> String? {
        guard let data = try? store.getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clear(_ store: SecureStoring) {
        try? store.deleteData(for: AuthStorageKeys.accessToken)
        try? store.deleteData(for: AuthStorageKeys.refreshToken)
        try? store.deleteData(for: AuthStorageKeys.hasLoggedIn)
    }
}

private enum AuthErrorPresenter {
    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .offline:
                return NSLocalizedString("auth_error_offline", comment: "")
            case .unauthorized:
                return NSLocalizedString("auth_error_unauthorized", comment: "")
            case let .server(_, _, message):
                return message ?? NSLocalizedString("auth_error_generic", comment: "")
            case .decoding:
                return NSLocalizedString("auth_error_generic", comment: "")
            case .transport:
                return NSLocalizedString("auth_error_generic", comment: "")
            case .invalidURL:
                return NSLocalizedString("auth_error_generic", comment: "")
            case .refreshFailed:
                return NSLocalizedString("auth_error_session", comment: "")
            }
        }
        return NSLocalizedString("auth_error_generic", comment: "")
    }
}

private struct AppleSignInRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String?
}

private struct EmailOTPRequest: Encodable {
    let email: String
}

private struct EmailOTPVerifyRequest: Encodable {
    let email: String
    let otp: String
}

private struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    let isNewUser: Bool?
}

#if DEBUG
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AuthView(
                viewModel: AuthViewModel(
                    dependencies: AuthDependencies(
                        authService: MockAuthService(),
                        analytics: NoopAnalytics(),
                        logger: ConsoleLogger(),
                        isMockMode: true
                    )
                )
            )
        }
    }
}
#endif
