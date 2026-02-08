import SwiftUI
import Foundation
import DesignSystem
import FoundationKit
import Networking
import Persistence
import Domain
import CoreImage.CIFilterBuiltins

public struct EventsDependencies {
    public let apiClient: APIClient
    public let analytics: AnalyticsTracking
    public let logger: Logger
    public let eventRepository: EventRepository
    public let rsvpRepository: EventRSVPRepository
    public let checkinRepository: EventCheckinRepository
    public let currentUserId: String

    public init(
        apiClient: APIClient,
        analytics: AnalyticsTracking,
        logger: Logger,
        eventRepository: EventRepository,
        rsvpRepository: EventRSVPRepository,
        checkinRepository: EventCheckinRepository,
        currentUserId: String
    ) {
        self.apiClient = apiClient
        self.analytics = analytics
        self.logger = logger
        self.eventRepository = eventRepository
        self.rsvpRepository = rsvpRepository
        self.checkinRepository = checkinRepository
        self.currentUserId = currentUserId
    }
}

public protocol EventsService {
    func fetchCache() async throws -> [EventEntity]
    func refreshEvents() async throws -> [EventEntity]
    func createEvent(_ request: EventCreateRequest) async throws -> EventEntity
    func updateRSVP(eventId: String, status: RSVPStatus) async throws -> EventRSVPEntity
    func fetchAttendees(eventId: String) async throws -> [EventAttendee]
    func fetchCheckInToken(eventId: String) async throws -> String
    func validateCheckIn(eventId: String, token: String) async throws -> CheckInResult
}

public final class NetworkEventsService: EventsService {
    private let apiClient: APIClient
    private let eventRepository: EventRepository
    private let rsvpRepository: EventRSVPRepository
    private let checkinRepository: EventCheckinRepository
    private let currentUserId: String

    public init(
        apiClient: APIClient,
        eventRepository: EventRepository,
        rsvpRepository: EventRSVPRepository,
        checkinRepository: EventCheckinRepository,
        currentUserId: String
    ) {
        self.apiClient = apiClient
        self.eventRepository = eventRepository
        self.rsvpRepository = rsvpRepository
        self.checkinRepository = checkinRepository
        self.currentUserId = currentUserId
    }

    public func fetchCache() async throws -> [EventEntity] {
        try await eventRepository.fetchEvents(hostId: nil)
    }

    public func refreshEvents() async throws -> [EventEntity] {
        let response: EventsListResponse = try await apiClient.request(
            Endpoint(path: "events", method: .get, requiresAuth: true)
        )
        let events = response.items.map { $0.toEntity() }
        for event in events {
            try await eventRepository.upsertEvent(event)
        }
        return events
    }

    public func createEvent(_ request: EventCreateRequest) async throws -> EventEntity {
        let response: EventDTO = try await apiClient.request(
            Endpoint(path: "events", method: .post, body: request, requiresAuth: true)
        )
        let event = response.toEntity()
        try await eventRepository.upsertEvent(event)
        return event
    }

    public func updateRSVP(eventId: String, status: RSVPStatus) async throws -> EventRSVPEntity {
        let response: RSVPResponse = try await apiClient.request(
            Endpoint(path: "events/\(eventId)/rsvp", method: .post, body: RSVPRequest(status: status.rawValue), requiresAuth: true)
        )
        let entity = EventRSVPEntity(
            eventId: eventId,
            userId: currentUserId,
            status: RSVPStatus(rawValue: response.status) ?? status,
            createdAt: Date()
        )
        try await rsvpRepository.upsertRSVP(entity)
        return entity
    }

    public func fetchAttendees(eventId: String) async throws -> [EventAttendee] {
        let response: AttendeesResponse = try await apiClient.request(
            Endpoint(path: "events/\(eventId)/attendees", method: .get, requiresAuth: true)
        )
        return response.items.map { $0.toDomain() }
    }

    public func fetchCheckInToken(eventId: String) async throws -> String {
        let response: CheckInTokenResponse = try await apiClient.request(
            Endpoint(path: "events/\(eventId)/check-in/token", method: .post, requiresAuth: true)
        )
        return response.token
    }

