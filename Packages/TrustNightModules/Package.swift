// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrustNightModules",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AppShell", targets: ["AppShell"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FoundationKit", targets: ["FoundationKit"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "AuthFeature", targets: ["AuthFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "VerificationFeature", targets: ["VerificationFeature"]),
        .library(name: "DiscoverFeature", targets: ["DiscoverFeature"]),
        .library(name: "EventsFeature", targets: ["EventsFeature"]),
        .library(name: "VouchFeature", targets: ["VouchFeature"]),
        .library(name: "TrustProfileFeature", targets: ["TrustProfileFeature"]),
        .library(name: "InvitesFeature", targets: ["InvitesFeature"]),
        .library(name: "ChatFeature", targets: ["ChatFeature"]),
        .library(name: "SafetyFeature", targets: ["SafetyFeature"]),
        .library(name: "ModerationFeature", targets: ["ModerationFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.9.0")
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Sources/DesignSystem"
        ),
        .target(
            name: "FoundationKit",
            dependencies: [],
            path: "Sources/FoundationKit"
        ),
        .target(
            name: "Domain",
            dependencies: [],
            path: "Sources/Domain"
        ),
        .target(
            name: "Networking",
            dependencies: ["FoundationKit"],
            path: "Sources/Networking"
        ),
        .target(
            name: "Persistence",
            dependencies: [
                "FoundationKit",
                "Domain",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/Persistence"
        ),
        .target(
            name: "AuthFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Networking"],
            path: "Sources/Features/AuthFeature"
        ),
        .target(
            name: "OnboardingFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Persistence", "Domain"],
            path: "Sources/Features/OnboardingFeature"
        ),
        .target(
            name: "VerificationFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Domain", "Networking"],
            path: "Sources/Features/VerificationFeature"
        ),
        .target(
            name: "DiscoverFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Networking", "Persistence", "Domain"],
            path: "Sources/Features/DiscoverFeature"
        ),
        .target(
            name: "EventsFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Networking", "Persistence", "Domain"],
            path: "Sources/Features/EventsFeature"
        ),
        .target(
            name: "VouchFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Domain"],
            path: "Sources/Features/VouchFeature"
        ),
        .target(
            name: "TrustProfileFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Persistence", "Domain"],
            path: "Sources/Features/TrustProfileFeature"
        ),
        .target(
            name: "InvitesFeature",
            dependencies: ["DesignSystem", "FoundationKit"],
            path: "Sources/Features/InvitesFeature"
        ),
        .target(
            name: "ChatFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Networking"],
            path: "Sources/Features/ChatFeature"
        ),
        .target(
            name: "SafetyFeature",
            dependencies: ["DesignSystem", "FoundationKit"],
            path: "Sources/Features/SafetyFeature"
        ),
        .target(
            name: "ModerationFeature",
            dependencies: ["DesignSystem", "FoundationKit", "Networking"],
            path: "Sources/Features/ModerationFeature"
        ),
        .target(
            name: "SettingsFeature",
            dependencies: ["DesignSystem", "FoundationKit"],
            path: "Sources/Features/SettingsFeature"
        ),
        .target(
            name: "AppShell",
            dependencies: [
                "DesignSystem",
                "FoundationKit",
                "Networking",
                "Persistence",
                "Domain",
                "AuthFeature",
                "OnboardingFeature",
                "VerificationFeature",
                "DiscoverFeature",
                "EventsFeature",
                "VouchFeature",
                "TrustProfileFeature",
                "InvitesFeature",
                "ChatFeature",
                "SafetyFeature",
                "ModerationFeature",
                "SettingsFeature"
            ],
            path: "Sources/AppShell"
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"],
            path: "Tests/DesignSystemTests"
        ),
        .testTarget(
            name: "FoundationKitTests",
            dependencies: ["FoundationKit"],
            path: "Tests/FoundationKitTests"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"],
            path: "Tests/NetworkingTests",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence"],
            path: "Tests/PersistenceTests"
        ),
        .testTarget(
            name: "AuthFeatureTests",
            dependencies: ["AuthFeature"],
            path: "Tests/AuthFeatureTests"
        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: ["OnboardingFeature", "Persistence", "Domain"],
            path: "Tests/OnboardingFeatureTests"
        ),
        .testTarget(
            name: "VerificationFeatureTests",
            dependencies: ["VerificationFeature", "Networking"],
            path: "Tests/VerificationFeatureTests"
        ),
        .testTarget(
            name: "DiscoverFeatureTests",
            dependencies: ["DiscoverFeature", "Domain", "Persistence", "Networking"],
            path: "Tests/DiscoverFeatureTests"
        ),
        .testTarget(
            name: "EventsFeatureTests",
            dependencies: ["EventsFeature", "Persistence", "Networking"],
            path: "Tests/EventsFeatureTests"
        ),
        .testTarget(
            name: "VouchFeatureTests",
            dependencies: ["VouchFeature"],
            path: "Tests/VouchFeatureTests"
        ),
        .testTarget(
            name: "TrustProfileFeatureTests",
            dependencies: ["TrustProfileFeature"],
            path: "Tests/TrustProfileFeatureTests"
        ),
        .testTarget(
            name: "InvitesFeatureTests",
            dependencies: ["InvitesFeature"],
            path: "Tests/InvitesFeatureTests"
        ),
        .testTarget(
            name: "ChatFeatureTests",
            dependencies: ["ChatFeature"],
            path: "Tests/ChatFeatureTests"
        ),
        .testTarget(
            name: "SafetyFeatureTests",
            dependencies: ["SafetyFeature"],
            path: "Tests/SafetyFeatureTests"
        ),
        .testTarget(
            name: "ModerationFeatureTests",
            dependencies: ["ModerationFeature"],
            path: "Tests/ModerationFeatureTests"
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: ["SettingsFeature"],
            path: "Tests/SettingsFeatureTests"
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Tests/AppShellTests"
        )
    ]
)
