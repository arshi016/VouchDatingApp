import Foundation
import CryptoKit
import FoundationKit
import Networking

public enum VerificationStatus: String, Codable {
    case unverified
    case verified
}

public protocol VerificationService {
    func fetchStatus() async -> VerificationStatus
    func fetchLastVerifiedAt() async -> Date?
    func saveTemplate(_ data: Data) async throws
    func deleteTemplate() async
    func markVerified() async throws
    func hasTemplate() async -> Bool
}

public final class NetworkVerificationService: VerificationService {
    private let apiClient: APIClient
    private let store: BiometricTemplateStore
    private let secureStore: SecureStoring
    private let logger: Logger

    public init(apiClient: APIClient, secureStore: SecureStoring, logger: Logger) {
        self.apiClient = apiClient
        self.secureStore = secureStore
        self.logger = logger
        self.store = BiometricTemplateStore(secureStore: secureStore)
    }

    public func fetchStatus() async -> VerificationStatus {
        if let stored = SecureTokenStore.readString(from: secureStore, key: VerificationStorageKeys.status),
           let status = VerificationStatus(rawValue: stored) {
            return status
        }
        return .unverified
    }

    public func fetchLastVerifiedAt() async -> Date? {
        guard let stored = SecureTokenStore.readString(from: secureStore, key: VerificationStorageKeys.lastVerifiedAt) else {
            return nil
        }
        return ISO8601DateFormatter().date(from: stored)
    }

    public func saveTemplate(_ data: Data) async throws {
        try store.saveTemplate(data)
    }

    public func deleteTemplate() async {
        store.deleteTemplate()
        try? SecureTokenStore.saveString(VerificationStatus.unverified.rawValue, in: secureStore, key: VerificationStorageKeys.status)
        let endpoint = Endpoint<EmptyResponse>(path: "verification/template", method: .delete, requiresAuth: true)
        _ = try? await apiClient.request(endpoint)
    }

    public func markVerified() async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try SecureTokenStore.saveString(VerificationStatus.verified.rawValue, in: secureStore, key: VerificationStorageKeys.status)
        try SecureTokenStore.saveString(now, in: secureStore, key: VerificationStorageKeys.lastVerifiedAt)
        let request = VerificationCompleteRequest(status: VerificationStatus.verified.rawValue)
        let endpoint = Endpoint<EmptyResponse>(path: "verification/complete", method: .post, body: request, requiresAuth: true)
        _ = try await apiClient.request(endpoint)
    }

    public func hasTemplate() async -> Bool {
        store.loadTemplate() != nil
    }
}

public final class MockVerificationService: VerificationService {
    private var status: VerificationStatus = .unverified
    private var hasStoredTemplate = false
    private var lastVerifiedAt: Date?

    public init() {}

    public func fetchStatus() async -> VerificationStatus {
        status
    }

    public func fetchLastVerifiedAt() async -> Date? {
        lastVerifiedAt
    }

    public func saveTemplate(_ data: Data) async throws {
        hasStoredTemplate = true
    }

    public func deleteTemplate() async {
        hasStoredTemplate = false
        status = .unverified
    }

    public func markVerified() async throws {
        status = .verified
        lastVerifiedAt = Date()
    }

    public func hasTemplate() async -> Bool {
        hasStoredTemplate
    }
}

private enum VerificationStorageKeys {
    static let status = "verification_status"
    static let template = "biometric_template"
    static let templateKey = "biometric_template_key"
    static let lastVerifiedAt = "verification_last_verified_at"
}

private struct VerificationCompleteRequest: Encodable {
    let status: String
}

final class BiometricTemplateStore {
    private let secureStore: SecureStoring

    init(secureStore: SecureStoring) {
        self.secureStore = secureStore
    }

    func saveTemplate(_ data: Data) throws {
        let key = try fetchOrCreateKey()
        let sealed = try ChaChaPoly.seal(data, using: key)
        try secureStore.set(sealed.combined, for: VerificationStorageKeys.template)
    }

    func loadTemplate() -> Data? {
        guard let combined = try? secureStore.getData(for: VerificationStorageKeys.template) else { return nil }
        guard let keyData = try? secureStore.getData(for: VerificationStorageKeys.templateKey) else { return nil }
        let key = SymmetricKey(data: keyData)
        guard let box = try? ChaChaPoly.SealedBox(combined: combined) else { return nil }
        return try? ChaChaPoly.open(box, using: key)
    }

    func deleteTemplate() {
        try? secureStore.deleteData(for: VerificationStorageKeys.template)
        try? secureStore.deleteData(for: VerificationStorageKeys.templateKey)
    }

    private func fetchOrCreateKey() throws -> SymmetricKey {
        if let keyData = try? secureStore.getData(for: VerificationStorageKeys.templateKey) {
            return SymmetricKey(data: keyData)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try secureStore.set(keyData, for: VerificationStorageKeys.templateKey)
        return key
    }
}

private enum SecureTokenStore {
    static func saveString(_ value: String, in store: SecureStoring, key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try store.set(data, for: key)
    }

    static func readString(from store: SecureStoring, key: String) -> String? {
        guard let data = try? store.getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