    public func validateCheckIn(eventId: String, token: String) async throws -> CheckInResult {
        let response: CheckInValidateResponse = try await apiClient.request(
            Endpoint(path: "events/\(eventId)/check-in/validate", method: .post, body: CheckInValidateRequest(token: token), requiresAuth: true)
        )
        let metadata: [String: String] = ["locationVerified": response.locationVerified ? "true" : "false"]
        let entity = EventCheckinEntity(eventId: eventId, userId: currentUserId, checkedInAt: response.checkedInAt, metadata: metadata)
        try await checkinRepository.upsertCheckin(entity)
        return CheckInResult(checkedInAt: response.checkedInAt, locationVerified: response.locationVerified)
    }
}

@MainActor
public final class EventsViewModel: ObservableObject {
    @Published public private(set) var events: [EventEntity] = []
    @Published public var isLoading = false
    @Published public var errorMessageKey: String?
    @Published public var showCreateEvent = false

    private let service: EventsService
    private let cachePolicy = CachePolicy(mode: .staleWhileRevalidate, maxAge: 120, staleTTL: 600)
    private let dependencies: EventsDependencies

    public init(dependencies: EventsDependencies) {
        self.dependencies = dependencies
        self.service = NetworkEventsService(
            apiClient: dependencies.apiClient,
            eventRepository: dependencies.eventRepository,
            rsvpRepository: dependencies.rsvpRepository,
            checkinRepository: dependencies.checkinRepository,
            currentUserId: dependencies.currentUserId
        )
        Task { await load() }
    }

    public func load() async {
        isLoading = true
        errorMessageKey = nil
        do {
            let cached = try await service.fetchCache()
            if cachePolicy.shouldReadCacheFirst, !cached.isEmpty {
                events = cached
                Task { await refresh() }
                isLoading = false
                return
            }
            let remote = try await service.refreshEvents()
            events = remote
        } catch {
            errorMessageKey = "events_error_generic"
        }
        isLoading = false
    }

    public func refresh() async {
        do {
            let remote = try await service.refreshEvents()
            events = remote
        } catch {
            errorMessageKey = "events_error_generic"
        }
    }

    public func createEvent(request: EventCreateRequest) async {
        do {
            let event = try await service.createEvent(request)
            events.insert(event, at: 0)
        } catch {
            errorMessageKey = "events_error_generic"
        }
    }

    public func detailViewModel(for event: EventEntity) -> EventDetailViewModel {
        EventDetailViewModel(event: event, dependencies: dependencies, service: service)
    }
}

@MainActor
public final class EventDetailViewModel: ObservableObject {
    @Published public private(set) var event: EventEntity
    @Published public private(set) var rsvpStatus: RSVPStatus?
    @Published public private(set) var attendees: [EventAttendee] = []
    @Published public private(set) var isCheckedIn = false
    @Published public var errorMessageKey: String?
    @Published public var checkInToken: String?

    let dependencies: EventsDependencies
    let service: EventsService

    init(event: EventEntity, dependencies: EventsDependencies, service: EventsService) {
        self.event = event
        self.dependencies = dependencies
        self.service = service
        Task { await loadStatus() }
    }

    public var isHost: Bool {
        event.hostId == dependencies.currentUserId
    }

    public func updateRSVP(_ status: RSVPStatus) {
        Task {
            do {
                let rsvp = try await service.updateRSVP(eventId: event.id, status: status)
                rsvpStatus = rsvp.status
                dependencies.analytics.track(AnalyticsEvent(name: "event_rsvp"))
            } catch {
                errorMessageKey = "events_rsvp_error"
            }
        }
    }

    public func loadAttendees() {
        Task {
            do {
                let attendees = try await service.fetchAttendees(eventId: event.id)
                self.attendees = attendees.filter { !$0.isIncognito }
            } catch {
                errorMessageKey = "events_attendees_error"
            }
        }
    }

    public func loadCheckInToken() {
        Task {
            do {
                checkInToken = try await service.fetchCheckInToken(eventId: event.id)
            } catch {
                errorMessageKey = "events_checkin_error"
            }
        }
    }

    public func refreshCheckIn() async {
        if let checkin = try? await dependencies.checkinRepository.fetchCheckin(eventId: event.id, userId: dependencies.currentUserId) {
            isCheckedIn = true
            if !checkin.metadata.isEmpty {
                dependencies.logger.info("Check-in metadata: \(checkin.metadata)")
            }
        }
    }

