import Foundation
import GRDB
import Domain

public struct UserEntity: Equatable, Codable, Identifiable {
    public let id: String
    public var handle: String
    public var displayName: String
    public var bio: String?
    public var badges: [String]
    public var trustSummary: [String: String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        handle: String,
        displayName: String,
        bio: String? = nil,
        badges: [String] = [],
        trustSummary: [String: String] = [:],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.bio = bio
        self.badges = badges
        self.trustSummary = trustSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ProfilePhotoEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let userId: String
    public var url: String
    public var isPrimary: Bool
    public var blurUntilUnlocked: Bool
    public var createdAt: Date

    public init(
        id: String,
        userId: String,
        url: String,
        isPrimary: Bool,
        blurUntilUnlocked: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.url = url
        self.isPrimary = isPrimary
        self.blurUntilUnlocked = blurUntilUnlocked
        self.createdAt = createdAt
    }
}

public struct EventEntity: Equatable, Codable, Identifiable {
    public let id: String
    public var title: String
    public var description: String?
    public var startsAt: Date
    public var endsAt: Date
    public var areaLabel: String
    public var venueHint: String?
    public var hostId: String
    public var capacity: Int
    public var attendeeCount: Int
    public var createdAt: Date

    public init(
        id: String,
        title: String,
        description: String? = nil,
        startsAt: Date,
        endsAt: Date,
        areaLabel: String,
        venueHint: String? = nil,
        hostId: String,
        capacity: Int,
        attendeeCount: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.areaLabel = areaLabel
        self.venueHint = venueHint
        self.hostId = hostId
        self.capacity = capacity
        self.attendeeCount = attendeeCount
        self.createdAt = createdAt
    }
}

public enum RSVPStatus: String, Codable {
    case going
    case maybe
    case declined
}

public struct EventRSVPEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let eventId: String
    public let userId: String
    public var status: RSVPStatus
    public var createdAt: Date

    public init(eventId: String, userId: String, status: RSVPStatus, createdAt: Date) {
        self.id = "\(eventId):\(userId)"
        self.eventId = eventId
        self.userId = userId
        self.status = status
        self.createdAt = createdAt
    }
}

public struct EventCheckinEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let eventId: String
    public let userId: String
    public var checkedInAt: Date
    public var metadata: [String: String]

    public init(eventId: String, userId: String, checkedInAt: Date, metadata: [String: String] = [:]) {
        self.id = "\(eventId):\(userId)"
        self.eventId = eventId
        self.userId = userId
        self.checkedInAt = checkedInAt
        self.metadata = metadata
    }
}

public enum VouchStatus: String, Codable {
    case pending
    case mutual
}

public struct VouchEntity: Equatable, Codable, Identifiable {
    public let id: String
    public var eventId: String?
    public var fromUserId: String
    public var toUserId: String
    public var status: VouchStatus
    public var createdAt: Date

    public init(
        id: String,
        eventId: String? = nil,
        fromUserId: String,
        toUserId: String,
        status: VouchStatus,
        createdAt: Date
    ) {
        self.id = id
        self.eventId = eventId
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.createdAt = createdAt
    }
}

public struct TrustLogEntry: Equatable, Codable, Identifiable {
    public let id: String
    public let userId: String
    public var type: String
    public var metadata: [String: String]
    public var createdAt: Date

    public init(
        id: String,
        userId: String,
        type: String,
        metadata: [String: String] = [:],
        createdAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

public enum InviteStatus: String, Codable {
    case pending
    case accepted
    case maybe
    case declined
}

public struct InviteEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let fromUserId: String
    public let toUserId: String
    public var eventId: String?
    public var status: InviteStatus
    public var createdAt: Date

    public init(
        id: String,
        fromUserId: String,
        toUserId: String,
        eventId: String? = nil,
        status: InviteStatus,
        createdAt: Date
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.eventId = eventId
        self.status = status
        self.createdAt = createdAt
    }
}

public struct ChatThreadEntity: Equatable, Codable, Identifiable {
    public let id: String
    public var eventId: String?
    public var participantIds: [String]
    public var expiresAt: Date
    public var createdAt: Date

