import XCTest
@testable import Networking

final class NetworkingTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testDecodingSamplePayload() throws {
        let data = try loadJSON(named: "user_profile")
        let profile = try JSONCoding.decoder.decode(UserProfilePayload.self, from: data)
        XCTAssertEqual(profile.displayName, "Riley")
        XCTAssertEqual(profile.coarseLocation.regionCode, "DE-BE")
        XCTAssertEqual(profile.age, 29)
    }

    func testErrorMappingFromServerPayload() async throws {
        let errorData = try loadJSON(named: "error_response")
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, errorData)
        }

        let client = makeClient()
        do {
            let endpoint = Endpoint<EmptyResponse>(path: "error", method: .get, requiresAuth: false)
            _ = try await client.request(endpoint)
            XCTFail("Expected server error.")
        } catch let error as APIError {
            switch error {
            case let .server(statusCode, code, message):
                XCTAssertEqual(statusCode, 400)
                XCTAssertEqual(code, "VALIDATION_ERROR")
                XCTAssertEqual(message, "Invalid input.")
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAuthHeaderInjection() async throws {
        var capturedAuthorization: String?
        MockURLProtocol.requestHandler = { request in
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            let data = #"{"status":"ok"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let client = makeClient(tokenProvider: StaticTokenProvider(token: "test-token"))
        let endpoint = Endpoint<StatusResponse>(path: "status", method: .get)
        let response = try await client.request(endpoint)
        XCTAssertEqual(response.status, "ok")
        XCTAssertEqual(capturedAuthorization, "Bearer test-token")
    }
}

private struct UserProfilePayload: Decodable, Equatable {
    let id: String
    let displayName: String
    let age: Int
    let coarseLocation: CoarseLocationPayload
}

private struct CoarseLocationPayload: Decodable, Equatable {
    let regionCode: String
}

private struct StatusResponse: Decodable, Equatable {
    let status: String
}

private struct StaticTokenProvider: AuthTokenProvider {
    let token: String
    func fetchToken() async -> String? { token }
}

private func makeClient(tokenProvider: AuthTokenProvider? = nil) -> URLSessionAPIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    let networkConfig = NetworkConfiguration(
        baseURL: URL(string: "https://example.com")!,
        timeout: 5,
        defaultHeaders: ["Accept": "application/json"]
    )
    return URLSessionAPIClient(
        session: session,
        configuration: networkConfig,
        tokenProvider: tokenProvider,
        tokenRefresher: nil,
        retryPolicy: RetryPolicy(maxRetries: 0, baseDelay: 0, maxDelay: 0, retryableStatusCodes: [], jitter: 0),
        reachability: AlwaysReachable(),
        logger: TestLogger()
    )
}

private func loadJSON(named name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private final class TestLogger: Logger {
    func log(_ message: String, level: LogLevel) {}
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