    private func loadStatus() async {
        if let rsvp = try? await dependencies.rsvpRepository.fetchRSVP(eventId: event.id, userId: dependencies.currentUserId) {
            rsvpStatus = rsvp.status
        }
        if let checkin = try? await dependencies.checkinRepository.fetchCheckin(eventId: event.id, userId: dependencies.currentUserId) {
            isCheckedIn = true
            event.attendeeCount = max(event.attendeeCount, 1)
            if !checkin.metadata.isEmpty {
                dependencies.logger.info("Check-in metadata: \(checkin.metadata)")
            }
        }
    }
}

public struct EventsView: View {
    @StateObject private var viewModel: EventsViewModel

    public init(viewModel: EventsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                header

                if viewModel.isLoading {
                    loadingSkeletons
                } else if let error = viewModel.errorMessageKey {
                    EmptyStateView(
                        titleKey: "events_error_title",
                        messageKey: LocalizedStringKey(error),
                        actionTitleKey: "events_retry",
                        action: { Task { await viewModel.refresh() } }
                    )
                } else if viewModel.events.isEmpty {
                    EmptyStateView(
                        titleKey: "events_empty_title",
                        messageKey: "events_empty_body",
                        actionTitleKey: "events_refresh",
                        action: { Task { await viewModel.refresh() } }
                    )
                } else {
                    ForEach(viewModel.events) { event in
                        NavigationLink {
                            EventDetailView(viewModel: viewModel.detailViewModel(for: event))
                        } label: {
                            EventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(TrustSpacing.lg)
        }
        .navigationTitle(Text("events_title"))
        .sheet(isPresented: $viewModel.showCreateEvent) {
            EventCreateView(onCreate: { request in
                Task { await viewModel.createEvent(request: request) }
                viewModel.showCreateEvent = false
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            HStack {
                Text("events_title")
                    .font(TrustTypography.title)
                Spacer()
                SecondaryButton("events_create") { viewModel.showCreateEvent = true }
                    .frame(maxWidth: 140)
            }
            Text("events_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }

    private var loadingSkeletons: some View {
        VStack(spacing: TrustSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                Card {
                    SkeletonView(height: 140)
                    SkeletonView(height: 16)
                    SkeletonView(height: 16)
                }
            }
        }
    }
}

private struct EventCard: View {
    let event: EventEntity

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: TrustSpacing.sm) {
                Text(event.title)
                    .font(TrustTypography.headline)
                Text(event.areaLabel)
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
                Text(eventStartsText)
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
            }
        }
    }

    private var eventStartsText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: event.startsAt)
    }
}

public struct EventDetailView: View {
    @StateObject private var viewModel: EventDetailViewModel
    @State private var showCheckIn = false

    public init(viewModel: EventDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                Text(viewModel.event.title)
                    .font(TrustTypography.title)
                Text(viewModel.event.description ?? "")
                    .font(TrustTypography.body)
                    .foregroundStyle(TrustColors.textSecondary)

                EventDetailRow(labelKey: "events_area_label", value: viewModel.event.areaLabel)
                if let hint = viewModel.event.venueHint {
                    EventDetailRow(labelKey: "events_venue_hint", value: hint)
                }

                RSVPButtons(current: viewModel.rsvpStatus, onSelect: viewModel.updateRSVP)

                if viewModel.isCheckedIn {
                    AttendeesSection(attendees: viewModel.attendees, onLoad: viewModel.loadAttendees)
                } else {
                    Text(String(format: NSLocalizedString("events_attendee_count", comment: ""), viewModel.event.attendeeCount))
                        .font(TrustTypography.caption)
                        .foregroundStyle(TrustColors.textSecondary)
                    Text("events_attendee_locked")
                        .font(TrustTypography.caption)
                        .foregroundStyle(TrustColors.textSecondary)
                }

                PrimaryButton("events_check_in", action: { showCheckIn = true })
                    .sheet(isPresented: $showCheckIn, onDismiss: {
                        Task { await viewModel.refreshCheckIn() }
                    }) {
                        EventCheckInView(
                            eventId: viewModel.event.id,
                            service: viewModel.service,
                            analytics: viewModel.dependencies.analytics
                        )
                    }

                if viewModel.isHost {
                    HostToolsSection(viewModel: viewModel)
                }

                if let error = viewModel.errorMessageKey {
                    Toast(titleKey: "events_error_title", messageKey: LocalizedStringKey(error), style: .warning)
                }
            }
            .padding(TrustSpacing.lg)
        }
    }
}

