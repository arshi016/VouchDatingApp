import Foundation

public enum IntentMode: String, Codable, CaseIterable {
    case relationship
    case friends
    case eventsOnly
}

public struct AgeRange: Equatable, Codable {
    public var min: Int
    public var max: Int

    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }

    public func contains(_ age: Int) -> Bool {
        age >= min && age <= max
    }
}

public struct DiscoverFilters: Equatable, Codable {
    public var ageRange: AgeRange
    public var intent: IntentMode
    public var humanVerifiedOnly: Bool
    public var irlVerifiedOnly: Bool

    public init(
        ageRange: AgeRange = AgeRange(min: 21, max: 40),
        intent: IntentMode = .eventsOnly,
        humanVerifiedOnly: Bool = false,
        irlVerifiedOnly: Bool = false
    ) {
        self.ageRange = ageRange
        self.intent = intent
        self.humanVerifiedOnly = humanVerifiedOnly
        self.irlVerifiedOnly = irlVerifiedOnly
    }
}

public struct DiscoverProfile: Equatable, Identifiable, Codable {
    public let id: String
    public let displayName: String
    public let age: Int
    public let distanceBucket: String
    public let badges: [String]
    public let isHumanVerified: Bool
    public let isIRLVerified: Bool
    public let intent: IntentMode
    public let photoURL: String?
    public let isBlurred: Bool
    public let summary: String

    public init(
        id: String,
        displayName: String,
        age: Int,
        distanceBucket: String,
        badges: [String] = [],
        isHumanVerified: Bool,
        isIRLVerified: Bool,
        intent: IntentMode,
        photoURL: String?,
        isBlurred: Bool,
        summary: String
    ) {
        self.id = id
        self.displayName = displayName
        self.age = age
        self.distanceBucket = distanceBucket
        self.badges = badges
        self.isHumanVerified = isHumanVerified
        self.isIRLVerified = isIRLVerified
        self.intent = intent
        self.photoURL = photoURL
        self.isBlurred = isBlurred
        self.summary = summary
    }
}

public struct DiscoverFilterEngine {
    public init() {}

    public func apply(_ profiles: [DiscoverProfile], filters: DiscoverFilters) -> [DiscoverProfile] {
        profiles.filter { profile in
            guard filters.ageRange.contains(profile.age) else { return false }
            if filters.humanVerifiedOnly && !profile.isHumanVerified { return false }
            if filters.irlVerifiedOnly && !profile.isIRLVerified { return false }
            if profile.intent != filters.intent { return false }
            return true
        }
    }
}
