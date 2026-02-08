import SwiftUI
import DesignSystem
import FoundationKit
import Networking
import Persistence
import Domain

public struct DiscoverDependencies {
    public let apiClient: APIClient
    public let discoverRepository: DiscoverRepository
    public let waveQuotaRepository: WaveQuotaRepository
    public let preferencesRepository: OnboardingPreferencesRepository
    public let analytics: AnalyticsTracking
    public let logger: Logger

    public init(
        apiClient: APIClient,
        discoverRepository: DiscoverRepository,
        waveQuotaRepository: WaveQuotaRepository,
        preferencesRepository: OnboardingPreferencesRepository,
        analytics: AnalyticsTracking,
        logger: Logger
    ) {
        self.apiClient = apiClient
        self.discoverRepository = discoverRepository
        self.waveQuotaRepository = waveQuotaRepository
        self.preferencesRepository = preferencesRepository
        self.analytics = analytics
        self.logger = logger
    }
}

public protocol DiscoverService {
    func fetchCache() async throws -> DiscoverCache
    func refresh(filters: DiscoverFilters, discoverVisible: Bool) async throws -> [DiscoverProfile]
}

public final class NetworkDiscoverService: DiscoverService {
    private let apiClient: APIClient
    private let repository: DiscoverRepository

    public init(apiClient: APIClient, repository: DiscoverRepository) {
        self.apiClient = apiClient
        self.repository = repository
    }

    public func fetchCache() async throws -> DiscoverCache {
        try await repository.fetchCache()
    }

    public func refresh(filters: DiscoverFilters, discoverVisible: Bool) async throws -> [DiscoverProfile] {
        let response: DiscoverFeedResponse = try await apiClient.request(
            Endpoint(
                path: "discover/feed",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "ageMin", value: "\(filters.ageRange.min)"),
                    URLQueryItem(name: "ageMax", value: "\(filters.ageRange.max)"),
                    URLQueryItem(name: "intent", value: filters.intent.rawValue),
                    URLQueryItem(name: "humanVerifiedOnly", value: filters.humanVerifiedOnly ? "true" : "false"),
                    URLQueryItem(name: "irlVerifiedOnly", value: filters.irlVerifiedOnly ? "true" : "false"),
                    URLQueryItem(name: "discoverVisible", value: discoverVisible ? "true" : "false")
                ],
                requiresAuth: true
            )
        )

        let profiles = response.items.map { $0.toDomain() }
        try await repository.saveProfiles(profiles, updatedAt: Date())
        return profiles
    }
}

@MainActor
public final class DiscoverViewModel: ObservableObject {
    @Published public private(set) var profiles: [DiscoverProfile] = []
    @Published public var filters = DiscoverFilters()
    @Published public var isLoading = false
    @Published public var errorMessageKey: String?
    @Published public var showFilters = false
    @Published public var showHiddenNotice = false
    @Published public var waveRemainingMessageKey: String?

    private let dependencies: DiscoverDependencies
    private let service: DiscoverService
    private let filterEngine = DiscoverFilterEngine()
    private let waveThrottler = WaveThrottler(policy: WaveThrottlePolicy(maxPerDay: 5))
    private let cachePolicy = CachePolicy(mode: .staleWhileRevalidate, maxAge: 120, staleTTL: 600)
    private let onInvite: (DiscoverProfile) -> Void
    private var allProfiles: [DiscoverProfile] = []

    public init(dependencies: DiscoverDependencies, onInvite: @escaping (DiscoverProfile) -> Void) {
        self.dependencies = dependencies
        self.service = NetworkDiscoverService(apiClient: dependencies.apiClient, repository: dependencies.discoverRepository)
        self.onInvite = onInvite
        Task { await load() }
    }

    public func load() async {
        isLoading = true
        errorMessageKey = nil

        let discoverVisible = await fetchDiscoverVisibility()
        showHiddenNotice = !discoverVisible

        do {
            let cache = try await service.fetchCache()
            if cachePolicy.shouldReadCacheFirst, !cache.profiles.isEmpty {
                allProfiles = cache.profiles
                profiles = filterEngine.apply(allProfiles, filters: filters)
                if let lastUpdated = cache.lastUpdated, cachePolicy.isFresh(lastUpdated: lastUpdated) {
                    isLoading = false
                    return
                }
                if let lastUpdated = cache.lastUpdated, cachePolicy.isWithinStaleWindow(lastUpdated: lastUpdated) {
                    Task { await refresh(discoverVisible: discoverVisible) }
                    isLoading = false
                    return
                }
            }

            let remote = try await service.refresh(filters: filters, discoverVisible: discoverVisible)
            allProfiles = remote
            profiles = filterEngine.apply(allProfiles, filters: filters)
        } catch {
            errorMessageKey = "discover_error_generic"
        }

        isLoading = false
    }