    public init(
        id: String,
        eventId: String? = nil,
        participantIds: [String],
        expiresAt: Date,
        createdAt: Date
    ) {
        self.id = id
        self.eventId = eventId
        self.participantIds = participantIds
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

public struct MessageEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let threadId: String
    public let senderId: String
    public var body: String
    public var createdAt: Date

    public init(id: String, threadId: String, senderId: String, body: String, createdAt: Date) {
        self.id = id
        self.threadId = threadId
        self.senderId = senderId
        self.body = body
        self.createdAt = createdAt
    }
}

public struct ReportEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let reporterId: String
    public let targetUserId: String
    public var reason: String
    public var details: String?
    public var createdAt: Date

    public init(id: String, reporterId: String, targetUserId: String, reason: String, details: String? = nil, createdAt: Date) {
        self.id = id
        self.reporterId = reporterId
        self.targetUserId = targetUserId
        self.reason = reason
        self.details = details
        self.createdAt = createdAt
    }
}

public struct BlockEntity: Equatable, Codable, Identifiable {
    public let id: String
    public let blockerId: String
    public let blockedId: String
    public var createdAt: Date

    public init(blockerId: String, blockedId: String, createdAt: Date) {
        self.id = "\(blockerId):\(blockedId)"
        self.blockerId = blockerId
        self.blockedId = blockedId
        self.createdAt = createdAt
    }
}

struct UserRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "users"
    var id: String
    var handle: String
    var displayName: String
    var bio: String?
    var badgesJSON: String
    var trustSummaryJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(from entity: UserEntity) {
        id = entity.id
        handle = entity.handle
        displayName = entity.displayName
        bio = entity.bio
        badgesJSON = PersistenceJSON.encode(entity.badges)
        trustSummaryJSON = PersistenceJSON.encode(entity.trustSummary)
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func toEntity() -> UserEntity {
        UserEntity(
            id: id,
            handle: handle,
            displayName: displayName,
            bio: bio,
            badges: PersistenceJSON.decode([String].self, from: badgesJSON, default: []),
            trustSummary: PersistenceJSON.decode([String: String].self, from: trustSummaryJSON, default: [:]),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct ProfilePhotoRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "profile_photos"
    var id: String
    var userId: String
    var url: String
    var isPrimary: Bool
    var blurUntilUnlocked: Bool
    var createdAt: Date

    init(from entity: ProfilePhotoEntity) {
        id = entity.id
        userId = entity.userId
        url = entity.url
        isPrimary = entity.isPrimary
        blurUntilUnlocked = entity.blurUntilUnlocked
        createdAt = entity.createdAt
    }

    func toEntity() -> ProfilePhotoEntity {
        ProfilePhotoEntity(
            id: id,
            userId: userId,
            url: url,
            isPrimary: isPrimary,
            blurUntilUnlocked: blurUntilUnlocked,
            createdAt: createdAt
        )
    }
}

struct EventRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "events"
    var id: String
    var title: String
    var description: String?
    var startsAt: Date
    var endsAt: Date
    var areaLabel: String
    var venueHint: String?
    var hostId: String
    var capacity: Int
    var attendeeCount: Int
    var createdAt: Date

    init(from entity: EventEntity) {
        id = entity.id
        title = entity.title
        description = entity.description
        startsAt = entity.startsAt
        endsAt = entity.endsAt
        areaLabel = entity.areaLabel
        venueHint = entity.venueHint
        hostId = entity.hostId
        capacity = entity.capacity
        attendeeCount = entity.attendeeCount
        createdAt = entity.createdAt
    }

    func toEntity() -> EventEntity {
        EventEntity(
            id: id,
            title: title,
            description: description,
            startsAt: startsAt,
            endsAt: endsAt,
            areaLabel: areaLabel,
            venueHint: venueHint,
            hostId: hostId,
            capacity: capacity,
            attendeeCount: attendeeCount,
            createdAt: createdAt
        )
    }
}

struct EventRSVPRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "event_rsvps"
    var eventId: String
    var userId: String
    var status: String
    var createdAt: Date

    init(from entity: EventRSVPEntity) {
        eventId = entity.eventId
        userId = entity.userId
        status = entity.status.rawValue
        createdAt = entity.createdAt
    }

    func toEntity() -> EventRSVPEntity {
        EventRSVPEntity(
            eventId: eventId,
            userId: userId,
            status: RSVPStatus(rawValue: status) ?? .maybe,
            createdAt: createdAt
        )
    }
}

struct EventCheckinRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "event_checkins"
    var eventId: String
    var userId: String
    var checkedInAt: Date
    var metadataJSON: String

