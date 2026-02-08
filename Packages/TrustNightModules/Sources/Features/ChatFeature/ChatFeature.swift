import SwiftUI
import DesignSystem
import FoundationKit
import Networking

public struct ChatDependencies {
    public let apiClient: APIClient
    public let analytics: AnalyticsTracking

    public init(apiClient: APIClient, analytics: AnalyticsTracking) {
        self.apiClient = apiClient
        self.analytics = analytics
    }
}

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var lastMessageKey = "chat_empty"
    private let dependencies: ChatDependencies

    public init(dependencies: ChatDependencies) {
        self.dependencies = dependencies
    }

    public func sendMockMessage() {
        dependencies.analytics.track(AnalyticsEvent(name: "chat_message_sent"))
        lastMessageKey = "chat_sent"
    }
}

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    public init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            Text("chat_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(viewModel.lastMessageKey))
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("chat_send", action: viewModel.sendMockMessage)
        }
        .padding(TrustSpacing.lg)
    }
}
