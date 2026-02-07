import SwiftUI

public enum TrustColors {
    public static let background = Color(.systemBackground)
    public static let primary = Color(.systemIndigo)
    public static let secondary = Color(.systemTeal)
    public static let accent = Color(.systemOrange)
    public static let textPrimary = Color(.label)
    public static let textSecondary = Color(.secondaryLabel)
}

public enum TrustTypography {
    public static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    public static let headline = Font.system(size: 20, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    public static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
}

public enum TrustSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum TrustIcon: String {
    case shield = "shield.lefthalf.filled"
    case chat = "message.fill"
    case heart = "heart.fill"
    case events = "calendar"
    case settings = "gearshape.fill"
}

public struct TrustIconView: View {
    private let icon: TrustIcon
    private let size: CGFloat

    public init(_ icon: TrustIcon, size: CGFloat = 20) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        Image(systemName: icon.rawValue)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(TrustColors.primary)
            .accessibilityHidden(true)
    }
}

public struct PrimaryButton: View {
    private let titleKey: LocalizedStringKey
    private let action: () -> Void

    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(TrustTypography.headline)
                .foregroundStyle(Color.white)
                .padding(.vertical, TrustSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(TrustColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel(Text(titleKey))
    }
}

public struct FeatureCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            content
        }
        .padding(TrustSpacing.md)
        .background(TrustColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