private struct EventDetailRow: View {
    let labelKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(labelKey)
                .font(TrustTypography.caption)
                .foregroundStyle(TrustColors.textSecondary)
            Spacer()
            Text(value)
                .font(TrustTypography.body)
        }
    }
}

private struct RSVPButtons: View {
    let current: RSVPStatus?
    let onSelect: (RSVPStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            Text("events_rsvp_title")
                .font(TrustTypography.headline)
            HStack(spacing: TrustSpacing.sm) {
                PrimaryButton("events_rsvp_going") { onSelect(.going) }
                SecondaryButton("events_rsvp_maybe") { onSelect(.maybe) }
                SecondaryButton("events_rsvp_not_going") { onSelect(.declined) }
            }
        }
    }
}

private struct AttendeesSection: View {
    let attendees: [EventAttendee]
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            Text("events_attendees_title")
                .font(TrustTypography.headline)
            if attendees.isEmpty {
                Text("events_attendees_empty")
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
                    .onAppear(perform: onLoad)
            } else {
                ForEach(attendees) { attendee in
                    HStack {
                        Text(attendee.displayName)
                        Spacer()
                        if attendee.isHumanVerified {
                            Badge("discover_badge_human", style: .success)
                        }
                    }
                }
            }
        }
    }
}

private struct HostToolsSection: View {
    @ObservedObject var viewModel: EventDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            Text("events_host_tools")
                .font(TrustTypography.headline)
            PrimaryButton("events_generate_qr") {
                viewModel.loadCheckInToken()
            }
            if let token = viewModel.checkInToken {
                EventQRCodeView(token: token)
            }
        }
    }
}

private struct EventQRCodeView: View {
    let token: String

    var body: some View {
        VStack(spacing: TrustSpacing.sm) {
            Image(uiImage: generateQRCode(from: token))
                .interpolation(.none)
                .resizable()
                .frame(width: 200, height: 200)
            Text("events_qr_note")
                .font(TrustTypography.caption)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }

    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let outputImage = filter.outputImage ?? CIImage()
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) ?? CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: CGDataProvider(data: Data([0, 0, 0, 0]) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return UIImage(cgImage: cgImage)
    }
}

public struct EventCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var areaLabel = ""
    @State private var venueHint = ""
    @State private var capacity = 50
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var endsAt = Date().addingTimeInterval(7200)

    let onCreate: (EventCreateRequest) -> Void

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("events_create_details")) {
                    TextField("events_create_title_field", text: $title)
                    TextField("events_create_description", text: $description)
                }
                Section(header: Text("events_create_location")) {
                    TextField("events_create_area", text: $areaLabel)
                    TextField("events_create_venue_hint", text: $venueHint)
                }
                Section(header: Text("events_create_time")) {
                    DatePicker("events_create_start", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("events_create_end", selection: $endsAt, displayedComponents: [.date, .hourAndMinute])
                }
                Section(header: Text("events_create_capacity")) {
                    Stepper(value: $capacity, in: 5...500) {
                        Text("\(capacity)")
                    }
                }
            }
            .navigationTitle("events_create_title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("events_create_submit") {
                        let request = EventCreateRequest(
                            title: title,
                            description: description,
                            areaLabel: areaLabel,
                            venueHint: venueHint.isEmpty ? nil : venueHint,
                            startsAt: startsAt,
                            endsAt: endsAt,
                            capacity: capacity
                        )
                        onCreate(request)
                        dismiss()
                    }
                    .disabled(title.isEmpty || areaLabel.isEmpty)
                }
            }
        }
    }
}

public struct EventCheckInView: View {
    @StateObject private var viewModel: CheckInViewModel

