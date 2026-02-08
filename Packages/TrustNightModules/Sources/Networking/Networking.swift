import Foundation
import FoundationKit

public enum HTTPMethod: String, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"

    public var isIdempotent: Bool {
        switch self {
        case .get, .put, .delete, .head:
            return true
        case .post, .patch:
            return false
        }
    }
}

public struct EmptyBody: Encodable {
    public init() {}
}

public struct EmptyResponse: Decodable {
    public init() {}
}

public struct Endpoint<Response: Decodable, Body: Encodable = EmptyBody> {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: Body?
    public let requiresAuth: Bool
    public let idempotent: Bool?

    public init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Body? = nil,
        requiresAuth: Bool = true,
        idempotent: Bool? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
        self.idempotent = idempotent
    }

    public var isIdempotent: Bool {
        idempotent ?? method.isIdempotent
    }
}

public struct NetworkConfiguration {
    public let baseURL: URL
    public let timeout: TimeInterval
    public let defaultHeaders: [String: String]

    public init(baseURL: URL, timeout: TimeInterval = 30, defaultHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
    }
}

public struct APIErrorPayload: Decodable {
    public let code: String?
    public let message: String?
    public let details: [String: String]?
    public let requestId: String?
}

public struct APIErrorEnvelope: Decodable {
    public let error: APIErrorPayload
}

public enum APIError: Error {
    case invalidURL
    case offline
    case unauthorized
    case server(statusCode: Int, code: String?, message: String?)
    case decoding(underlying: Error)
    case transport(underlying: Error)
    case refreshFailed
}

extension APIError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .offline:
            return "Network unreachable"
        case .unauthorized:
            return "Unauthorized"
        case let .server(statusCode, code, message):
            return "Server error \(statusCode) \(code ?? "unknown"): \(message ?? "no message")"
        case let .decoding(underlying):
            return "Decoding error: \(underlying)"
        case let .transport(underlying):
            return "Transport error: \(underlying)"
        case .refreshFailed:
            return "Token refresh failed"
        }
    }
}

public protocol APIClient {
    func request<Response: Decodable, Body: Encodable>(_ endpoint: Endpoint<Response, Body>) async throws -> Response
}

public protocol AuthTokenProvider {
    func fetchToken() async -> String?
}

public protocol AuthTokenRefreshing {
    func refreshToken() async throws -> String
}

public protocol ReachabilityChecking {
    var isReachable: Bool { get }
}

public struct AlwaysReachable: ReachabilityChecking {
    public init() {}
    public var isReachable: Bool { true }
}

public struct RetryPolicy {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let retryableStatusCodes: Set<Int>
    public let jitter: Double

    public init(
        maxRetries: Int = 2,
        baseDelay: TimeInterval = 0.4,
        maxDelay: TimeInterval = 4,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        jitter: Double = 0.1
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
        self.jitter = jitter
    }

    public func shouldRetry(isIdempotent: Bool, statusCode: Int?, error: Error, attempt: Int) -> Bool {
        guard isIdempotent, attempt < maxRetries else { return false }
        if let statusCode, retryableStatusCodes.contains(statusCode) {
            return true
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        return false
    }

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let expDelay = baseDelay * pow(2, Double(attempt))
        let capped = min(maxDelay, expDelay)
        guard jitter > 0 else { return capped }
        let jitterValue = Double.random(in: 0...(capped * jitter))
        return capped + jitterValue
    }

    public static let `default` = RetryPolicy()
}

