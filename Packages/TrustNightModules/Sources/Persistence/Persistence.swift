import Foundation
import GRDB
import Domain

public protocol DatabaseManaging {
    var dbQueue: DatabaseQueue { get }
}

public final class DatabaseManager: DatabaseManaging {
    public let dbQueue: DatabaseQueue

    public init(inMemory: Bool = false, fileName: String = "trustnight.sqlite") throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true

        if inMemory {
            dbQueue = try DatabaseQueue(path: ":memory:", configuration: configuration)
        } else {
            let url = try DatabaseManager.databaseURL(fileName: fileName)
            dbQueue = try DatabaseQueue(path: url.path, configuration: configuration)
        }
        try DatabaseManager.migrator().migrate(dbQueue)
    }

    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createUsers") { db in
            try db.create(table: UserRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("handle", .text).notNull()
                table.column("displayName", .text).notNull()
                table.column("bio", .text)
                table.column("badgesJSON", .text).notNull().defaults(to: "[]")
                table.column("trustSummaryJSON", .text).notNull().defaults(to: "{}")
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
            try db.createIndex(on: UserRecord.databaseTableName, columns: ["handle"], unique: true)
        }

        migrator.registerMigration("createProfilePhotos") { db in
            try db.create(table: ProfilePhotoRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("userId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("url", .text).notNull()
                table.column("isPrimary", .boolean).notNull().defaults(to: false)
                table.column("blurUntilUnlocked", .boolean).notNull().defaults(to: false)
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: ProfilePhotoRecord.databaseTableName, columns: ["userId"])
        }

        migrator.registerMigration("createEvents") { db in
            try db.create(table: EventRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("description", .text)
                table.column("startsAt", .datetime).notNull()
                table.column("endsAt", .datetime).notNull()
                table.column("areaLabel", .text).notNull()
                table.column("venueHint", .text)
                table.column("hostId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("capacity", .integer).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: EventRecord.databaseTableName, columns: ["hostId"])
        }

        migrator.registerMigration("createEventRSVPs") { db in
            try db.create(table: EventRSVPRecord.databaseTableName) { table in
                table.column("eventId", .text).notNull().references(EventRecord.databaseTableName, onDelete: .cascade)
                table.column("userId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("status", .text).notNull()
                table.column("createdAt", .datetime).notNull()
                table.primaryKey(["eventId", "userId"])
            }
            try db.createIndex(on: EventRSVPRecord.databaseTableName, columns: ["eventId"])
            try db.createIndex(on: EventRSVPRecord.databaseTableName, columns: ["userId"])
        }

        migrator.registerMigration("createEventCheckins") { db in
            try db.create(table: EventCheckinRecord.databaseTableName) { table in
                table.column("eventId", .text).notNull().references(EventRecord.databaseTableName, onDelete: .cascade)
                table.column("userId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("checkedInAt", .datetime).notNull()
                table.primaryKey(["eventId", "userId"])
            }
            try db.createIndex(on: EventCheckinRecord.databaseTableName, columns: ["eventId"])
        }

        migrator.registerMigration("createVouches") { db in
            try db.create(table: VouchRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("eventId", .text).references(EventRecord.databaseTableName, onDelete: .setNull)
                table.column("fromUserId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("toUserId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("status", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: VouchRecord.databaseTableName, columns: ["fromUserId"])
            try db.createIndex(on: VouchRecord.databaseTableName, columns: ["toUserId"])
            try db.createIndex(on: VouchRecord.databaseTableName, columns: ["eventId"])
        }

        migrator.registerMigration("createTrustLog") { db in
            try db.create(table: TrustLogRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("userId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("type", .text).notNull()
                table.column("metadataJSON", .text).notNull().defaults(to: "{}")
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: TrustLogRecord.databaseTableName, columns: ["userId"])
        }

        migrator.registerMigration("createInvites") { db in
            try db.create(table: InviteRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("fromUserId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("toUserId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("eventId", .text).references(EventRecord.databaseTableName, onDelete: .setNull)
                table.column("status", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: InviteRecord.databaseTableName, columns: ["toUserId"])
        }

        migrator.registerMigration("createChatThreads") { db in
            try db.create(table: ChatThreadRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("eventId", .text).references(EventRecord.databaseTableName, onDelete: .setNull)
                table.column("participantIdsJSON", .text).notNull().defaults(to: "[]")
                table.column("expiresAt", .datetime).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: ChatThreadRecord.databaseTableName, columns: ["eventId"])
        }

        migrator.registerMigration("createMessages") { db in
            try db.create(table: MessageRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("threadId", .text).notNull().references(ChatThreadRecord.databaseTableName, onDelete: .cascade)
                table.column("senderId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("body", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: MessageRecord.databaseTableName, columns: ["threadId"])
        }

        migrator.registerMigration("createReports") { db in
            try db.create(table: ReportRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("reporterId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("targetUserId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("reason", .text).notNull()
                table.column("details", .text)
                table.column("createdAt", .datetime).notNull()
            }
            try db.createIndex(on: ReportRecord.databaseTableName, columns: ["reporterId"])
            try db.createIndex(on: ReportRecord.databaseTableName, columns: ["targetUserId"])
        }

        migrator.registerMigration("createBlocks") { db in
            try db.create(table: BlockRecord.databaseTableName) { table in
                table.column("blockerId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("blockedId", .text).notNull().references(UserRecord.databaseTableName, onDelete: .cascade)
                table.column("createdAt", .datetime).notNull()
                table.primaryKey(["blockerId", "blockedId"])
            }
            try db.createIndex(on: BlockRecord.databaseTableName, columns: ["blockerId"])
        }

        migrator.registerMigration("createOnboardingPreferences") { db in
            try db.create(table: OnboardingPreferencesRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("payloadJSON", .text).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("createDiscoverProfiles") { db in
            try db.create(table: DiscoverProfileRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("displayName", .text).notNull()
                table.column("age", .integer).notNull()
                table.column("distanceBucket", .text).notNull()
                table.column("badgesJSON", .text).notNull().defaults(to: "[]")
                table.column("isHumanVerified", .boolean).notNull().defaults(to: false)
                table.column("isIRLVerified", .boolean).notNull().defaults(to: false)
                table.column("intent", .text).notNull().defaults(to: "eventsOnly")
                table.column("photoURL", .text)
                table.column("isBlurred", .boolean).notNull().defaults(to: false)
                table.column("summary", .text).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("createWaveQuota") { db in
            try db.create(table: WaveQuotaRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("count", .integer).notNull()
                table.column("lastReset", .datetime).notNull()
            }
        }

        migrator.registerMigration("addEventAttendeeCount") { db in
            try db.alter(table: EventRecord.databaseTableName) { table in
                table.add(column: "attendeeCount", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("addCheckinMetadata") { db in
            try db.alter(table: EventCheckinRecord.databaseTableName) { table in
                table.add(column: "metadataJSON", .text).notNull().defaults(to: "{}")
            }
        }

        return migrator
    }

    private static func databaseURL(fileName: String) throws -> URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let baseURL = urls.first else {
            throw GRDBError(.fileError, message: "Missing application support directory.")
        }
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        }
        return baseURL.appendingPathComponent(fileName)
    }
}

public enum CacheMode: String, Codable {
    case networkOnly
    case cacheOnly
    case cacheFirst
    case networkFirst
    case staleWhileRevalidate
}

public struct CachePolicy: Hashable, Codable {
    public let mode: CacheMode
    public let maxAge: TimeInterval
    public let staleTTL: TimeInterval

    public init(mode: CacheMode, maxAge: TimeInterval = 300, staleTTL: TimeInterval = 900) {
        self.mode = mode
        self.maxAge = maxAge
        self.staleTTL = staleTTL
    }

    public var shouldReadCacheFirst: Bool {
        switch mode {
        case .cacheFirst, .cacheOnly, .staleWhileRevalidate:
            return true
        case .networkOnly, .networkFirst:
            return false
        }
    }

    public var shouldServeStale: Bool {
        mode == .staleWhileRevalidate
    }

    public func isFresh(lastUpdated: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastUpdated) <= maxAge
    }

    public func isWithinStaleWindow(lastUpdated: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastUpdated) <= (maxAge + staleTTL)
    }
}

public protocol UserProfileRepository {
    func fetchProfile(userID: UserID) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
}

public final class GRDBUserProfileRepository: UserProfileRepository {
    private let userRepository: UserRepository

    public init(dbManager: DatabaseManaging) {
        self.userRepository = GRDBUserRepository(dbManager: dbManager)
    }

    public func fetchProfile(userID: UserID) async throws -> UserProfile? {
        guard let user = try await userRepository.fetchUser(id: userID.value) else { return nil }
        let regionCode = user.trustSummary["regionCode"]
        let location = regionCode.map { CoarseLocation(regionCode: $0) }
        return UserProfile(id: UserID(user.id), displayName: user.displayName, location: location)
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        let existing = try await userRepository.fetchUser(id: profile.id.value)
        let handle = existing?.handle ?? profile.displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let now = Date()
        var trustSummary = existing?.trustSummary ?? [:]
        if let region = profile.location?.regionCode {
            trustSummary["regionCode"] = region
        }
        let user = UserEntity(
            id: profile.id.value,
            handle: handle,
            displayName: profile.displayName,
            bio: existing?.bio,
            badges: existing?.badges ?? [],
            trustSummary: trustSummary,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        try await userRepository.upsertUser(user)
    }
}