    public init(eventId: String, service: EventsService, analytics: AnalyticsTracking) {
        _viewModel = StateObject(wrappedValue: CheckInViewModel(eventId: eventId, service: service, analytics: analytics))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.lg) {
            Text("events_checkin_title")
                .font(TrustTypography.title)
            Text("events_checkin_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)

            QRScannerView(onCode: viewModel.handleScan)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            SecondaryButton("events_checkin_torch", action: viewModel.toggleTorch)

            switch viewModel.state {
            case .idle, .scanning:
                Text("events_checkin_prompt")
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
            case .validating:
                LoadingSpinner()
            case .success:
                Toast(titleKey: "events_checkin_success", messageKey: "events_checkin_success_body", style: .success)
            case .failure(let failure):
                Toast(titleKey: "events_checkin_failure", messageKey: viewModel.messageKey(for: failure), style: .danger)
            }
        }
        .padding(TrustSpacing.lg)
    }
}

@MainActor
final class CheckInViewModel: ObservableObject {
    @Published private(set) var state: CheckInState = .idle

    private let eventId: String
    private let service: EventsService
    private let analytics: AnalyticsTracking
    private var machine = CheckInStateMachine()

    init(eventId: String, service: EventsService, analytics: AnalyticsTracking) {
        self.eventId = eventId
        self.service = service
        self.analytics = analytics
        state = machine.handle(.start)
    }

    func handleScan(_ code: String) {
        guard case .scanning = state else { return }
        state = machine.handle(.tokenScanned(code))
        Task {
            do {
                _ = try await service.validateCheckIn(eventId: eventId, token: code)
                analytics.track(AnalyticsEvent(name: "checkin_success"))
                state = machine.handle(.validationSuccess(Date()))
            } catch let error as APIError {
                analytics.track(AnalyticsEvent(name: "checkin_failure"))
                state = machine.handle(.validationFailure(mapError(error)))
            } catch {
                state = machine.handle(.validationFailure(.network))
            }
        }
    }

    func toggleTorch() {
        QRScannerView.toggleTorch()
    }

    func messageKey(for failure: CheckInFailure) -> LocalizedStringKey {
        switch failure {
        case .invalidToken: return "events_checkin_invalid"
        case .expiredToken: return "events_checkin_expired"
        case .wrongEvent: return "events_checkin_wrong_event"
        case .alreadyCheckedIn: return "events_checkin_already"
        case .network: return "events_checkin_network"
        }
    }

    private func mapError(_ error: APIError) -> CheckInFailure {
        switch error {
        case .server(_, let code, _):
            switch code {
            case "EVENT_CHECKIN_INVALID_TOKEN": return .invalidToken
            case "EVENT_CHECKIN_EXPIRED": return .expiredToken
            case "EVENT_CHECKIN_WRONG_EVENT": return .wrongEvent
            case "EVENT_CHECKIN_ALREADY": return .alreadyCheckedIn
            default: return .network
            }
        default:
            return .network
        }
    }
}

public struct EventAttendee: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let isHumanVerified: Bool
    public let isIncognito: Bool
}

public struct CheckInResult: Equatable {
    public let checkedInAt: Date
    public let locationVerified: Bool
}

private struct EventCreateRequest: Encodable {
    let title: String
    let description: String?
    let areaLabel: String
    let venueHint: String?
    let startsAt: Date
    let endsAt: Date
    let capacity: Int
}

private struct RSVPRequest: Encodable {
    let status: String
}

private struct RSVPResponse: Decodable {
    let status: String
}

private struct EventDTO: Decodable {
    let id: String
    let title: String
    let description: String?
    let startsAt: Date
    let endsAt: Date
    let areaLabel: String
    let venueHint: String?
    let hostId: String
    let capacity: Int
    let attendeeCount: Int?
    let createdAt: Date

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
            attendeeCount: attendeeCount ?? 0,
            createdAt: createdAt
        )
    }
}

private struct EventsListResponse: Decodable {
    let items: [EventDTO]
}

private struct AttendeeDTO: Decodable {
    let id: String
    let displayName: String
    let isHumanVerified: Bool
    let isIncognito: Bool

    func toDomain() -> EventAttendee {
        EventAttendee(id: id, displayName: displayName, isHumanVerified: isHumanVerified, isIncognito: isIncognito)
    }
}

private struct AttendeesResponse: Decodable {
    let items: [AttendeeDTO]
}

private struct CheckInTokenResponse: Decodable {
    let token: String
}

private struct CheckInValidateRequest: Encodable {
    let token: String
}

private struct CheckInValidateResponse: Decodable {
    let checkedInAt: Date
    let locationVerified: Bool
}