    init(from entity: EventCheckinEntity) {
        eventId = entity.eventId
        userId = entity.userId
        checkedInAt = entity.checkedInAt
        metadataJSON = PersistenceJSON.encode(entity.metadata)
    }

    func toEntity() -> EventCheckinEntity {
        EventCheckinEntity(
            eventId: eventId,
            userId: userId,
            checkedInAt: checkedInAt,
            metadata: PersistenceJSON.decode([String: String].self, from: metadataJSON, default: [:])
        )
    }
}

struct VouchRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "vouches"
    var id: String
    var eventId: String?
    var fromUserId: String
    var toUserId: String
    var status: String
    var createdAt: Date

    init(from entity: VouchEntity) {
        id = entity.id
        eventId = entity.eventId
        fromUserId = entity.fromUserId
        toUserId = entity.toUserId
        status = entity.status.rawValue
        createdAt = entity.createdAt
    }

    func toEntity() -> VouchEntity {
        VouchEntity(
            id: id,
            eventId: eventId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            status: VouchStatus(rawValue: status) ?? .pending,
            createdAt: createdAt
        )
    }
}

struct TrustLogRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "trust_log"
    var id: String
    var userId: String
    var type: String
    var metadataJSON: String
    var createdAt: Date

    init(from entity: TrustLogEntry) {
        id = entity.id
        userId = entity.userId
        type = entity.type
        metadataJSON = PersistenceJSON.encode(entity.metadata)
        createdAt = entity.createdAt
    }

    func toEntity() -> TrustLogEntry {
        TrustLogEntry(
            id: id,
            userId: userId,
            type: type,
            metadata: PersistenceJSON.decode([String: String].self, from: metadataJSON, default: [:]),
            createdAt: createdAt
        )
    }
}

struct InviteRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "invites"
    var id: String
    var fromUserId: String
    var toUserId: String
    var eventId: String?
    var status: String
    var createdAt: Date

    init(from entity: InviteEntity) {
        id = entity.id
        fromUserId = entity.fromUserId
        toUserId = entity.toUserId
        eventId = entity.eventId
        status = entity.status.rawValue
        createdAt = entity.createdAt
    }

    func toEntity() -> InviteEntity {
        InviteEntity(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            eventId: eventId,
            status: InviteStatus(rawValue: status) ?? .pending,
            createdAt: createdAt
        )
    }
}

struct ChatThreadRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "chat_threads"
    var id: String
    var eventId: String?
    var participantIdsJSON: String
    var expiresAt: Date
    var createdAt: Date

    init(from entity: ChatThreadEntity) {
        id = entity.id
        eventId = entity.eventId
        participantIdsJSON = PersistenceJSON.encode(entity.participantIds)
        expiresAt = entity.expiresAt
        createdAt = entity.createdAt
    }

    func toEntity() -> ChatThreadEntity {
        ChatThreadEntity(
            id: id,
            eventId: eventId,
            participantIds: PersistenceJSON.decode([String].self, from: participantIdsJSON, default: []),
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }
}

