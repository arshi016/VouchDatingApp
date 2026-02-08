import XCTest
@testable import EventsFeature
import FoundationKit
import Networking
import Persistence

final class EventsFeatureTests: XCTestCase {
    func testLoadsCachedEvents() async {
        let eventRepo = StubEventRepository()
        let now = Date()
        eventRepo.events = [
            EventEntity(
                id: "event_1",
                title: "Zero Trust Social",
                description: nil,
                startsAt: now,
                endsAt: now.addingTimeInterval(3600),
                areaLabel: "Berlin",
                venueHint: nil,
                hostId: "host_1",
                capacity: 50,
                attendeeCount: 10,
                createdAt: now
            )
        ]

        let viewModel = EventsViewModel(
            dependencies: EventsDependencies(
                apiClient: MockAPIClient(),
                analytics: StubAnalytics(),
                logger: StubLogger(),
                eventRepository: eventRepo,
                rsvpRepository: StubRSVPRepository(),
                checkinRepository: StubCheckinRepository(),
                currentUserId: "host_1"
            )
        )

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(viewModel.events.isEmpty)
    }
}

private final class StubEventRepository: EventRepository {
    var events: [EventEntity] = []

    func fetchEvent(id: String) async throws -> EventEntity? {
        events.first { $0.id == id }
    }

    func fetchEvents(hostId: String?) async throws -> [EventEntity] {
        events
    }

    func upsertEvent(_ event: EventEntity) async throws {
        events.append(event)
    }

    func deleteEvent(id: String) async throws {
        events.removeAll { $0.id == id }
    }
}

private final class StubRSVPRepository: EventRSVPRepository {
    func fetchRSVP(eventId: String, userId: String) async throws -> EventRSVPEntity? { nil }
    func fetchRSVPs(eventId: String) async throws -> [EventRSVPEntity] { [] }
    func upsertRSVP(_ rsvp: EventRSVPEntity) async throws {}
    func deleteRSVP(eventId: String, userId: String) async throws {}
}

private final class StubCheckinRepository: EventCheckinRepository {
    func fetchCheckin(eventId: String, userId: String) async throws -> EventCheckinEntity? { nil }
    func fetchCheckins(eventId: String) async throws -> [EventCheckinEntity] { [] }
    func upsertCheckin(_ checkin: EventCheckinEntity) async throws {}
    func deleteCheckin(eventId: String, userId: String) async throws {}
}

private final class StubAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

private struct StubLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
