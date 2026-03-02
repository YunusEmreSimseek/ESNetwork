//
//  NetworkService.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
/// Defines the capabilities of our network service.
public protocol NetworkService: Sendable {
    /// Executes a network request and decodes the response into the specified type.
    func request<T: Decodable>(_ endpoint: Endpoint, responseType: T.Type) async throws -> T

    /// Executes a network request without expecting a decodable response body (e.g., 204 No Content).
    func request(_ endpoint: Endpoint) async throws
}
