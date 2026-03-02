//
//  NetworkError.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
import Foundation

/// Represents the possible errors that can occur within the network layer.
public enum NetworkError: Error, LocalizedError {
    // MARK: - Request Errors
    /// The provided URL is invalid or malformed.
    case invalidURL
    
    /// The request body or parameters failed to encode.
    case encodingFailed(Error?)
    
    // MARK: - Transport Errors
    /// A network transport error occurred (e.g., connection lost).
    case transportError(Error)
    
    /// The network request timed out.
    case timeout
    
    /// The device is not connected to the internet.
    case noInternetConnection
    
    /// The network request was cancelled (e.g., user navigated away or task was explicitly cancelled).
    case requestCancelled
    
    // MARK: - Server Errors
    /// The server responded with an invalid or unexpected format (not an HTTPURLResponse).
    case invalidResponse
    
    /// The request is unauthorized (HTTP 401). Typically used to trigger a token refresh flow.
    case unauthorized
    
    /// The server returned an HTTP error status code (4xx or 5xx). Includes the raw data for custom error parsing by the client.
    case httpError(statusCode: Int, data: Data?)
    
    // MARK: - Parsing Errors
    /// The response data failed to decode into the expected model.
    case decodingFailed(Error)
    
    /// An unknown error occurred with a specific message.
    case unknown(String)
    
    // MARK: - Localized Descriptions
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided URL is invalid."
        case .encodingFailed:
            return "Failed to encode the request."
        case .transportError(let error):
            return "Network transport error: \(error.localizedDescription)"
        case .timeout:
            return "The request timed out."
        case .noInternetConnection:
            return "No internet connection available."
        case .requestCancelled:
            return "The network request was cancelled."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .unauthorized:
            return "Session expired or unauthorized. Please log in again."
        case .httpError(let statusCode, _):
            return "Server error occurred with status code: \(statusCode)."
        case .decodingFailed(let error):
            return "Failed to decode the response: \(error.localizedDescription)"
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
    
    // MARK: - Retry Logic
    /// Indicates whether the error is transient and the request can be automatically retried without user intervention.
    public var isRetryable: Bool {
        switch self {
        case .timeout, .noInternetConnection:
            return true
        case .httpError(let statusCode, _):
            return (500 ... 599).contains(statusCode)
        default:
            return false
        }
    }
    
    /// Indicates whether the error can potentially be resolved by user action (e.g., re-login, enabling internet).
    public var isRecoverable: Bool {
        switch self {
        case .timeout, .noInternetConnection, .unauthorized:
            return true
        case .httpError(let statusCode, _):
            return (500 ... 599).contains(statusCode)
        default:
            return false
        }
    }
}

// MARK: - Equatable Conformance
extension NetworkError: Equatable {
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.timeout, .timeout),
             (.noInternetConnection, .noInternetConnection),
             (.requestCancelled, .requestCancelled),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized):
            return true
            
        case (.httpError(let lhsCode, _), .httpError(let rhsCode, _)):
            return lhsCode == rhsCode
            
        case (.unknown(let lhsMsg), .unknown(let rhsMsg)):
            return lhsMsg == rhsMsg
            
        case (.encodingFailed, .encodingFailed),
             (.transportError, .transportError),
             (.decodingFailed, .decodingFailed):
            return true
            
        default:
            return false
        }
    }
}
