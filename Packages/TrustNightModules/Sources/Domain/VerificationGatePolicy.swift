import Foundation

public enum VerificationAction: String, Codable {
    case checkIn
    case vouch
    case invite
    case chat
}

public protocol VerificationGatePolicy {
    func requiresReverification(for action: VerificationAction, lastVerifiedAt: Date?) -> Bool
}

public struct DefaultVerificationGatePolicy: VerificationGatePolicy {
    private let maxAge: TimeInterval

    public init(maxAge: TimeInterval = 60 * 60 * 24 * 14) {
        self.maxAge = maxAge
    }

    public func requiresReverification(for action: VerificationAction, lastVerifiedAt: Date?) -> Bool {
        guard let lastVerifiedAt else { return true }
        return Date().timeIntervalSince(lastVerifiedAt) > maxAge
    }
}
