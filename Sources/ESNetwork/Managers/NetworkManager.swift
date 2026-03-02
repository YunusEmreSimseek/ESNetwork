//
//  NetworkManager.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
import Foundation

/// The main manager responsible for executing network requests using `URLSession`.
public final class NetworkManager: NetworkService, Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let authProvider: AuthProvider?
    private let interceptors: [NetworkInterceptor]
    
    /// Initializes a new NetworkManager.
    /// - Parameters:
    ///   - session: The `URLSession` to use for requests. Defaults to `.shared`.
    ///   - decoder: The `JSONDecoder` to use for decoding responses. Defaults to a new instance.
    ///   - authProvider: An optional provider to inject authorization tokens.
    ///   - interceptors: An array of interceptors for request/response manipulation. Defaults to an empty array.
    public init(session: URLSession = .shared, decoder: JSONDecoder = .init(), authProvider: AuthProvider? = nil, interceptors: [NetworkInterceptor] = []) {
        self.session = session
        self.decoder = decoder
        self.authProvider = authProvider
        self.interceptors = interceptors
    }
    
    // MARK: - Public Methods
    /// Executes a network request and decodes the response into the specified type.
    /// - Parameters:
    ///   - endpoint: The target endpoint that conforms to `Endpoint`.
    ///   - responseType: The expected `Decodable` type of the response.
    /// - Returns: An instance of the requested `Decodable` type.
    /// - Throws: A `NetworkError` if the request, networking, or decoding fails.
    public func request<T: Decodable>(_ endpoint: Endpoint, responseType: T.Type) async throws -> T {
        let data = try await performRequest(for: endpoint, isRetry: false)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    /// Executes a network request without expecting a decodable response body.
    /// Useful for endpoints that return success without a body (e.g., 204 No Content).
    /// - Parameter endpoint: The target endpoint that conforms to `Endpoint`.
    /// - Throws: A `NetworkError` if the request or networking fails.
    public func request(_ endpoint: Endpoint) async throws {
        _ = try await performRequest(for: endpoint, isRetry: false)
    }
    
    // MARK: - Private Helper
    /// Handles the actual URLSession data task, token injection, interceptor execution, and HTTP status validation.
    /// - Parameters:
    ///   - endpoint: The target endpoint to request.
    ///   - isRetry: A flag indicating whether this is a retry attempt after a token refresh, preventing infinite loops.
    /// - Returns: The raw `Data` received from the server.
    /// - Throws: A `NetworkError` based on transport failures, invalid responses, or HTTP error codes.
    private func performRequest(for endpoint: Endpoint, isRetry: Bool) async throws -> Data {
        var request = try endpoint.asURLRequest()
        
        if let authProvider = authProvider, let token = try await authProvider.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        for interceptor in interceptors {
            request = try await interceptor.adapt(request)
        }
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw NetworkError.requestCancelled
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                throw NetworkError.noInternetConnection
            } else if urlError.code == .timedOut {
                throw NetworkError.timeout
            } else if urlError.code == .cancelled {
                throw NetworkError.requestCancelled
            } else {
                throw NetworkError.transportError(urlError)
            }
        } catch {
            throw NetworkError.transportError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        for interceptor in interceptors {
            try await interceptor.process(httpResponse, data: data)
        }
        
        switch httpResponse.statusCode {
        case 200 ... 299:
            return data
        case 401:
            if !isRetry, let authProvider = authProvider {
                let newToken = try await authProvider.refreshToken()
                if newToken != nil {
                    return try await performRequest(for: endpoint, isRetry: true)
                }
            }
            throw NetworkError.unauthorized
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}
