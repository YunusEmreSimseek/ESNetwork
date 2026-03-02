//
//  HTTPTask.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//

/// Defines the type of HTTP task to be performed for a specific request.
/// This enum helps encapsulate body data encoding and URL query parameter handling.
public enum HTTPTask {
    /// A simple request with no additional body data or URL query parameters.
    case requestPlain
    
    /// A request that includes an encodable body.
    /// The network layer will automatically encode this object into JSON data.
    /// - Parameter body: The model object to be encoded and sent in the HTTP body.
    case requestWithBody(any Encodable)
    
    /// A request that appends query parameters to the URL (e.g., `?page=1&sort=desc`).
    /// - Parameter queryParameters: A dictionary of key-value pairs to be added as query items.
    case requestWithQueryParameters([String: String])
    
    /// A request that includes both an encodable body and URL query parameters.
    /// - Parameters:
    ///   - body: The model object to be encoded into the HTTP body.
    ///   - queryParameters: A dictionary of key-value pairs to be added as query items.
    case requestWithBodyAndQuery(body: any Encodable, queryParameters: [String: String])
}
