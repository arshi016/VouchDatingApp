import Foundation
import GRDB
import Domain
import FoundationKit

public protocol DatabaseManaging {
    var dbQueue: DatabaseQueue { get }
}

public final class DatabaseManager: DatabaseManaging {
    public let dbQueue: DatabaseQueue

    public init(inMemory: Bool = false, fileName: String = "trustnight.sqlite") throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            let url = try DatabaseManager.databaseURL(fileName: fileName)
            dbQueue = try DatabaseQueue(path: url.path)
        }
        try setupMigrations()
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

    private func setupMigrations() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createUserProfiles") { db in
            try db.create(table: UserProfileRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("displayName", .text).notNull()
                table.column("regionCode", .text)
            }
        }
        try migrator.migrate(dbQueue)
    }
}

public enum CachePolicy: Hashable, Codable {
    case networkOnly
    case cacheOnly
    case cacheFirst
    case networkFirst

    public var shouldReadCacheFirst: Bool {
        switch self {
        case .cacheFirst, .cacheOnly:
            return true
        case .networkOnly, .networkFirst:
            return false
        }
    }
}

public protocol UserProfileRepository {
    func fetchProfile(userID: UserID) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
}

public final class GRDBUserProfileRepository: UserProfileRepository {
    private let dbManager: DatabaseManaging

    public init(dbManager: DatabaseManaging) {
        self.dbManager = dbManager
    }

    public func fetchProfile(userID: UserID) async throws -> UserProfile? {
        try await dbManager.dbQueue.read { db in
            try UserProfileRecord.fetchOne(db, key: userID.value)?.toDomain()
        }
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        try await dbManager.dbQueue.write { db in
            try UserProfileRecord(from: profile).save(db)
        }
    }
}

struct UserProfileRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_profiles"

    var id: String
    var displayName: String
    var regionCode: String?

    init(from profile: UserProfile) {
        id = profile.id.value
        displayName = profile.displayName
        regionCode = profile.location?.regionCode
    }

    func toDomain() -> UserProfile {
        let location = regionCode.map { CoarseLocation(regionCode: $0) }
        return UserProfile(id: UserID(id), displayName: displayName, location: location)
    }
}