public enum JSONCoding {
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

public final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let tokenProvider: AuthTokenProvider?
    private let tokenRefresher: AuthTokenRefreshing?
    private let retryPolicy: RetryPolicy
    private let reachability: ReachabilityChecking
    private let logger: Logger
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        session: URLSession = .shared,
        configuration: NetworkConfiguration,
        tokenProvider: AuthTokenProvider? = nil,
        tokenRefresher: AuthTokenRefreshing? = nil,
        retryPolicy: RetryPolicy = .default,
        reachability: ReachabilityChecking = AlwaysReachable(),
        logger: Logger,
        encoder: JSONEncoder = JSONCoding.encoder,
        decoder: JSONDecoder = JSONCoding.decoder
    ) {
        self.session = session
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
        self.retryPolicy = retryPolicy
        self.reachability = reachability
        self.logger = logger
        self.encoder = encoder
        self.decoder = decoder
    }

    public func request<Response: Decodable, Body: Encodable>(_ endpoint: Endpoint<Response, Body>) async throws -> Response {
        guard reachability.isReachable else { throw APIError.offline }

        var attempt = 0
        var didRefresh = false
        var overrideToken: String?

        while true {
            do {
                return try await performRequest(endpoint, tokenOverride: overrideToken)
            } catch {
                if case APIError.unauthorized = error,
                   endpoint.requiresAuth,
                   let tokenRefresher,
                   !didRefresh {
                    do {
                        overrideToken = try await tokenRefresher.refreshToken()
                        didRefresh = true
                        continue
                    } catch {
                        throw APIError.refreshFailed
                    }
                }

                let normalizedError = normalizeError(error)
                let statusCode = normalizedError.statusCode
                if retryPolicy.shouldRetry(
                    isIdempotent: endpoint.isIdempotent,
                    statusCode: statusCode,
                    error: normalizedError,
                    attempt: attempt
                ) {
                    let delay = retryPolicy.delay(forAttempt: attempt)
                    logger.warn("Retrying request in \(delay)s due to \(normalizedError)")
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw normalizedError
            }
        }
    }

    private func performRequest<Response: Decodable, Body: Encodable>(
        _ endpoint: Endpoint<Response, Body>,
        tokenOverride: String?
    ) async throws -> Response {
        let url = try makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = configuration.timeout

        let bodyData = try encodeBody(endpoint.body)
        if let bodyData {
            request.httpBody = bodyData
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        configuration.defaultHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if endpoint.requiresAuth {
            await applyAuth(to: &request, tokenOverride: tokenOverride)
        }

        logRequest(request, body: bodyData)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw mapTransportError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport(underlying: URLError(.badServerResponse))
        }

        logResponse(request: request, statusCode: httpResponse.statusCode, data: data)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw decodeServerError(statusCode: httpResponse.statusCode, data: data)
        }

        return try decodeResponse(data: data, as: Response.self)
    }

    private func makeURL<Response, Body>(for endpoint: Endpoint<Response, Body>) throws -> URL {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else { throw APIError.invalidURL }
        return url
    }

    private func encodeBody<Body: Encodable>(_ body: Body?) throws -> Data? {
        guard let body else { return nil }
        return try encoder.encode(body)
    }

    private func decodeResponse<Response: Decodable>(data: Data, as type: Response.Type) throws -> Response {
        if data.isEmpty, Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }

    private func decodeServerError(statusCode: Int, data: Data) -> APIError {
        if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
            return .server(statusCode: statusCode, code: envelope.error.code, message: envelope.error.message)
        }
        return .server(statusCode: statusCode, code: nil, message: nil)
    }

    private func applyAuth(to request: inout URLRequest, tokenOverride: String?) async {
        let token = tokenOverride ?? await tokenProvider?.fetchToken()
        guard let token else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func mapTransportError(_ error: Error) -> APIError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .offline
            default:
                return .transport(underlying: urlError)
            }
        }
        return .transport(underlying: error)
    }

    private func normalizeError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        return mapTransportError(error)
    }

    private func logRequest(_ request: URLRequest, body: Data?) {
        let method = request.httpMethod ?? "?"
        let redactedURL = RequestRedactor.redactedURL(request.url)
        let redactedHeaders = RequestRedactor.redactedHeaders(request.allHTTPHeaderFields ?? [:])
        let redactedBody = RequestRedactor.redactedBody(body)
        logger.debug("Request \(method) \(redactedURL) headers=\(redactedHeaders) body=\(redactedBody)")
    }

    private func logResponse(request: URLRequest, statusCode: Int, data: Data) {
        let method = request.httpMethod ?? "?"
        let redactedURL = RequestRedactor.redactedURL(request.url)
        logger.debug("Response \(method) \(redactedURL) status=\(statusCode) bytes=\(data.count)")
    }
}

public final class MockAPIClient: APIClient {
    public struct MockRouteKey: Hashable {
        public let method: HTTPMethod
        public let path: String

