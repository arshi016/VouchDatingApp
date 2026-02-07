import SwiftUI
import UIKit

public enum TrustColors {
    public static let background = Color(dynamicLight: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1),
                                         dark: UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1))
    public static let surface = Color(dynamicLight: .white,
                                      dark: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1))
    public static let textPrimary = Color(dynamicLight: UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1),
                                          dark: UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1))
    public static let textSecondary = Color(dynamicLight: UIColor(red: 0.32, green: 0.36, blue: 0.42, alpha: 1),
                                            dark: UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1))
    public static let accent = Color(dynamicLight: UIColor(red: 0.31, green: 0.36, blue: 0.92, alpha: 1),
                                     dark: UIColor(red: 0.49, green: 0.54, blue: 1.0, alpha: 1))
    public static let success = Color(dynamicLight: UIColor(red: 0.10, green: 0.64, blue: 0.37, alpha: 1),
                                      dark: UIColor(red: 0.20, green: 0.78, blue: 0.47, alpha: 1))
    public static let warning = Color(dynamicLight: UIColor(red: 0.91, green: 0.59, blue: 0.12, alpha: 1),
                                      dark: UIColor(red: 0.96, green: 0.73, blue: 0.24, alpha: 1))
    public static let danger = Color(dynamicLight: UIColor(red: 0.87, green: 0.22, blue: 0.26, alpha: 1),
                                     dark: UIColor(red: 0.97, green: 0.35, blue: 0.35, alpha: 1))

    public static let primary = accent
    public static let secondary = surface
}

public enum TrustTypography {
    public static let title = Font.system(.title, design: .rounded).weight(.bold)
    public static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    public static let body = Font.system(.body, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded)
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
    case verified = "checkmark.seal.fill"
    case chat = "message.fill"
    case heart = "heart.fill"
    case events = "calendar"
    case settings = "gearshape.fill"
    case warning = "exclamationmark.triangle.fill"
    case info = "info.circle.fill"
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
            .foregroundStyle(TrustColors.accent)
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
        }
        .buttonStyle(TrustButtonStyle(style: .primary))
        .accessibilityLabel(Text(titleKey))
    }
}

public struct SecondaryButton: View {
    private let titleKey: LocalizedStringKey
    private let action: () -> Void

    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(titleKey)
        }
        .buttonStyle(TrustButtonStyle(style: .secondary))
        .accessibilityLabel(Text(titleKey))
    }
}

public struct DestructiveButton: View {
    private let titleKey: LocalizedStringKey
    private let action: () -> Void

    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(titleKey)
        }
        .buttonStyle(TrustButtonStyle(style: .destructive))
        .accessibilityLabel(Text(titleKey))
    }
}

public struct TrustDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(TrustColors.surface.opacity(0.8))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

public struct Card<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.sm) {
            content
        }
        .padding(TrustSpacing.md)
        .background(TrustColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

public typealias FeatureCard<Content: View> = Card<Content>

public enum BadgeStyle {
    case neutral
    case accent
    case success
    case warning
    case danger
}

public struct Badge: View {
    private let titleKey: LocalizedStringKey
    private let style: BadgeStyle

    public init(_ titleKey: LocalizedStringKey, style: BadgeStyle = .neutral) {
        self.titleKey = titleKey
        self.style = style
    }

    public var body: some View {
        Text(titleKey)
            .font(TrustTypography.caption.weight(.semibold))
            .padding(.horizontal, TrustSpacing.sm)
            .padding(.vertical, TrustSpacing.xs)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule(style: .continuous))
            .accessibilityLabel(Text(titleKey))
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral:
            return TrustColors.surface
        case .accent:
            return TrustColors.accent.opacity(0.15)
        case .success:
            return TrustColors.success.opacity(0.15)
        case .warning:
            return TrustColors.warning.opacity(0.15)
        case .danger:
            return TrustColors.danger.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral:
            return TrustColors.textSecondary
        case .accent:
            return TrustColors.accent
        case .success:
            return TrustColors.success
        case .warning:
            return TrustColors.warning
        case .danger:
            return TrustColors.danger
        }
    }
}

