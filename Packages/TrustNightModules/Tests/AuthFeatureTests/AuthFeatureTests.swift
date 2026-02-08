import XCTest
@testable import AuthFeature
import FoundationKit
import Networking

final class AuthFeatureTests: XCTestCase {
    func testTokenStorageOnSignIn() async throws {
        let secureStore = InMemorySecureStore()
        let apiClient = MockAPIClient()
        apiClient.registerData(path: "auth/apple", method: .post, data: authResponseData(isNewUser: true))

        let service = NetworkAuthService(apiClient: apiClient, secureStore: secureStore, logger: TestLogger())
        let session = try await service.signInWithApple(identityToken: "id", authorizationCode: "code", nonce: nil)

        XCTAssertEqual(session.accessToken, "access_123")
        XCTAssertEqual(secureStore.string(for: "auth_access_token"), "access_123")
        XCTAssertEqual(secureStore.string(for: "auth_refresh_token"), "refresh_123")
    }

    func testLogoutClearsTokens() async {
        let secureStore = InMemorySecureStore()
        secureStore.setString("access_123", for: "auth_access_token")
        secureStore.setString("refresh_123", for: "auth_refresh_token")

        let apiClient = MockAPIClient()
        let service = NetworkAuthService(apiClient: apiClient, secureStore: secureStore, logger: TestLogger())
        await service.logout()

        XCTAssertNil(secureStore.string(for: "auth_access_token"))
        XCTAssertNil(secureStore.string(for: "auth_refresh_token"))
    }

    func testSessionRestoration() async {
        let secureStore = InMemorySecureStore()
        secureStore.setString("access_123", for: "auth_access_token")
        secureStore.setString("refresh_123", for: "auth_refresh_token")
        secureStore.setString("true", for: "auth_has_logged_in")

        let service = NetworkAuthService(apiClient: MockAPIClient(), secureStore: secureStore, logger: TestLogger())
        let restored = await service.restoreSession()

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.accessToken, "access_123")
        XCTAssertEqual(restored?.isNewUser, false)
    }
}

private func authResponseData(isNewUser: Bool) -> Data {
    let json = """
    {
      "access_token": "access_123",
      "refresh_token": "refresh_123",
      "expires_in": 3600,
      "is_new_user": \(isNewUser ? "true" : "false")
    }
    """
    return Data(json.utf8)
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

    func setString(_ value: String, for key: String) {
        storage[key] = Data(value.utf8)
    }

    func string(for key: String) -> String? {
        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct TestLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}
