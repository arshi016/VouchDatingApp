import SwiftUI
import DesignSystem
import FoundationKit

public struct SettingsDependencies {
    public let featureFlags: FeatureFlagging
    public let secureStore: SecureStoring
    public let analytics: AnalyticsTracking

    public init(featureFlags: FeatureFlagging, secureStore: SecureStoring, analytics: AnalyticsTracking) {
        self.featureFlags = featureFlags
        self.secureStore = secureStore
        self.analytics = analytics
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var isExperimentalEnabled: Bool = false
    private let dependencies: SettingsDependencies

    public init(dependencies: SettingsDependencies) {
        self.dependencies = dependencies
        isExperimentalEnabled = dependencies.featureFlags.isEnabled(FeatureFlagKey("experimental"))
    }

    public func clearSecureData() {
        try? dependencies.secureStore.deleteData(for: "auth_token")
        try? dependencies.secureStore.deleteData(for: "face_template")
        dependencies.analytics.track(AnalyticsEvent(name: "settings_clear_secure_store"))
    }
}

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.lg) {
            Text("settings_title")
                .font(TrustTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text("settings_subtitle")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("settings_clear_secure", action: viewModel.clearSecureData)
        }
        .padding(TrustSpacing.lg)
    }
}
