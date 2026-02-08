import Foundation
import GRDB
import Domain

public protocol UserRepository {
    func fetchUser(id: String) async throws -> UserEntity?
    func fetchUsers(ids: [String]) async throws -> [UserEntity]
    func upsertUser(_ user: UserEntity) async throws
    func deleteUser(id: String) async throws
}

public protocol ProfilePhotoRepository {
    func fetchPhotos(userId: String) async throws -> [ProfilePhotoEntity]
    func upsertPhoto(_ photo: ProfilePhotoEntity) async throws
    func deletePhoto(id: String) async throws
}

public protocol EventRepository {
    func fetchEvent(id: String) async throws -> EventEntity?
    func fetchEvents(hostId: String?) async throws -> [EventEntity]
    func upsertEvent(_ event: EventEntity) async throws
    func deleteEvent(id: String) async throws
}

public protocol EventRSVPRepository {
    func fetchRSVP(eventId: String, userId: String) async throws -> EventRSVPEntity?
    func fetchRSVPs(eventId: String) async throws -> [EventRSVPEntity]
    func upsertRSVP(_ rsvp: EventRSVPEntity) async throws
    func deleteRSVP(eventId: String, userId: String) async throws
}

public protocol EventCheckinRepository {
    func fetchCheckin(eventId: String, userId: String) async throws -> EventCheckinEntity?
    func fetchCheckins(eventId: String) async throws -> [EventCheckinEntity]
    func upsertCheckin(_ checkin: EventCheckinEntity) async throws
    func deleteCheckin(eventId: String, userId: String) async throws
}

public protocol VouchRepository {
    func fetchVouch(id: String) async throws -> VouchEntity?
    func fetchVouches(fromUserId: String?, toUserId: String?) async throws -> [VouchEntity]
    func upsertVouch(_ vouch: VouchEntity) async throws
    func deleteVouch(id: String) async throws
}

public protocol TrustLogRepository {
    func fetchTrustLog(userId: String) async throws -> [TrustLogEntry]
    func addEntry(_ entry: TrustLogEntry) async throws
    func deleteEntry(id: String) async throws
}

public protocol InviteRepository {
    func fetchInvites(userId: String) async throws -> [InviteEntity]
    func upsertInvite(_ invite: InviteEntity) async throws
    func deleteInvite(id: String) async throws
}

public protocol ChatThreadRepository {
    func fetchThread(id: String) async throws -> ChatThreadEntity?
    func fetchThreads(eventId: String?) async throws -> [ChatThreadEntity]
    func upsertThread(_ thread: ChatThreadEntity) async throws
    func deleteThread(id: String) async throws
}

public protocol MessageRepository {
    func fetchMessages(threadId: String) async throws -> [MessageEntity]
    func upsertMessage(_ message: MessageEntity) async throws
    func deleteMessage(id: String) async throws
}

public protocol ReportRepository {
    func fetchReports(reporterId: String) async throws -> [ReportEntity]
    func addReport(_ report: ReportEntity) async throws
}

public protocol BlockRepository {
    func fetchBlocks(blockerId: String) async throws -> [BlockEntity]
    func upsertBlock(_ block: BlockEntity) async throws
    func deleteBlock(blockerId: String, blockedId: String) async throws
}

public protocol OnboardingPreferencesRepository {
    func fetchPreferences() async throws -> OnboardingPreferences?
    func savePreferences(_ preferences: OnboardingPreferences) async throws
    func clearPreferences() async throws
}

public struct DiscoverCache: Equatable {
    public let profiles: [DiscoverProfile]
    public let lastUpdated: Date?

    public init(profiles: [DiscoverProfile], lastUpdated: Date?) {
        self.profiles = profiles
        self.lastUpdated = lastUpdated
    }
}

public protocol DiscoverRepository {
    func fetchCache() async throws -> DiscoverCache
    func saveProfiles(_ profiles: [DiscoverProfile], updatedAt: Date) async throws
    func clearProfiles() async throws
}

public protocol WaveQuotaRepository {
    func fetchQuota() async throws -> WaveQuota
    func saveQuota(_ quota: WaveQuota) async throws
}