        public init(method: HTTPMethod, path: String) {
            self.method = method
            self.path = path
        }
    }

    public struct MockRequest {
        public let path: String
        public let method: HTTPMethod
        public let headers: [String: String]
        public let body: Data?
    }

    public typealias Handler = (MockRequest) async throws -> Data

    private var handlers: [MockRouteKey: Handler]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        handlers: [MockRouteKey: Handler] = [:],
        encoder: JSONEncoder = JSONCoding.encoder,
        decoder: JSONDecoder = JSONCoding.decoder
    ) {
        self.handlers = handlers
        self.encoder = encoder
        self.decoder = decoder
    }

    public func register<Response: Encodable>(path: String, method: HTTPMethod = .get, response: Response) {
        let key = MockRouteKey(method: method, path: path)
        handlers[key] = { [encoder] _ in
            try encoder.encode(response)
        }
    }

    public func registerData(path: String, method: HTTPMethod = .get, data: Data) {
        let key = MockRouteKey(method: method, path: path)
        handlers[key] = { _ in data }
    }

    public func request<Response: Decodable, Body: Encodable>(_ endpoint: Endpoint<Response, Body>) async throws -> Response {
        let key = MockRouteKey(method: endpoint.method, path: endpoint.path)
        guard let handler = handlers[key] else {
            throw APIError.server(statusCode: 404, code: "MOCK_NOT_FOUND", message: "No mock registered for \(endpoint.method.rawValue) \(endpoint.path)")
        }
        let bodyData = try encodeBody(endpoint.body)
        let request = MockRequest(path: endpoint.path, method: endpoint.method, headers: endpoint.headers, body: bodyData)
        let data = try await handler(request)
        return try decodeResponse(data: data, as: Response.self)
    }

    private func encodeBody<Body: Encodable>(_ body: Body?) throws -> Data? {
        guard let body else { return nil }
        return try encoder.encode(body)
    }

    private func decodeResponse<Response: Decodable>(data: Data, as type: Response.Type) throws -> Response {
        if data.isEmpty, Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }
}

private enum RequestRedactor {
    private static let redactedHeaderKeys: Set<String> = [
        "authorization",
        "x-auth-token",
        "x-refresh-token",
        "cookie",
        "set-cookie"
    ]

    private static let redactedBodyKeys: Set<String> = [
        "token",
        "access_token",
        "refresh_token",
        "identity_token",
        "authorization_code",
        "biometric",
        "biometrics",
        "face",
        "template",
        "selfie",
        "image",
        "photo",
        "liveness"
    ]

    static func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        headers.forEach { key, value in
            if redactedHeaderKeys.contains(key.lowercased()) {
                result[key] = "<redacted>"
            } else {
                result[key] = value
            }
        }
        return result
    }

    static func redactedURL(_ url: URL?) -> String {
        guard let url else { return "<nil>" }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        if let items = components.queryItems {
            components.queryItems = items.map { item in
                if redactedBodyKeys.contains(item.name.lowercased()) {
                    return URLQueryItem(name: item.name, value: "<redacted>")
                }
                return item
            }
        }
        return components.string ?? url.absoluteString
    }

    static func redactedBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "nil" }
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return "<\(data.count) bytes>"
        }
        let redactedObject = redact(jsonObject)
        guard let redactedData = try? JSONSerialization.data(withJSONObject: redactedObject, options: [.sortedKeys]),
              let string = String(data: redactedData, encoding: .utf8) else {
            return "<json>"
        }
        return string
    }

    private static func redact(_ object: Any) -> Any {
        if let dictionary = object as? [String: Any] {
            var redacted: [String: Any] = [:]
            for (key, value) in dictionary {
                if redactedBodyKeys.contains(key.lowercased()) {
                    redacted[key] = "<redacted>"
                } else {
                    redacted[key] = redact(value)
                }
            }
            return redacted
        }
        if let array = object as? [Any] {
            return array.map { redact($0) }
        }
        return object
    }
}

private extension APIError {
    var statusCode: Int? {
        if case let .server(statusCode, _, _) = self { return statusCode }
        return nil
    }
}