    public func refresh() {
        Task { await refresh(discoverVisible: await fetchDiscoverVisibility()) }
    }

    private func refresh(discoverVisible: Bool) async {
        do {
            let remote = try await service.refresh(filters: filters, discoverVisible: discoverVisible)
            allProfiles = remote
            profiles = filterEngine.apply(allProfiles, filters: filters)
        } catch {
            errorMessageKey = "discover_error_generic"
        }
    }

    public func applyFilters() {
        profiles = filterEngine.apply(allProfiles, filters: filters)
        refresh()
    }

    public func wave(at profile: DiscoverProfile) {
        Task {
            do {
                let quota = try await dependencies.waveQuotaRepository.fetchQuota()
                let normalized = waveThrottler.normalizedQuota(quota)
                guard waveThrottler.canSendWave(quota: normalized) else {
                    waveRemainingMessageKey = "discover_wave_limit"
                    return
                }
                let updated = waveThrottler.consume(quota: normalized)
                try await dependencies.waveQuotaRepository.saveQuota(updated)
                dependencies.analytics.track(AnalyticsEvent(name: "discover_wave_sent"))
                waveRemainingMessageKey = nil
            } catch {
                waveRemainingMessageKey = "discover_wave_error"
            }
        }
    }

    public func invite(profile: DiscoverProfile) {
        dependencies.analytics.track(AnalyticsEvent(name: "discover_invite_tapped"))
        onInvite(profile)
    }

    private func fetchDiscoverVisibility() async -> Bool {
        guard let preferences = try? await dependencies.preferencesRepository.fetchPreferences() else {
            return true
        }
        return preferences.privacy.discoverVisible
    }
}

public struct DiscoverView: View {
    @StateObject private var viewModel: DiscoverViewModel

    public init(viewModel: DiscoverViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                header

                if viewModel.showHiddenNotice {
                    Toast(titleKey: "discover_hidden_title", messageKey: "discover_hidden_body", style: .info)
                }

                if let message = viewModel.waveRemainingMessageKey {
                    Toast(titleKey: "discover_wave_title", messageKey: LocalizedStringKey(message), style: .warning)
                }

                if viewModel.isLoading {
                    loadingSkeletons
                } else if let errorMessage = viewModel.errorMessageKey {
                    EmptyStateView(
                        titleKey: "discover_error_title",
                        messageKey: LocalizedStringKey(errorMessage),
                        actionTitleKey: "discover_retry",
                        action: viewModel.refresh
                    )
                } else if viewModel.profiles.isEmpty {
                    EmptyStateView(
                        titleKey: "discover_empty_title",
                        messageKey: "discover_empty_body",
                        actionTitleKey: "discover_refresh",
                        action: viewModel.refresh
                    )
                } else {
                    ForEach(viewModel.profiles) { profile in
                        DiscoverCard(profile: profile, onInvite: { viewModel.invite(profile: profile) }, onWave: { viewModel.wave(at: profile) })
                    }
                }
            }
            .padding(TrustSpacing.lg)
        }
        .sheet(isPresented: $viewModel.showFilters) {
            DiscoverFiltersSheet(filters: $viewModel.filters, onApply: {
                viewModel.applyFilters()
                viewModel.showFilters = false
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            HStack {
                Text("discover_title")
                    .font(TrustTypography.title)
                Spacer()
                SecondaryButton("discover_filters") { viewModel.showFilters = true }
                    .frame(maxWidth: 140)
            }
            Text("discover_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }

    private var loadingSkeletons: some View {
        VStack(spacing: TrustSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                Card {
                    SkeletonView(height: 180)
                    SkeletonView(height: 16)
                    SkeletonView(height: 16)
                }
            }
        }
    }
}

private struct DiscoverCard: View {
    let profile: DiscoverProfile
    let onInvite: () -> Void
    let onWave: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: TrustSpacing.md) {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: profile.photoURL ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(TrustColors.surface)
                    }
                    .frame(height: 200)
                    .clipped()
                    .blur(radius: profile.isBlurred ? 16 : 0)

                    if profile.isBlurred {
                        Badge("discover_photo_locked", style: .accent)
                            .padding(TrustSpacing.sm)
                    }
                }
                VStack(alignment: .leading, spacing: TrustSpacing.xs) {
                    HStack {
                        Text("\(profile.displayName), \(profile.age)")
                            .font(TrustTypography.headline)
                        Spacer()
                        Text(profile.distanceBucket)
                            .font(TrustTypography.caption)
                            .foregroundStyle(TrustColors.textSecondary)
                    }
                    Text(profile.summary)
                        .font(TrustTypography.body)
                        .foregroundStyle(TrustColors.textSecondary)
                }
                HStack(spacing: TrustSpacing.sm) {
                    if profile.isHumanVerified {
                        Badge("discover_badge_human", style: .success)
                    }
                    if profile.isIRLVerified {
                        Badge("discover_badge_irl", style: .accent)
                    }
                }
                HStack(spacing: TrustSpacing.sm) {
                    PrimaryButton("discover_invite", action: onInvite)
                    SecondaryButton("discover_wave", action: onWave)
                }
            }
        }
    }
}

