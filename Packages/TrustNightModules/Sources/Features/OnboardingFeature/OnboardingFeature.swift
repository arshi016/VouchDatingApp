import SwiftUI
import AVFoundation
import CoreLocation
import DesignSystem
import Domain
import FoundationKit
import Persistence

public struct OnboardingDependencies {
    public let analytics: AnalyticsTracking
    public let logger: Logger
    public let preferencesRepository: OnboardingPreferencesRepository
    public let permissionClient: PermissionRequesting
    public let notificationScheduler: NotificationScheduling

    public init(
        analytics: AnalyticsTracking,
        logger: Logger,
        preferencesRepository: OnboardingPreferencesRepository,
        permissionClient: PermissionRequesting,
        notificationScheduler: NotificationScheduling
    ) {
        self.analytics = analytics
        self.logger = logger
        self.preferencesRepository = preferencesRepository
        self.permissionClient = permissionClient
        self.notificationScheduler = notificationScheduler
    }
}

public enum PermissionState: String, Equatable {
    case notDetermined
    case granted
    case denied
    case restricted
    case skipped

    var isGranted: Bool {
        self == .granted
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .notDetermined: return "onboarding_permission_not_determined"
        case .granted: return "onboarding_permission_granted"
        case .denied: return "onboarding_permission_denied"
        case .restricted: return "onboarding_permission_restricted"
        case .skipped: return "onboarding_permission_skipped"
        }
    }
}

public protocol PermissionRequesting {
    var cameraStatus: PermissionState { get }
    var locationStatus: PermissionState { get }
    func requestCameraPermission() async -> PermissionState
    func requestLocationPermission() async -> PermissionState
}

public final class SystemPermissionClient: PermissionRequesting {
    private let locationClient = LocationPermissionClient()

    public init() {}

    public var cameraStatus: PermissionState {
        PermissionState(AVCaptureDevice.authorizationStatus(for: .video))
    }

    public var locationStatus: PermissionState {
        PermissionState(CLLocationManager.authorizationStatus())
    }

    public func requestCameraPermission() async -> PermissionState {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    public func requestLocationPermission() async -> PermissionState {
        await locationClient.requestWhenInUse()
    }
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public private(set) var step: OnboardingStep
    @Published public var consentCamera = false
    @Published public var consentBiometrics = false
    @Published public var discoverVisible = true
    @Published public var distanceBucket: DistanceBucket = .cityArea
    @Published public var incognitoEvents = false
    @Published public var cameraPermission: PermissionState = .notDetermined
    @Published public var locationPermission: PermissionState = .notDetermined
    @Published public var trustedContactName = ""
    @Published public var trustedContactPhone = ""
    @Published public var checkInRemindersEnabled = false
    @Published public var errorMessage: String?
    @Published public var isLoading = false
    @Published public var finished = false

    private var stateMachine = OnboardingStateMachine()
    private let dependencies: OnboardingDependencies

    public init(dependencies: OnboardingDependencies) {
        self.dependencies = dependencies
        self.step = stateMachine.state.step
        self.cameraPermission = dependencies.permissionClient.cameraStatus
        self.locationPermission = dependencies.permissionClient.locationStatus
    }

    public func next() {
        errorMessage = nil

        if step == .consent {
            _ = stateMachine.handle(.setConsent(camera: consentCamera, biometrics: consentBiometrics))
            if !stateMachine.state.consentAccepted {
                errorMessage = NSLocalizedString("onboarding_error_consent", comment: "")
                return
            }
        }

        if step == .safety {
            Task { await completeOnboarding() }
            return
        }

        if !stateMachine.handle(.next) {
            errorMessage = NSLocalizedString("onboarding_error_generic", comment: "")
            return
        }

        step = stateMachine.state.step
    }

    public func back() {
        _ = stateMachine.handle(.back)
        step = stateMachine.state.step
    }

    public func requestCameraPermission() {
        Task {
            let state = await dependencies.permissionClient.requestCameraPermission()
            await MainActor.run { self.cameraPermission = state }
        }
    }

    public func requestLocationPermission() {
        Task {
            let state = await dependencies.permissionClient.requestLocationPermission()
            await MainActor.run { self.locationPermission = state }
        }
    }

    public func skipLocationPermission() {
        locationPermission = .skipped
    }

    public func updateCheckInReminders(_ enabled: Bool) {
        checkInRemindersEnabled = enabled
        if enabled {
            Task { _ = await dependencies.notificationScheduler.requestAuthorization() }
        }
    }

    private func completeOnboarding() async {
        isLoading = true
        errorMessage = nil

        let preferences = OnboardingPreferences(
            consentCamera: consentCamera,
            consentBiometrics: consentBiometrics,
            privacy: OnboardingPrivacySettings(
                discoverVisible: discoverVisible,
                distanceBucket: distanceBucket,
                incognitoEventsDefault: incognitoEvents
            ),
            permissions: OnboardingPermissions(
                cameraGranted: cameraPermission == .granted,
                locationGranted: locationPermission == .granted,
                locationSkipped: locationPermission == .skipped
            ),
            safety: OnboardingSafetySettings(
                trustedContact: trustedContact(),
                checkInRemindersEnabled: checkInRemindersEnabled
            ),
            completedAt: Date()
        )

        do {
            try await dependencies.preferencesRepository.savePreferences(preferences)
            dependencies.analytics.track(AnalyticsEvent(name: "onboarding_completed"))
            _ = stateMachine.handle(.next)
            step = stateMachine.state.step
            finished = true
        } catch {
            errorMessage = NSLocalizedString("onboarding_error_generic", comment: "")
        }

        isLoading = false
    }

    private func trustedContact() -> TrustedContact? {
        let trimmedName = trustedContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else { return nil }
        return TrustedContact(name: trimmedName, phone: trimmedPhone)
    }
}

public struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    private let onFinished: (() -> Void)?

