import Foundation

public enum LogLevel: String {
    case debug
    case info
    case warn
    case error
}

public protocol Logger {
    func log(_ message: String, level: LogLevel)
}

public extension Logger {
    func debug(_ message: String) { log(message, level: .debug) }
    func info(_ message: String) { log(message, level: .info) }
    func warn(_ message: String) { log(message, level: .warn) }
    func error(_ message: String) { log(message, level: .error) }
}

public final class ConsoleLogger: Logger {
    public init() {}

    public func log(_ message: String, level: LogLevel) {
        print("[\(level.rawValue.uppercased())] \(message)")
    }
}

public struct FeatureFlagKey: Hashable, Codable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public protocol FeatureFlagging {
    func isEnabled(_ key: FeatureFlagKey) -> Bool
}

public final class InMemoryFeatureFlags: FeatureFlagging {
    private var flags: [FeatureFlagKey: Bool]

    public init(initialFlags: [FeatureFlagKey: Bool] = [:]) {
        self.flags = initialFlags
    }

    public func isEnabled(_ key: FeatureFlagKey) -> Bool {
        flags[key] ?? false
    }

    public func set(_ key: FeatureFlagKey, enabled: Bool) {
        flags[key] = enabled
    }
}

public struct AnalyticsEvent: Hashable, Codable {
    public let name: String
    public let properties: [String: String]

    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

public protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

public final class NoopAnalytics: AnalyticsTracking {
    public init() {}
    public func track(_ event: AnalyticsEvent) {}
}

public enum SecureStoreError: Error {
    case unexpectedStatus(Int)
    case encodingFailed
    case decodingFailed
}

public protocol SecureStoring {
    func set(_ data: Data, for key: String) throws
    func getData(for key: String) throws -> Data?
    func deleteData(for key: String) throws
}

#if canImport(Security)
import Security

public final class KeychainSecureStore: SecureStoring {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func set(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureStoreError.unexpectedStatus(Int(status)) }
    }

    public func getData(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw SecureStoreError.unexpectedStatus(Int(status)) }
        return result as? Data
    }

    public func deleteData(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.unexpectedStatus(Int(status))
        }
    }
}
#else
public final class KeychainSecureStore: SecureStoring {
    public init(service: String) {}
    public func set(_ data: Data, for key: String) throws {}
    public func getData(for key: String) throws -> Data? { nil }
    public func deleteData(for key: String) throws {}
}
#endif