private struct DiscoverFiltersSheet: View {
    @Binding var filters: DiscoverFilters
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("discover_filter_age")) {
                    Stepper(value: $filters.ageRange.min, in: 18...filters.ageRange.max) {
                        Text("\(filters.ageRange.min)")
                    }
                    Stepper(value: $filters.ageRange.max, in: filters.ageRange.min...70) {
                        Text("\(filters.ageRange.max)")
                    }
                }

                Section(header: Text("discover_filter_intent")) {
                    Picker("discover_filter_intent", selection: $filters.intent) {
                        ForEach(IntentMode.allCases, id: \.self) { mode in
                            Text(intentTitle(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("discover_filter_verified")) {
                    Toggle("discover_filter_human", isOn: $filters.humanVerifiedOnly)
                    Toggle("discover_filter_irl", isOn: $filters.irlVerifiedOnly)
                }
            }
            .navigationTitle("discover_filters_title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("discover_apply", action: onApply)
                }
            }
        }
    }

    private func intentTitle(_ mode: IntentMode) -> LocalizedStringKey {
        switch mode {
        case .relationship:
            return "discover_intent_relationship"
        case .friends:
            return "discover_intent_friends"
        case .eventsOnly:
            return "discover_intent_events"
        }
    }
}

private struct DiscoverFeedResponse: Decodable {
    let items: [DiscoverProfileDTO]
}

private struct DiscoverProfileDTO: Decodable {
    let id: String
    let displayName: String
    let age: Int
    let distanceBucket: String
    let badges: [String]?
    let isHumanVerified: Bool
    let isIRLVerified: Bool
    let intent: String?
    let photoUrl: String?
    let blurUntilUnlocked: Bool
    let summary: String

    func toDomain() -> DiscoverProfile {
        DiscoverProfile(
            id: id,
            displayName: displayName,
            age: age,
            distanceBucket: distanceBucket,
            badges: badges ?? [],
            isHumanVerified: isHumanVerified,
            isIRLVerified: isIRLVerified,
            intent: IntentMode(rawValue: intent ?? IntentMode.eventsOnly.rawValue) ?? .eventsOnly,
            photoURL: photoUrl,
            isBlurred: blurUntilUnlocked,
            summary: summary
        )
    }
}

#if DEBUG
struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(
            viewModel: DiscoverViewModel(
                dependencies: DiscoverDependencies(
                    apiClient: MockAPIClient(),
                    discoverRepository: PreviewDiscoverRepository(),
                    waveQuotaRepository: PreviewWaveQuotaRepository(),
                    preferencesRepository: PreviewOnboardingRepository(),
                    analytics: NoopAnalytics(),
                    logger: ConsoleLogger()
                ),
                onInvite: { _ in }
            )
        )
    }
}

private final class PreviewDiscoverRepository: DiscoverRepository {
    func fetchCache() async throws -> DiscoverCache { DiscoverCache(profiles: [], lastUpdated: nil) }
    func saveProfiles(_ profiles: [DiscoverProfile], updatedAt: Date) async throws {}
    func clearProfiles() async throws {}
}

private final class PreviewWaveQuotaRepository: WaveQuotaRepository {
    func fetchQuota() async throws -> WaveQuota { WaveQuota() }
    func saveQuota(_ quota: WaveQuota) async throws {}
}

private final class PreviewOnboardingRepository: OnboardingPreferencesRepository {
    func fetchPreferences() async throws -> OnboardingPreferences? { nil }
    func savePreferences(_ preferences: OnboardingPreferences) async throws {}
    func clearPreferences() async throws {}
}
#endif