    public init(viewModel: OnboardingViewModel, onFinished: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onFinished = onFinished
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                StepHeader(step: viewModel.step)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                switch viewModel.step {
                case .intro:
                    IntroStep(viewModel: viewModel)
                case .consent:
                    ConsentStep(viewModel: viewModel)
                case .privacy:
                    PrivacyStep(viewModel: viewModel)
                case .permissions:
                    PermissionsStep(viewModel: viewModel)
                case .safety:
                    SafetyStep(viewModel: viewModel)
                case .completed:
                    CompletionStep()
                }
            }
            .padding(TrustSpacing.lg)
        }
        .onChange(of: viewModel.finished) { finished in
            if finished { onFinished?() }
        }
    }
}

private struct StepHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.xs) {
            Text("onboarding_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(progressText)
                .font(TrustTypography.caption)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }

    private var progressText: String {
        let index = max(1, min(5, stepIndex))
        return String(format: NSLocalizedString("onboarding_step_of", comment: ""), index, 5)
    }

    private var stepIndex: Int {
        switch step {
        case .intro: return 1
        case .consent: return 2
        case .privacy: return 3
        case .permissions: return 4
        case .safety: return 5
        case .completed: return 5
        }
    }
}

private struct IntroStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("onboarding_intro_title")
                .font(TrustTypography.headline)
            Text("onboarding_intro_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("onboarding_continue", action: viewModel.next)
        }
    }
}

private struct ConsentStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("onboarding_consent_title")
                .font(TrustTypography.headline)
            Text("onboarding_consent_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            ToggleRow("onboarding_consent_camera", subtitleKey: "onboarding_consent_camera_note", isOn: $viewModel.consentCamera)
            ToggleRow("onboarding_consent_biometrics", subtitleKey: "onboarding_consent_biometrics_note", isOn: $viewModel.consentBiometrics)
            PrimaryButton("onboarding_continue", action: viewModel.next)
                .disabled(!(viewModel.consentCamera && viewModel.consentBiometrics))
            SecondaryButton("onboarding_back", action: viewModel.back)
        }
    }
}