public enum ToastStyle {
    case info
    case success
    case warning
    case danger
}

public struct Toast: View {
    private let titleKey: LocalizedStringKey
    private let messageKey: LocalizedStringKey
    private let style: ToastStyle

    public init(titleKey: LocalizedStringKey, messageKey: LocalizedStringKey, style: ToastStyle = .info) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.style = style
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TrustSpacing.sm) {
            TrustIconView(icon, size: 18)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: TrustSpacing.xs) {
                Text(titleKey)
                    .font(TrustTypography.headline)
                    .foregroundStyle(TrustColors.textPrimary)
                Text(messageKey)
                    .font(TrustTypography.caption)
                    .foregroundStyle(TrustColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(TrustSpacing.md)
        .background(TrustColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch style {
        case .info: return TrustColors.accent
        case .success: return TrustColors.success
        case .warning: return TrustColors.warning
        case .danger: return TrustColors.danger
        }
    }

    private var icon: TrustIcon {
        switch style {
        case .info: return .info
        case .success: return .verified
        case .warning: return .warning
        case .danger: return .warning
        }
    }
}

public struct AvatarView: View {
    public enum Source {
        case image(Image)
        case initials(String)
    }

    private let source: Source
    private let size: CGFloat
    private let isVerified: Bool

    public init(source: Source, size: CGFloat = 64, isVerified: Bool = false) {
        self.source = source
        self.size = size
        self.isVerified = isVerified
    }

    public var body: some View {
        ZStack {
            switch source {
            case .image(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .initials(let text):
                Circle()
                    .fill(TrustColors.surface)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(text)
                            .font(TrustTypography.headline)
                            .foregroundStyle(TrustColors.textPrimary)
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isVerified {
                VerifiedBadge()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isVerified ? "Verified profile avatar" : "Profile avatar"))
    }
}

public struct VerifiedBadge: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .fill(TrustColors.accent)
                .frame(width: 20, height: 20)
            Image(systemName: TrustIcon.verified.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)
                .accessibilityHidden(true)
        }
        .overlay(
            Circle()
                .stroke(TrustColors.surface, lineWidth: 2)
        )
        .accessibilityLabel(Text("Verified"))
    }
}

public struct SkeletonView: View {
    private let height: CGFloat
    private let cornerRadius: CGFloat

    public init(height: CGFloat = 16, cornerRadius: CGFloat = 8) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(TrustColors.surface.opacity(0.6))
            .overlay(ShimmerView().clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

public struct LoadingSpinner: View {
    public init() {}

    public var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: TrustColors.accent))
            .accessibilityLabel(Text("Loading"))
    }
}

public struct EmptyStateView: View {
    private let titleKey: LocalizedStringKey
    private let messageKey: LocalizedStringKey
    private let actionTitleKey: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        titleKey: LocalizedStringKey,
        messageKey: LocalizedStringKey,
        actionTitleKey: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.actionTitleKey = actionTitleKey
        self.action = action
    }

    public var body: some View {
        VStack(spacing: TrustSpacing.md) {
            TrustIconView(.shield, size: 40)
            Text(titleKey)
                .font(TrustTypography.headline)
                .foregroundStyle(TrustColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(messageKey)
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitleKey, let action {
                PrimaryButton(actionTitleKey, action: action)
            }
        }
        .padding(TrustSpacing.lg)
        .accessibilityElement(children: .contain)
    }
}

public struct TrustTextField: View {
    private let titleKey: LocalizedStringKey
    private let placeholderKey: LocalizedStringKey
    @Binding private var text: String

