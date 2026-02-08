import Foundation

public enum OnboardingStep: Int, CaseIterable, Codable {
    case intro
    case consent
    case privacy
    case permissions
    case safety
    case completed

    public var isTerminal: Bool {
        self == .completed
    }
}

public enum DistanceBucket: String, Codable, CaseIterable {
    case under2km = "<2km"
    case twoTo5km = "2-5km"
    case cityArea = "City area"
    case regional = "Regional"
}

public struct OnboardingPrivacySettings: Equatable, Codable {
    public var discoverVisible: Bool
    public var distanceBucket: DistanceBucket
    public var incognitoEventsDefault: Bool

    public init(
        discoverVisible: Bool = true,
        distanceBucket: DistanceBucket = .cityArea,
        incognitoEventsDefault: Bool = false
    ) {
        self.discoverVisible = discoverVisible
        self.distanceBucket = distanceBucket
        self.incognitoEventsDefault = incognitoEventsDefault
    }
}

public struct OnboardingPermissions: Equatable, Codable {
    public var cameraGranted: Bool
    public var locationGranted: Bool
    public var locationSkipped: Bool

    public init(cameraGranted: Bool = false, locationGranted: Bool = false, locationSkipped: Bool = false) {
        self.cameraGranted = cameraGranted
        self.locationGranted = locationGranted
        self.locationSkipped = locationSkipped
    }
}

public struct TrustedContact: Equatable, Codable {
    public var name: String
    public var phone: String

    public init(name: String, phone: String) {
        self.name = name
        self.phone = phone
    }
}

public struct OnboardingSafetySettings: Equatable, Codable {
    public var trustedContact: TrustedContact?
    public var checkInRemindersEnabled: Bool

    public init(trustedContact: TrustedContact? = nil, checkInRemindersEnabled: Bool = false) {
        self.trustedContact = trustedContact
        self.checkInRemindersEnabled = checkInRemindersEnabled
    }
}

public struct OnboardingPreferences: Equatable, Codable {
    public var consentCamera: Bool
    public var consentBiometrics: Bool
    public var privacy: OnboardingPrivacySettings
    public var permissions: OnboardingPermissions
    public var safety: OnboardingSafetySettings
    public var completedAt: Date?

    public init(
        consentCamera: Bool = false,
        consentBiometrics: Bool = false,
        privacy: OnboardingPrivacySettings = OnboardingPrivacySettings(),
        permissions: OnboardingPermissions = OnboardingPermissions(),
        safety: OnboardingSafetySettings = OnboardingSafetySettings(),
        completedAt: Date? = nil
    ) {
        self.consentCamera = consentCamera
        self.consentBiometrics = consentBiometrics
        self.privacy = privacy
        self.permissions = permissions
        self.safety = safety
        self.completedAt = completedAt
    }
}

public enum OnboardingAction: Equatable {
    case next
    case back
    case setConsent(camera: Bool, biometrics: Bool)
    case reset
}

public struct OnboardingState: Equatable {
    public var step: OnboardingStep
    public var consentAccepted: Bool

    public init(step: OnboardingStep = .intro, consentAccepted: Bool = false) {
        self.step = step
        self.consentAccepted = consentAccepted
    }
}

public struct OnboardingStateMachine {
    public private(set) var state: OnboardingState

    public init(state: OnboardingState = OnboardingState()) {
        self.state = state
    }

    @discardableResult
    public mutating func handle(_ action: OnboardingAction) -> Bool {
        switch action {
        case .reset:
            state = OnboardingState()
            return true
        case .setConsent(let camera, let biometrics):
            state.consentAccepted = camera && biometrics
            return true
        case .back:
            guard let previous = previousStep(from: state.step) else { return false }
            state.step = previous
            return true
        case .next:
            if state.step == .consent && !state.consentAccepted {
                return false
            }
            guard let next = nextStep(from: state.step) else { return false }
            state.step = next
            return true
        }
    }

    private func nextStep(from step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .intro: return .consent
        case .consent: return .privacy
        case .privacy: return .permissions
        case .permissions: return .safety
        case .safety: return .completed
        case .completed: return nil
        }
    }

    private func previousStep(from step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .intro: return nil
        case .consent: return .intro
        case .privacy: return .consent
        case .permissions: return .privacy
        case .safety: return .permissions
        case .completed: return .safety
        }
    }
}