private struct PrivacyStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("onboarding_privacy_title")
                .font(TrustTypography.headline)
            Text("onboarding_privacy_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            ToggleRow("onboarding_privacy_discover", subtitleKey: "onboarding_privacy_discover_note", isOn: $viewModel.discoverVisible)
            PickerRow("onboarding_privacy_distance", options: DistanceBucket.allCases, selection: $viewModel.distanceBucket) { bucket in
                bucket.rawValue
            }
            ToggleRow("onboarding_privacy_incognito", subtitleKey: "onboarding_privacy_incognito_note", isOn: $viewModel.incognitoEvents)
            PrimaryButton("onboarding_continue", action: viewModel.next)
            SecondaryButton("onboarding_back", action: viewModel.back)
        }
    }
}

private struct PermissionsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("onboarding_permissions_title")
                .font(TrustTypography.headline)
            Text("onboarding_permissions_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)

            PermissionRow(
                titleKey: "onboarding_permission_camera",
                status: viewModel.cameraPermission,
                actionTitleKey: "onboarding_permission_allow_camera",
                action: viewModel.requestCameraPermission
            )

            PermissionRow(
                titleKey: "onboarding_permission_location",
                status: viewModel.locationPermission,
                actionTitleKey: "onboarding_permission_allow_location",
                action: viewModel.requestLocationPermission
            )

            Text("onboarding_permission_skip_note")
                .font(TrustTypography.caption)
                .foregroundStyle(TrustColors.textSecondary)
            SecondaryButton("onboarding_permission_skip_location", action: viewModel.skipLocationPermission)

            PrimaryButton("onboarding_continue", action: viewModel.next)
            SecondaryButton("onboarding_back", action: viewModel.back)
        }
    }
}

private struct SafetyStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("onboarding_safety_title")
                .font(TrustTypography.headline)
            Text("onboarding_safety_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            TrustTextField("onboarding_trusted_name", placeholderKey: "onboarding_trusted_name_placeholder", text: $viewModel.trustedContactName)
            TrustTextField("onboarding_trusted_phone", placeholderKey: "onboarding_trusted_phone_placeholder", text: $viewModel.trustedContactPhone)
            ToggleRow("onboarding_checkin_toggle", subtitleKey: "onboarding_checkin_note", isOn: Binding(
                get: { viewModel.checkInRemindersEnabled },
                set: { viewModel.updateCheckInReminders($0) }
            ))

            if viewModel.isLoading {
                LoadingSpinner()
            }

            PrimaryButton("onboarding_finish", action: viewModel.next)
            SecondaryButton("onboarding_back", action: viewModel.back)
        }
    }
}

private struct CompletionStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("onboarding_complete_title")
                .font(TrustTypography.headline)
            Text("onboarding_complete_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }
}

private struct PermissionRow: View {
    let titleKey: LocalizedStringKey
    let status: PermissionState
    let actionTitleKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: TrustSpacing.xs) {
                    Text(titleKey)
                        .font(TrustTypography.body)
                    Text(status.descriptionKey)
                        .font(TrustTypography.caption)
                        .foregroundStyle(TrustColors.textSecondary)
                }
                Spacer(minLength: TrustSpacing.sm)
                SecondaryButton(actionTitleKey, action: action)
                    .frame(maxWidth: 180)
                    .disabled(status == .granted)
            }
        }
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
        .background(TrustColors.danger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private final class LocationPermissionClient: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<PermissionState, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() async -> PermissionState {
        let status = PermissionState(CLLocationManager.authorizationStatus())
        if status != .notDetermined {
            return status
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = continuation else { return }
        continuation.resume(returning: PermissionState(manager.authorizationStatus))
        self.continuation = nil
    }
}

private extension PermissionState {
    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized:
            self = .granted
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .restricted
        }
    }

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            self = .granted
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .restricted
        }
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(
            viewModel: OnboardingViewModel(
                dependencies: OnboardingDependencies(
                    analytics: NoopAnalytics(),
                    logger: ConsoleLogger(),
                    preferencesRepository: PreviewOnboardingPreferencesRepository(),
                    permissionClient: SystemPermissionClient(),
                    notificationScheduler: LocalNotificationScheduler()
                )
            )
        )
    }
}

private final class PreviewOnboardingPreferencesRepository: OnboardingPreferencesRepository {
    func fetchPreferences() async throws -> OnboardingPreferences? { nil }
    func savePreferences(_ preferences: OnboardingPreferences) async throws {}
    func clearPreferences() async throws {}
}
#endif
