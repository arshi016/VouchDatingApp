import SwiftUI
import DesignSystem
import FoundationKit
import Networking
import Persistence
import Domain
import AuthFeature
import OnboardingFeature
import VerificationFeature
import DiscoverFeature
import EventsFeature
import VouchFeature
import TrustProfileFeature
import InvitesFeature
import ChatFeature
import SafetyFeature
import ModerationFeature
import SettingsFeature

public final class AppContainer {
    public let logger: Logger
    public let analytics: AnalyticsTracking
    public let featureFlags: FeatureFlagging
    public let secureStore: SecureStoring
    public let apiClient: APIClient
    public let databaseManager: DatabaseManaging
    public let userProfileRepository: UserProfileRepository
    public let authService: AuthService
    public let onboardingPreferencesRepository: OnboardingPreferencesRepository
    public let notificationScheduler: NotificationScheduling
    public let verificationService: VerificationService
    public let discoverRepository: DiscoverRepository
    public let waveQuotaRepository: WaveQuotaRepository

    public init(
        logger: Logger,
        analytics: AnalyticsTracking,
        featureFlags: FeatureFlagging,
        secureStore: SecureStoring,
        apiClient: APIClient,
        databaseManager: DatabaseManaging,
        userProfileRepository: UserProfileRepository,
        authService: AuthService,
        onboardingPreferencesRepository: OnboardingPreferencesRepository,
        notificationScheduler: NotificationScheduling,
        verificationService: VerificationService,
        discoverRepository: DiscoverRepository,
        waveQuotaRepository: WaveQuotaRepository
    ) {
        self.logger = logger
        self.analytics = analytics
        self.featureFlags = featureFlags
        self.secureStore = secureStore
        self.apiClient = apiClient
        self.databaseManager = databaseManager
        self.userProfileRepository = userProfileRepository
        self.authService = authService
        self.onboardingPreferencesRepository = onboardingPreferencesRepository
        self.notificationScheduler = notificationScheduler
        self.verificationService = verificationService
        self.discoverRepository = discoverRepository
        self.waveQuotaRepository = waveQuotaRepository
    }

    public static func live() -> AppContainer {
        let logger = ConsoleLogger()
        let analytics = NoopAnalytics()
        let featureFlags = InMemoryFeatureFlags()
        let secureStore = KeychainSecureStore(service: "com.trustnight.app")
        let tokenProvider = SecureStoreTokenProvider(secureStore: secureStore, tokenKey: "auth_access_token")
        let tokenRefresher = SecureStoreTokenRefresher(secureStore: secureStore, tokenKey: "auth_access_token")
        let configuration = NetworkConfiguration(
            baseURL: URL(string: "https://api.trustnight.example")!,
            timeout: 20,
            defaultHeaders: ["Content-Type": "application/json"]
        )
        let apiClient = URLSessionAPIClient(
            configuration: configuration,
            tokenProvider: tokenProvider,
            tokenRefresher: tokenRefresher,
            retryPolicy: .default,
            reachability: AlwaysReachable(),
            logger: logger
        )

        let databaseManager: DatabaseManaging
        do {
            databaseManager = try DatabaseManager()
        } catch {
            logger.error("Failed to create database, using in-memory store: \(error)")
            databaseManager = (try? DatabaseManager(inMemory: true)) ?? try! DatabaseManager()
        }

        let userProfileRepository = GRDBUserProfileRepository(dbManager: databaseManager)
        let onboardingPreferencesRepository = GRDBOnboardingPreferencesRepository(dbManager: databaseManager)
        let notificationScheduler = LocalNotificationScheduler()
        let discoverRepository = GRDBDiscoverRepository(dbManager: databaseManager)
        let waveQuotaRepository = GRDBWaveQuotaRepository(dbManager: databaseManager)

        #if targetEnvironment(simulator)
        let authService: AuthService = MockAuthService()
        #else
        let authService: AuthService = NetworkAuthService(
            apiClient: apiClient,
            secureStore: secureStore,
            logger: logger
        )
        #endif

        #if targetEnvironment(simulator)
        let verificationService: VerificationService = MockVerificationService()
        #else
        let verificationService: VerificationService = NetworkVerificationService(
            apiClient: apiClient,
            secureStore: secureStore,
            logger: logger
        )
        #endif

        return AppContainer(
            logger: logger,
            analytics: analytics,
            featureFlags: featureFlags,
            secureStore: secureStore,
            apiClient: apiClient,
            databaseManager: databaseManager,
            userProfileRepository: userProfileRepository,
            authService: authService,
            onboardingPreferencesRepository: onboardingPreferencesRepository,
            notificationScheduler: notificationScheduler,
            verificationService: verificationService,
            discoverRepository: discoverRepository,
            waveQuotaRepository: waveQuotaRepository
        )
    }
}

struct SecureStoreTokenProvider: AuthTokenProvider {
    private let secureStore: SecureStoring
    private let tokenKey: String

    init(secureStore: SecureStoring, tokenKey: String) {
        self.secureStore = secureStore
        self.tokenKey = tokenKey
    }

