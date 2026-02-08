import XCTest
import GRDB
@testable import Persistence
import Domain

final class PersistenceTests: XCTestCase {
    func testMigrationsCreateTables() throws {
        let dbQueue = try DatabaseQueue()
        try DatabaseManager.migrator().migrate(dbQueue)
        try dbQueue.read { db in
            XCTAssertTrue(db.tableExists("users"))
            XCTAssertTrue(db.tableExists("profile_photos"))
            XCTAssertTrue(db.tableExists("events"))
            XCTAssertTrue(db.tableExists("event_rsvps"))
            XCTAssertTrue(db.tableExists("event_checkins"))
            XCTAssertTrue(db.tableExists("vouches"))
            XCTAssertTrue(db.tableExists("trust_log"))
            XCTAssertTrue(db.tableExists("invites"))
            XCTAssertTrue(db.tableExists("chat_threads"))
            XCTAssertTrue(db.tableExists("messages"))
            XCTAssertTrue(db.tableExists("reports"))
            XCTAssertTrue(db.tableExists("blocks"))
            XCTAssertTrue(db.tableExists("onboarding_preferences"))
        }
    }

    func testRepositoriesCRUD() async throws {
        let dbManager = try DatabaseManager(inMemory: true)
        let now = Date()

        let userRepo = GRDBUserRepository(dbManager: dbManager)
        let user = UserEntity(
            id: "user_1",
            handle: "riley",
            displayName: "Riley",
            bio: "Security analyst",
            badges: ["verified"],
            trustSummary: ["score": "high"],
            createdAt: now,
            updatedAt: now
        )
        try await userRepo.upsertUser(user)
        let fetchedUser = try await userRepo.fetchUser(id: "user_1")
        XCTAssertEqual(fetchedUser?.displayName, "Riley")

        let photoRepo = GRDBProfilePhotoRepository(dbManager: dbManager)
        let photo = ProfilePhotoEntity(
            id: "photo_1",
            userId: "user_1",
            url: "https://example.com/1.jpg",
            isPrimary: true,
            blurUntilUnlocked: false,
            createdAt: now
        )
        try await photoRepo.upsertPhoto(photo)
        let photos = try await photoRepo.fetchPhotos(userId: "user_1")
        XCTAssertEqual(photos.count, 1)

        let eventRepo = GRDBEventRepository(dbManager: dbManager)
        let event = EventEntity(
            id: "event_1",
            title: "Zero Trust Social",
            description: "Meetup",
            startsAt: now,
            endsAt: now.addingTimeInterval(3600),
            areaLabel: "Berlin",
            venueHint: "Near central station",
            hostId: "user_1",
            capacity: 50,
            createdAt: now
        )
        try await eventRepo.upsertEvent(event)
        let fetchedEvent = try await eventRepo.fetchEvent(id: "event_1")
        XCTAssertEqual(fetchedEvent?.title, "Zero Trust Social")

        let rsvpRepo = GRDBEventRSVPRepository(dbManager: dbManager)
        let rsvp = EventRSVPEntity(eventId: "event_1", userId: "user_1", status: .going, createdAt: now)
        try await rsvpRepo.upsertRSVP(rsvp)
        let fetchedRSVP = try await rsvpRepo.fetchRSVP(eventId: "event_1", userId: "user_1")
        XCTAssertEqual(fetchedRSVP?.status, .going)

        let checkinRepo = GRDBEventCheckinRepository(dbManager: dbManager)
        let checkin = EventCheckinEntity(eventId: "event_1", userId: "user_1", checkedInAt: now)
        try await checkinRepo.upsertCheckin(checkin)
        let fetchedCheckin = try await checkinRepo.fetchCheckin(eventId: "event_1", userId: "user_1")
        XCTAssertEqual(fetchedCheckin?.eventId, "event_1")

        let vouchRepo = GRDBVouchRepository(dbManager: dbManager)
        let vouch = VouchEntity(id: "vouch_1", eventId: "event_1", fromUserId: "user_1", toUserId: "user_2", status: .pending, createdAt: now)
        try await vouchRepo.upsertVouch(vouch)
        let fetchedVouch = try await vouchRepo.fetchVouch(id: "vouch_1")
        XCTAssertEqual(fetchedVouch?.status, .pending)

        let trustLogRepo = GRDBTrustLogRepository(dbManager: dbManager)
        let entry = TrustLogEntry(id: "log_1", userId: "user_1", type: "vouch_received", metadata: ["fromUserId": "user_2"], createdAt: now)
        try await trustLogRepo.addEntry(entry)
        let log = try await trustLogRepo.fetchTrustLog(userId: "user_1")
        XCTAssertEqual(log.count, 1)

        let inviteRepo = GRDBInviteRepository(dbManager: dbManager)
        let invite = InviteEntity(id: "invite_1", fromUserId: "user_1", toUserId: "user_2", eventId: "event_1", status: .pending, createdAt: now)
        try await inviteRepo.upsertInvite(invite)
        let invites = try await inviteRepo.fetchInvites(userId: "user_2")
        XCTAssertEqual(invites.count, 1)

        let threadRepo = GRDBChatThreadRepository(dbManager: dbManager)
        let thread = ChatThreadEntity(id: "thread_1", eventId: "event_1", participantIds: ["user_1", "user_2"], expiresAt: now.addingTimeInterval(3600), createdAt: now)
        try await threadRepo.upsertThread(thread)
        let fetchedThread = try await threadRepo.fetchThread(id: "thread_1")
        XCTAssertEqual(fetchedThread?.participantIds, ["user_1", "user_2"])

        let messageRepo = GRDBMessageRepository(dbManager: dbManager)
        let message = MessageEntity(id: "msg_1", threadId: "thread_1", senderId: "user_1", body: "Hello", createdAt: now)
        try await messageRepo.upsertMessage(message)
        let messages = try await messageRepo.fetchMessages(threadId: "thread_1")
        XCTAssertEqual(messages.count, 1)

        let reportRepo = GRDBReportRepository(dbManager: dbManager)
        let report = ReportEntity(id: "report_1", reporterId: "user_1", targetUserId: "user_2", reason: "spam", details: "Details", createdAt: now)
        try await reportRepo.addReport(report)
        let reports = try await reportRepo.fetchReports(reporterId: "user_1")
        XCTAssertEqual(reports.count, 1)

        let blockRepo = GRDBBlockRepository(dbManager: dbManager)
        let block = BlockEntity(blockerId: "user_1", blockedId: "user_3", createdAt: now)
        try await blockRepo.upsertBlock(block)
        let blocks = try await blockRepo.fetchBlocks(blockerId: "user_1")
        XCTAssertEqual(blocks.count, 1)
        try await blockRepo.deleteBlock(blockerId: "user_1", blockedId: "user_3")
        let blocksAfterDelete = try await blockRepo.fetchBlocks(blockerId: "user_1")
        XCTAssertEqual(blocksAfterDelete.count, 0)

        let onboardingRepo = GRDBOnboardingPreferencesRepository(dbManager: dbManager)
        let preferences = OnboardingPreferences(
            consentCamera: true,
            consentBiometrics: true,
            privacy: OnboardingPrivacySettings(
                discoverVisible: true,
                distanceBucket: .cityArea,
                incognitoEventsDefault: false
            ),
            permissions: OnboardingPermissions(cameraGranted: true, locationGranted: false, locationSkipped: true),
            safety: OnboardingSafetySettings(
                trustedContact: TrustedContact(name: "Alex", phone: "123456"),
                checkInRemindersEnabled: true
            ),
            completedAt: now
        )
        try await onboardingRepo.savePreferences(preferences)
        let fetchedPreferences = try await onboardingRepo.fetchPreferences()
        XCTAssertEqual(fetchedPreferences?.privacy.distanceBucket, .cityArea)
    }

    func testStaleWhileRevalidatePolicy() {
        let policy = CachePolicy(mode: .staleWhileRevalidate, maxAge: 60, staleTTL: 120)
        let now = Date()
        XCTAssertTrue(policy.isFresh(lastUpdated: now.addingTimeInterval(-30), now: now))
        XCTAssertTrue(policy.isWithinStaleWindow(lastUpdated: now.addingTimeInterval(-90), now: now))
        XCTAssertFalse(policy.isWithinStaleWindow(lastUpdated: now.addingTimeInterval(-200), now: now))
    }
}
