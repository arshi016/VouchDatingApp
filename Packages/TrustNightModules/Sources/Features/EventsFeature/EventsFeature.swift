import SwiftUI
import Foundation
import DesignSystem
import FoundationKit
import Networking

public struct EventsDependencies {
    public let apiClient: APIClient
    public let analytics: AnalyticsTracking
    public let logger: Logger

    public init(apiClient: APIClient, analytics: AnalyticsTracking, logger: Logger) {
        self.apiClient = apiClient
        self.analytics = analytics
        self.logger = logger
    }
}

public struct EventListItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let region: String
}

@MainActor
public final class EventsViewModel: ObservableObject {
    @Published public private(set) var events: [EventListItem] = []
    private let dependencies: EventsDependencies

    public init(dependencies: EventsDependencies) {
        self.dependencies = dependencies
        loadMockEvents()
    }

    private func loadMockEvents() {
        events = [
            EventListItem(title: "Encrypted Meetup", region: "Berlin"),
            EventListItem(title: "Zero Trust Social", region: "Munich")
        ]
    }
}

public struct EventsView: View {
    @StateObject private var viewModel: EventsViewModel

    public init(viewModel: EventsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List(viewModel.events) { event in
            VStack(alignment: .leading, spacing: TrustSpacing.xs) {
                Text(event.title)
                    .font(TrustTypography.headline)
                Text(event.region)
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
                    .accessibilityLabel(Text(regionAccessibilityLabel(for: event.region)))
            }
            .padding(.vertical, TrustSpacing.xs)
        }
        .navigationTitle(Text("events_title"))
    }

    private func regionAccessibilityLabel(for region: String) -> String {
        String(format: NSLocalizedString("region_label", comment: ""), region)
    }
}
