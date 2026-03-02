//
//  NetworkInterceptor.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
import Foundation

/// A protocol to intercept and modify network requests and responses.
public protocol NetworkInterceptor: Sendable {
    /// Called before the request is sent over the network.
    /// You can modify the URLRequest here (e.g., add special headers, log the request).
    func adapt(_ request: URLRequest) async throws -> URLRequest

    /// Called after the response is received but before it's decoded.
    /// Useful for logging or globally tracking specific status codes.
    func process(_ response: HTTPURLResponse, data: Data) async throws
}

public extension NetworkInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest { request }
    func process(_ response: HTTPURLResponse, data: Data) async throws {}
}