struct MessageRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "messages"
    var id: String
    var threadId: String
    var senderId: String
    var body: String
    var createdAt: Date

    init(from entity: MessageEntity) {
        id = entity.id
        threadId = entity.threadId
        senderId = entity.senderId
        body = entity.body
        createdAt = entity.createdAt
    }

    func toEntity() -> MessageEntity {
        MessageEntity(id: id, threadId: threadId, senderId: senderId, body: body, createdAt: createdAt)
    }
}

struct ReportRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "reports"
    var id: String
    var reporterId: String
    var targetUserId: String
    var reason: String
    var details: String?
    var createdAt: Date

    init(from entity: ReportEntity) {
        id = entity.id
        reporterId = entity.reporterId
        targetUserId = entity.targetUserId
        reason = entity.reason
        details = entity.details
        createdAt = entity.createdAt
    }

    func toEntity() -> ReportEntity {
        ReportEntity(
            id: id,
            reporterId: reporterId,
            targetUserId: targetUserId,
            reason: reason,
            details: details,
            createdAt: createdAt
        )
    }
}

struct BlockRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "blocks"
    var blockerId: String
    var blockedId: String
    var createdAt: Date

    init(from entity: BlockEntity) {
        blockerId = entity.blockerId
        blockedId = entity.blockedId
        createdAt = entity.createdAt
    }

    func toEntity() -> BlockEntity {
        BlockEntity(blockerId: blockerId, blockedId: blockedId, createdAt: createdAt)
    }
}

enum PersistenceJSON {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return string
    }

    static func decode<T: Decodable>(_ type: T.Type, from string: String?, default defaultValue: T) -> T {
        guard let string,
              let data = string.data(using: .utf8),
              let value = try? decoder.decode(T.self, from: data) else {
            return defaultValue
        }
        return value
    }
}

struct OnboardingPreferencesRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "onboarding_preferences"
    var id: String
    var payloadJSON: String
    var updatedAt: Date

    init(id: String = "primary", preferences: OnboardingPreferences, updatedAt: Date) {
        self.id = id
        self.payloadJSON = PersistenceJSON.encode(preferences)
        self.updatedAt = updatedAt
    }

    func toPreferences() -> OnboardingPreferences {
        PersistenceJSON.decode(OnboardingPreferences.self, from: payloadJSON, default: OnboardingPreferences())
    }
}

struct DiscoverProfileRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "discover_profiles"
    var id: String
    var displayName: String
    var age: Int
    var distanceBucket: String
    var badgesJSON: String
    var isHumanVerified: Bool
    var isIRLVerified: Bool
    var intent: String
    var photoURL: String?
    var isBlurred: Bool
    var summary: String
    var updatedAt: Date

    init(from profile: DiscoverProfile, updatedAt: Date) {
        id = profile.id
        displayName = profile.displayName
        age = profile.age
        distanceBucket = profile.distanceBucket
        badgesJSON = PersistenceJSON.encode(profile.badges)
        isHumanVerified = profile.isHumanVerified
        isIRLVerified = profile.isIRLVerified
        intent = profile.intent.rawValue
        photoURL = profile.photoURL
        isBlurred = profile.isBlurred
        summary = profile.summary
        self.updatedAt = updatedAt
    }

    func toDomain() -> DiscoverProfile {
        DiscoverProfile(
            id: id,
            displayName: displayName,
            age: age,
            distanceBucket: distanceBucket,
            badges: PersistenceJSON.decode([String].self, from: badgesJSON, default: []),
            isHumanVerified: isHumanVerified,
            isIRLVerified: isIRLVerified,
            intent: IntentMode(rawValue: intent) ?? .eventsOnly,
            photoURL: photoURL,
            isBlurred: isBlurred,
            summary: summary
        )
    }
}

struct WaveQuotaRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "wave_quota"
    var id: String
    var count: Int
    var lastReset: Date

    init(id: String = "daily", quota: WaveQuota) {
        self.id = id
        self.count = quota.count
        self.lastReset = quota.lastReset
    }

    func toDomain() -> WaveQuota {
        WaveQuota(count: count, lastReset: lastReset)
    }
}
