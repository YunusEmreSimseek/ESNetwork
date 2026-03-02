//
//  Endpoint.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
import Foundation

/// A protocol defining the requirements for a network endpoint.
public protocol Endpoint {
    /// The base URL of the API (e.g., "https://api.example.com").
    var baseURL: String { get }
    
    /// The specific path for the request (e.g., "v1/users").
    var path: String { get }
    
    /// The HTTP method to use for the request.
    var method: HTTPMethod { get }
    
    /// The HTTP task to be performed (plain, with body, or query parameters).
    var task: HTTPTask { get }
    
    /// The HTTP headers to be sent with the request.
    var headers: [String: String]? { get }
    
    /// The timeout interval for the request in seconds.
    var timeoutInterval: TimeInterval { get }
}

public extension Endpoint {
    // Provide default values so conforming types don't have to implement everything if not needed.
    var headers: [String: String]? { return nil }
    
    // Default timeout of 30 seconds is a common choice for network requests, but can be overridden by specific endpoints if needed.
    var timeoutInterval: TimeInterval { return 30.0 }
    
    /// Converts the `Endpoint` definition into a standard `URLRequest` ready to be executed.
    /// - Returns: A configured `URLRequest`.
    /// - Throws: `NetworkError` if the URL cannot be constructed or body encoding fails.
    func asURLRequest() throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        let formattedPath = path.hasPrefix("/") ? path : "/\(path)"
        urlComponents.path = urlComponents.path.isEmpty
            ? formattedPath
            : urlComponents.path + formattedPath
        
        var requestBody: Data? = nil
        var queryItems: [URLQueryItem]? = nil
        
        switch task {
        case .requestPlain:
            break
            
        case .requestWithQueryParameters(let parameters):
            queryItems = parameters.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
            
        case .requestWithBody(let bodyModel):
            requestBody = try encodeBody(bodyModel)
            
        case .requestWithBodyAndQuery(let bodyModel, let parameters):
            requestBody = try encodeBody(bodyModel)
            queryItems = parameters.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let finalURL = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = requestBody
        request.timeoutInterval = timeoutInterval
        
        if requestBody != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }

    // MARK: - Private Helpers
    /// Encodes an `Encodable` model into `Data`.
    private func encodeBody(_ body: any Encodable) throws -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw NetworkError.encodingFailed(error)
        }
    }
}
