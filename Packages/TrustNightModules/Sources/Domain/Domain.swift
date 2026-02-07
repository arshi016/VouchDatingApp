import Foundation

public struct UserID: Hashable, Codable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct CoarseLocation: Hashable, Codable {
    public let regionCode: String

    public init(regionCode: String) {
        self.regionCode = regionCode
    }
}

public struct UserProfile: Hashable, Codable {
    public let id: UserID
    public var displayName: String
    public var location: CoarseLocation?

    public init(id: UserID, displayName: String, location: CoarseLocation? = nil) {
        self.id = id
        self.displayName = displayName
        self.location = location
    }
}

public struct TrustScore: Equatable, Codable {
    public let value: Int

    public init(value: Int) {
        self.value = max(0, min(100, value))
    }
}

public protocol TrustScoreCalculating {
    func score(endorsements: Int, reports: Int) -> TrustScore
}

public struct TrustScoreCalculator: TrustScoreCalculating {
    public init() {}

    public func score(endorsements: Int, reports: Int) -> TrustScore {
        let rawScore = (endorsements * 10) - (reports * 15)
        return TrustScore(value: rawScore)
    }
}

public struct ComputeTrustScoreUseCase {
    private let calculator: TrustScoreCalculating

    public init(calculator: TrustScoreCalculating = TrustScoreCalculator()) {
        self.calculator = calculator
    }

    public func execute(endorsements: Int, reports: Int) -> TrustScore {
        calculator.score(endorsements: endorsements, reports: reports)
    }
}

public struct FaceTemplate: Hashable, Codable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}

public struct VerificationSession: Hashable, Codable {
    public let userID: UserID
    public let createdAt: Date

    public init(userID: UserID, createdAt: Date = Date()) {
        self.userID = userID
        self.createdAt = createdAt
    }
}