public final class GRDBUserRepository: UserRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchUser(id: String) async throws -> UserEntity? {
        try await dbManager.dbQueue.read { db in
            try UserRecord.fetchOne(db, key: id)?.toEntity()
        }
    }

    public func fetchUsers(ids: [String]) async throws -> [UserEntity] {
        try await dbManager.dbQueue.read { db in
            try UserRecord
                .filter(ids: ids)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertUser(_ user: UserEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try UserRecord(from: user).save(db)
        }
    }

    public func deleteUser(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try UserRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBProfilePhotoRepository: ProfilePhotoRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchPhotos(userId: String) async throws -> [ProfilePhotoEntity] {
        try await dbManager.dbQueue.read { db in
            try ProfilePhotoRecord
                .filter(Column("userId") == userId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertPhoto(_ photo: ProfilePhotoEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try ProfilePhotoRecord(from: photo).save(db)
        }
    }

    public func deletePhoto(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try ProfilePhotoRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBEventRepository: EventRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchEvent(id: String) async throws -> EventEntity? {
        try await dbManager.dbQueue.read { db in
            try EventRecord.fetchOne(db, key: id)?.toEntity()
        }
    }

    public func fetchEvents(hostId: String?) async throws -> [EventEntity] {
        try await dbManager.dbQueue.read { db in
            var request = EventRecord.order(Column("startsAt").desc)
            if let hostId {
                request = request.filter(Column("hostId") == hostId)
            }
            return try request.fetchAll(db).map { $0.toEntity() }
        }
    }

    public func upsertEvent(_ event: EventEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try EventRecord(from: event).save(db)
        }
    }

    public func deleteEvent(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try EventRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBEventRSVPRepository: EventRSVPRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchRSVP(eventId: String, userId: String) async throws -> EventRSVPEntity? {
        try await dbManager.dbQueue.read { db in
            try EventRSVPRecord
                .filter(Column("eventId") == eventId && Column("userId") == userId)
                .fetchOne(db)?
                .toEntity()
        }
    }

    public func fetchRSVPs(eventId: String) async throws -> [EventRSVPEntity] {
        try await dbManager.dbQueue.read { db in
            try EventRSVPRecord
                .filter(Column("eventId") == eventId)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertRSVP(_ rsvp: EventRSVPEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try EventRSVPRecord(from: rsvp).save(db)
        }
    }

    public func deleteRSVP(eventId: String, userId: String) async throws {
        try await dbManager.dbQueue.write { db in
            try EventRSVPRecord
                .filter(Column("eventId") == eventId && Column("userId") == userId)
                .deleteAll(db)
        }
    }
}

public final class GRDBEventCheckinRepository: EventCheckinRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchCheckin(eventId: String, userId: String) async throws -> EventCheckinEntity? {
        try await dbManager.dbQueue.read { db in
            try EventCheckinRecord
                .filter(Column("eventId") == eventId && Column("userId") == userId)
                .fetchOne(db)?
                .toEntity()
        }
    }

    public func fetchCheckins(eventId: String) async throws -> [EventCheckinEntity] {
        try await dbManager.dbQueue.read { db in
            try EventCheckinRecord
                .filter(Column("eventId") == eventId)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertCheckin(_ checkin: EventCheckinEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try EventCheckinRecord(from: checkin).save(db)
        }
    }

    public func deleteCheckin(eventId: String, userId: String) async throws {
        try await dbManager.dbQueue.write { db in
            try EventCheckinRecord
                .filter(Column("eventId") == eventId && Column("userId") == userId)
                .deleteAll(db)
        }
    }
}

public final class GRDBVouchRepository: VouchRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchVouch(id: String) async throws -> VouchEntity? {
        try await dbManager.dbQueue.read { db in
            try VouchRecord.fetchOne(db, key: id)?.toEntity()
        }
    }

    public func fetchVouches(fromUserId: String?, toUserId: String?) async throws -> [VouchEntity] {
        try await dbManager.dbQueue.read { db in
            var request = VouchRecord.order(Column("createdAt").desc)
            if let fromUserId {
                request = request.filter(Column("fromUserId") == fromUserId)
            }
            if let toUserId {
                request = request.filter(Column("toUserId") == toUserId)
            }
            return try request.fetchAll(db).map { $0.toEntity() }
        }
    }

    public func upsertVouch(_ vouch: VouchEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try VouchRecord(from: vouch).save(db)
        }
    }

    public func deleteVouch(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try VouchRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBTrustLogRepository: TrustLogRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchTrustLog(userId: String) async throws -> [TrustLogEntry] {
        try await dbManager.dbQueue.read { db in
            try TrustLogRecord
                .filter(Column("userId") == userId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func addEntry(_ entry: TrustLogEntry) async throws {
        try await dbManager.dbQueue.write { db in
            try TrustLogRecord(from: entry).save(db)
        }
    }

    public func deleteEntry(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try TrustLogRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBInviteRepository: InviteRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchInvites(userId: String) async throws -> [InviteEntity] {
        try await dbManager.dbQueue.read { db in
            try InviteRecord
                .filter(Column("toUserId") == userId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertInvite(_ invite: InviteEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try InviteRecord(from: invite).save(db)
        }
    }

    public func deleteInvite(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try InviteRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBChatThreadRepository: ChatThreadRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchThread(id: String) async throws -> ChatThreadEntity? {
        try await dbManager.dbQueue.read { db in
            try ChatThreadRecord.fetchOne(db, key: id)?.toEntity()
        }
    }

    public func fetchThreads(eventId: String?) async throws -> [ChatThreadEntity] {
        try await dbManager.dbQueue.read { db in
            var request = ChatThreadRecord.order(Column("createdAt").desc)
            if let eventId {
                request = request.filter(Column("eventId") == eventId)
            }
            return try request.fetchAll(db).map { $0.toEntity() }
        }
    }

    public func upsertThread(_ thread: ChatThreadEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try ChatThreadRecord(from: thread).save(db)
        }
    }

    public func deleteThread(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try ChatThreadRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBMessageRepository: MessageRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchMessages(threadId: String) async throws -> [MessageEntity] {
        try await dbManager.dbQueue.read { db in
            try MessageRecord
                .filter(Column("threadId") == threadId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertMessage(_ message: MessageEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try MessageRecord(from: message).save(db)
        }
    }

    public func deleteMessage(id: String) async throws {
        try await dbManager.dbQueue.write { db in
            _ = try MessageRecord.deleteOne(db, key: id)
        }
    }
}

public final class GRDBReportRepository: ReportRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchReports(reporterId: String) async throws -> [ReportEntity] {
        try await dbManager.dbQueue.read { db in
            try ReportRecord
                .filter(Column("reporterId") == reporterId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func addReport(_ report: ReportEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try ReportRecord(from: report).save(db)
        }
    }
}

public final class GRDBBlockRepository: BlockRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchBlocks(blockerId: String) async throws -> [BlockEntity] {
        try await dbManager.dbQueue.read { db in
            try BlockRecord
                .filter(Column("blockerId") == blockerId)
                .fetchAll(db)
                .map { $0.toEntity() }
        }
    }

    public func upsertBlock(_ block: BlockEntity) async throws {
        try await dbManager.dbQueue.write { db in
            try BlockRecord(from: block).save(db)
        }
    }

    public func deleteBlock(blockerId: String, blockedId: String) async throws {
        try await dbManager.dbQueue.write { db in
            try BlockRecord
                .filter(Column("blockerId") == blockerId && Column("blockedId") == blockedId)
                .deleteAll(db)
        }
    }
}

public final class GRDBOnboardingPreferencesRepository: OnboardingPreferencesRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchPreferences() async throws -> OnboardingPreferences? {
        try await dbManager.dbQueue.read { db in
            try OnboardingPreferencesRecord.fetchOne(db, key: "primary")?.toPreferences()
        }
    }

    public func savePreferences(_ preferences: OnboardingPreferences) async throws {
        let record = OnboardingPreferencesRecord(preferences: preferences, updatedAt: Date())
        try await dbManager.dbQueue.write { db in
            try record.save(db)
        }
    }

    public func clearPreferences() async throws {
        try await dbManager.dbQueue.write { db in
            _ = try OnboardingPreferencesRecord.deleteOne(db, key: "primary")
        }
    }
}

public final class GRDBDiscoverRepository: DiscoverRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchCache() async throws -> DiscoverCache {
        try await dbManager.dbQueue.read { db in
            let records = try DiscoverProfileRecord.fetchAll(db)
            let lastUpdated = records.map(\.updatedAt).max()
            return DiscoverCache(
                profiles: records.map { $0.toDomain() },
                lastUpdated: lastUpdated
            )
        }
    }

    public func saveProfiles(_ profiles: [DiscoverProfile], updatedAt: Date) async throws {
        try await dbManager.dbQueue.write { db in
            try DiscoverProfileRecord.deleteAll(db)
            for profile in profiles {
                try DiscoverProfileRecord(from: profile, updatedAt: updatedAt).save(db)
            }
        }
    }

    public func clearProfiles() async throws {
        try await dbManager.dbQueue.write { db in
            _ = try DiscoverProfileRecord.deleteAll(db)
        }
    }
}

public final class GRDBWaveQuotaRepository: WaveQuotaRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchQuota() async throws -> WaveQuota {
        try await dbManager.dbQueue.read { db in
            if let record = try WaveQuotaRecord.fetchOne(db, key: "daily") {
                return record.toDomain()
            }
            return WaveQuota()
        }
    }

    public func saveQuota(_ quota: WaveQuota) async throws {
        try await dbManager.dbQueue.write { db in
            try WaveQuotaRecord(quota: quota).save(db)
        }
    }
}