    func fetchToken() async -> String? {
        guard let data = try? secureStore.getData(for: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct SecureStoreTokenRefresher: AuthTokenRefreshing {
    private let secureStore: SecureStoring
    private let tokenKey: String

    init(secureStore: SecureStoring, tokenKey: String) {
        self.secureStore = secureStore
        self.tokenKey = tokenKey
    }

    func refreshToken() async throws -> String {
        guard let data = try? secureStore.getData(for: tokenKey),
              let token = String(data: data, encoding: .utf8) else {
            throw APIError.refreshFailed
        }
        return token
    }
}

public final class AppRouter: ObservableObject {
    @Published public var path = NavigationPath()

    public init() {}

    public func push(_ route: AppRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func reset() {
        path = NavigationPath()
    }
}

public enum AppRoute: Hashable {
    case auth
    case onboarding
    case verification
    case discover
    case events
    case vouch
    case trustProfile
    case invites
    case chat
    case safety
    case moderation
    case settings
}

public struct AppRootView: View {
    private let container: AppContainer
    @StateObject private var router = AppRouter()

    public init(container: AppContainer) {
        self.container = container
    }

    public var body: some View {
        AppCoordinatorView(router: router, container: container)
    }
}

public struct AppCoordinatorView: View {
    @ObservedObject private var router: AppRouter
    private let container: AppContainer

    public init(router: AppRouter, container: AppContainer) {
        self.router = router
        self.container = container
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            DiscoverView(
                viewModel: DiscoverViewModel(
                    dependencies: DiscoverDependencies(
                        apiClient: container.apiClient,
                        discoverRepository: container.discoverRepository,
                        waveQuotaRepository: container.waveQuotaRepository,
                        preferencesRepository: container.onboardingPreferencesRepository,
                        analytics: container.analytics,
                        logger: container.logger
                    ),
                    onInvite: { _ in router.push(.events) }
                )
            )
            .navigationTitle(Text("home_title"))
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .auth:
            AuthView(
                viewModel: AuthViewModel(
                    dependencies: AuthDependencies(
                        authService: container.authService,
                        analytics: container.analytics,
                        logger: container.logger,
                        isMockMode: {
                            #if targetEnvironment(simulator)
                            return true
                            #else
                            return false
                            #endif
                        }()
                    )
                ),
                onAuthenticated: { session in
                    router.reset()
                    if session.isNewUser {
                        router.push(.onboarding)
                    }
                }
            )
        case .onboarding:
            OnboardingView(
                viewModel: OnboardingViewModel(
                    dependencies: OnboardingDependencies(
                        analytics: container.analytics,
                        logger: container.logger,
                        preferencesRepository: container.onboardingPreferencesRepository,
                        permissionClient: SystemPermissionClient(),
                        notificationScheduler: container.notificationScheduler
                    )
                ),
                onFinished: {
                    router.reset()
                    router.push(.verification)
                }
            )
        case .verification:
            #if targetEnvironment(simulator)
            let provider: VerificationProvider = MockVerificationProvider()
            #else
            let provider: VerificationProvider = VisionVerificationProvider()
            #endif
            VerificationView(
                viewModel: VerificationViewModel(
                    dependencies: VerificationDependencies(
                        analytics: container.analytics,
                        logger: container.logger,
                        service: container.verificationService,
                        provider: provider
                    )
                ),
                onCompleted: {
                    router.reset()
                    router.push(.discover)
                }
            )
        case .discover:
            DiscoverView(
                viewModel: DiscoverViewModel(
                    dependencies: DiscoverDependencies(
                        apiClient: container.apiClient,
                        discoverRepository: container.discoverRepository,
                        waveQuotaRepository: container.waveQuotaRepository,
                        preferencesRepository: container.onboardingPreferencesRepository,
                        analytics: container.analytics,
                        logger: container.logger
                    ),
                    onInvite: { _ in router.push(.events) }
                )
            )
        case .events:
            EventsView(
                viewModel: EventsViewModel(
                    dependencies: EventsDependencies(
                        apiClient: container.apiClient,
                        analytics: container.analytics,
                        logger: container.logger
                    )
                )
            )
        case .vouch:
            VouchView(
                viewModel: VouchViewModel(
                    dependencies: VouchDependencies(
                        analytics: container.analytics,
                        calculator: TrustScoreCalculator()
                    )
                )
            )
        case .trustProfile:
            TrustProfileView(
                viewModel: TrustProfileViewModel(
                    dependencies: TrustProfileDependencies(
                        repository: container.userProfileRepository,
                        analytics: container.analytics
                    )
                )
            )
        case .invites:
            InvitesView(
                viewModel: InvitesViewModel(
                    dependencies: InvitesDependencies(
                        analytics: container.analytics
                    )
                )
            )
        case .chat:
            ChatView(
                viewModel: ChatViewModel(
                    dependencies: ChatDependencies(
                        apiClient: container.apiClient,
                        analytics: container.analytics
                    )
                )
            )
        case .safety:
            SafetyView(
                viewModel: SafetyViewModel(
                    dependencies: SafetyDependencies(
                        analytics: container.analytics
                    )
                )
            )
        case .moderation:
            ModerationView(
                viewModel: ModerationViewModel(
                    dependencies: ModerationDependencies(
                        apiClient: container.apiClient,
                        analytics: container.analytics,
                        logger: container.logger
                    )
                )
            )
        case .settings:
            SettingsView(
                viewModel: SettingsViewModel(
                    dependencies: SettingsDependencies(
                        featureFlags: container.featureFlags,
                        secureStore: container.secureStore,
                        analytics: container.analytics
                    )
                )
            )
        }
    }
}
