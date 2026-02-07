import Foundation
import FoundationKit

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public struct Endpoint<Response: Decodable> {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: Data?

    public init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
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

public enum NetworkError: Error {
    case invalidURL
    case offline
    case unauthorized
    case server(Int, Data?)
    case transport(Error)
    case decoding(Error)
}

public protocol APIClient {
    func request<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response
}

public protocol AuthTokenProvider {
    func fetchToken() async -> String?
}

public protocol AuthInterceptor {
    func apply(to request: inout URLRequest) async
}

public struct BearerAuthInterceptor: AuthInterceptor {
    private let tokenProvider: AuthTokenProvider

    public init(tokenProvider: AuthTokenProvider) {
        self.tokenProvider = tokenProvider
    }

    public func apply(to request: inout URLRequest) async {
        guard let token = await tokenProvider.fetchToken() else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
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
    public let delay: TimeInterval
    public let retryableStatusCodes: Set<Int>

    public init(maxRetries: Int, delay: TimeInterval, retryableStatusCodes: Set<Int>) {
        self.maxRetries = maxRetries
        self.delay = delay
        self.retryableStatusCodes = retryableStatusCodes
    }

    public func shouldRetry(statusCode: Int?, error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        if let statusCode, retryableStatusCodes.contains(statusCode) {
            return true
        }
        return error is URLError
    }

    public static let `default` = RetryPolicy(
        maxRetries: 2,
        delay: 0.5,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )
}

public final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let authInterceptor: AuthInterceptor?
    private let retryPolicy: RetryPolicy
    private let reachability: ReachabilityChecking
    private let logger: Logger

    public init(
        session: URLSession = .shared,
        configuration: NetworkConfiguration,
        authInterceptor: AuthInterceptor? = nil,
        retryPolicy: RetryPolicy = .default,
        reachability: ReachabilityChecking = AlwaysReachable(),
        logger: Logger
    ) {
        self.session = session
        self.configuration = configuration
        self.authInterceptor = authInterceptor
        self.retryPolicy = retryPolicy
        self.reachability = reachability
        self.logger = logger
    }

    public func request<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response {
        guard reachability.isReachable else { throw NetworkError.offline }

        var attempt = 0
        while true {
            do {
                let request = try await buildRequest(endpoint)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.server(0, data)
                }
                if httpResponse.statusCode == 401 {
                    throw NetworkError.unauthorized
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw NetworkError.server(httpResponse.statusCode, data)
                }
                do {
                    return try JSONDecoder().decode(Response.self, from: data)
                } catch {
                    throw NetworkError.decoding(error)
                }
            } catch {
                let statusCode = (error as? NetworkError).flatMap { networkError -> Int? in
                    if case let .server(code, _) = networkError { return code }
                    return nil
                }
                let shouldRetry = retryPolicy.shouldRetry(statusCode: statusCode, error: error, attempt: attempt)
                logger.warn("Network request failed (attempt \(attempt + 1)): \(error)")
                if shouldRetry {
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(retryPolicy.delay * 1_000_000_000))
                    continue
                }
                if let networkError = error as? NetworkError {
                    throw networkError
                }
                throw NetworkError.transport(error)
            }
        }
    }

    private func buildRequest<Response>(_ endpoint: Endpoint<Response>) async throws -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.timeoutInterval = configuration.timeout
        configuration.defaultHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        await authInterceptor?.apply(to: &request)
        return request
    }
}