    public init(_ titleKey: LocalizedStringKey, placeholderKey: LocalizedStringKey, text: Binding<String>) {
        self.titleKey = titleKey
        self.placeholderKey = placeholderKey
        _text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.xs) {
            Text(titleKey)
                .font(TrustTypography.caption.weight(.semibold))
                .foregroundStyle(TrustColors.textSecondary)
            TextField(placeholderKey, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(TrustSpacing.sm)
                .background(TrustColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TrustColors.surface.opacity(0.6), lineWidth: 1)
                )
                .accessibilityLabel(Text(titleKey))
        }
    }
}

public struct TrustSecureField: View {
    private let titleKey: LocalizedStringKey
    private let placeholderKey: LocalizedStringKey
    @Binding private var text: String

    public init(_ titleKey: LocalizedStringKey, placeholderKey: LocalizedStringKey, text: Binding<String>) {
        self.titleKey = titleKey
        self.placeholderKey = placeholderKey
        _text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.xs) {
            Text(titleKey)
                .font(TrustTypography.caption.weight(.semibold))
                .foregroundStyle(TrustColors.textSecondary)
            SecureField(placeholderKey, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(TrustSpacing.sm)
                .background(TrustColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TrustColors.surface.opacity(0.6), lineWidth: 1)
                )
                .accessibilityLabel(Text(titleKey))
        }
    }
}

public struct TrustMultilineText: View {
    private let titleKey: LocalizedStringKey
    private let placeholderKey: LocalizedStringKey
    @Binding private var text: String
    private let minHeight: CGFloat

    public init(
        _ titleKey: LocalizedStringKey,
        placeholderKey: LocalizedStringKey,
        text: Binding<String>,
        minHeight: CGFloat = 120
    ) {
        self.titleKey = titleKey
        self.placeholderKey = placeholderKey
        _text = text
        self.minHeight = minHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.xs) {
            Text(titleKey)
                .font(TrustTypography.caption.weight(.semibold))
                .foregroundStyle(TrustColors.textSecondary)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .padding(TrustSpacing.sm)
                    .frame(minHeight: minHeight)
                    .background(TrustColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(TrustColors.surface.opacity(0.6), lineWidth: 1)
                    )

                if text.isEmpty {
                    Text(placeholderKey)
                        .font(TrustTypography.body)
                        .foregroundStyle(TrustColors.textSecondary.opacity(0.7))
                        .padding(.horizontal, TrustSpacing.md)
                        .padding(.vertical, TrustSpacing.sm + 2)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(Text(titleKey))
        }
    }
}

public struct ToggleRow: View {
    private let titleKey: LocalizedStringKey
    private let subtitleKey: LocalizedStringKey?
    @Binding private var isOn: Bool

    public init(_ titleKey: LocalizedStringKey, subtitleKey: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: TrustSpacing.xs) {
                Text(titleKey)
                    .font(TrustTypography.body)
                    .foregroundStyle(TrustColors.textPrimary)
                if let subtitleKey {
                    Text(subtitleKey)
                        .font(TrustTypography.caption)
                        .foregroundStyle(TrustColors.textSecondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: TrustColors.accent))
        .accessibilityLabel(Text(titleKey))
    }
}

public struct PickerRow<Option: Hashable>: View {
    private let titleKey: LocalizedStringKey
    private let options: [Option]
    private let optionTitle: (Option) -> String
    @Binding private var selection: Option

    public init(
        _ titleKey: LocalizedStringKey,
        options: [Option],
        selection: Binding<Option>,
        optionTitle: @escaping (Option) -> String
    ) {
        self.titleKey = titleKey
        self.options = options
        _selection = selection
        self.optionTitle = optionTitle
    }

    public var body: some View {
        HStack {
            Text(titleKey)
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textPrimary)
            Spacer(minLength: TrustSpacing.sm)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(optionTitle(option))
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(Text(titleKey))
        }
        .padding(.vertical, TrustSpacing.xs)
    }
}

