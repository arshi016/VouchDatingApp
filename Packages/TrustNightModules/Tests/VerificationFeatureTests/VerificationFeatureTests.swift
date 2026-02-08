import XCTest
@testable import VerificationFeature
import FoundationKit
import Networking

final class VerificationFeatureTests: XCTestCase {
    func testTemplateStorageAndDelete() async throws {
        let secureStore = InMemorySecureStore()
        let apiClient = MockAPIClient()
        apiClient.registerData(path: "verification/template", method: .delete, data: Data())
        let service = NetworkVerificationService(apiClient: apiClient, secureStore: secureStore, logger: TestLogger())

        try await service.saveTemplate(Data("template".utf8))
        XCTAssertTrue(secureStore.hasKey("biometric_template"))

        await service.deleteTemplate()
        XCTAssertFalse(secureStore.hasKey("biometric_template"))
    }

    func testMarkVerifiedStoresStatus() async throws {
        let secureStore = InMemorySecureStore()
        let apiClient = MockAPIClient()
        apiClient.registerData(path: "verification/complete", method: .post, data: Data())
        let service = NetworkVerificationService(apiClient: apiClient, secureStore: secureStore, logger: TestLogger())

        try await service.markVerified()
        XCTAssertEqual(secureStore.string(for: "verification_status"), "verified")
    }
}

private final class InMemorySecureStore: SecureStoring {
    private var storage: [String: Data] = [:]

    func set(_ data: Data, for key: String) throws {
        storage[key] = data
    }

    func getData(for key: String) throws -> Data? {
        storage[key]
    }

    func deleteData(for key: String) throws {
        storage[key] = nil
    }

    func hasKey(_ key: String) -> Bool {
        storage[key] != nil
    }

    func string(for key: String) -> String? {
        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct TestLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