private struct ShimmerView: View {
    @State private var offset: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.4),
                    Color.white.opacity(0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geometry.size.width * 1.5, height: geometry.size.height * 1.5)
            .rotationEffect(.degrees(20))
            .offset(x: geometry.size.width * offset)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    offset = 1
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private enum TrustButtonKind {
    case primary
    case secondary
    case destructive
}

private struct TrustButtonStyle: ButtonStyle {
    let style: TrustButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TrustTypography.headline)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, TrustSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(backgroundColor(configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return TrustColors.textPrimary
        case .destructive:
            return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return TrustColors.surface.opacity(0.4)
        default:
            return .clear
        }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return TrustColors.accent
        case .secondary:
            return TrustColors.surface
        case .destructive:
            return TrustColors.danger
        }
    }
}

private extension Color {
    init(dynamicLight light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

#if DEBUG
struct DesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewGallery()
                .preferredColorScheme(.light)
            PreviewGallery()
                .preferredColorScheme(.dark)
        }
    }
}

private struct PreviewGallery: View {
    @State private var email = ""
    @State private var password = ""
    @State private var bio = ""
    @State private var isEnabled = true
    @State private var selectedRegion = "Berlin"

    private let regions = ["Berlin", "Hamburg", "Munich"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                Group {
                    Text("Typography")
                        .font(TrustTypography.headline)
                    Text("Title Style").font(TrustTypography.title)
                    Text("Headline Style").font(TrustTypography.headline)
                    Text("Body Style").font(TrustTypography.body)
                    Text("Caption Style").font(TrustTypography.caption)
                }

                Group {
                    Text("Buttons").font(TrustTypography.headline)
                    PrimaryButton("Primary Action") {}
                    SecondaryButton("Secondary Action") {}
                    DestructiveButton("Delete") {}
                }

                Group {
                    Text("Card & Badge").font(TrustTypography.headline)
                    Card {
                        Text("Card Title").font(TrustTypography.headline)
                        Text("Card supporting text goes here.")
                            .font(TrustTypography.body)
                            .foregroundStyle(TrustColors.textSecondary)
                    }
                    HStack {
                        Badge("Neutral")
                        Badge("Accent", style: .accent)
                        Badge("Success", style: .success)
                        Badge("Warning", style: .warning)
                        Badge("Danger", style: .danger)
                    }
                }

                Group {
                    Text("Divider & Toast").font(TrustTypography.headline)
                    TrustDivider()
                    Toast(titleKey: "Network", messageKey: "You are back online.", style: .success)
                }

                Group {
                    Text("Avatar").font(TrustTypography.headline)
                    HStack(spacing: TrustSpacing.md) {
                        AvatarView(source: .initials("TN"), isVerified: true)
                        AvatarView(source: .initials("CS"), isVerified: false)
                    }
                }

                Group {
                    Text("Loading").font(TrustTypography.headline)
                    SkeletonView(height: 18)
                    SkeletonView(height: 18)
                    LoadingSpinner()
                }

                Group {
                    Text("Empty State").font(TrustTypography.headline)
                    EmptyStateView(
                        titleKey: "No Matches Yet",
                        messageKey: "Check back later or update your preferences.",
                        actionTitleKey: "Explore Events",
                        action: {}
                    )
                }

                Group {
                    Text("Forms").font(TrustTypography.headline)
                    TrustTextField("Email", placeholderKey: "you@trustnight.com", text: $email)
                    TrustSecureField("Password", placeholderKey: "•••••••", text: $password)
                    TrustMultilineText("Bio", placeholderKey: "Tell us about your mission.", text: $bio)
                    ToggleRow("Enable stealth mode", subtitleKey: "Hide exact activity times.", isOn: $isEnabled)
                    PickerRow("Region", options: regions, selection: $selectedRegion, optionTitle: { $0 })
                }
            }
            .padding(TrustSpacing.lg)
            .background(TrustColors.background)
        }
        .previewDisplayName("DesignSystem")
    }
}
#endif
