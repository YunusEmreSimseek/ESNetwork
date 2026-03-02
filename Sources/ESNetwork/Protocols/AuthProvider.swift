//
//  AuthProvider.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
public protocol AuthProvider: Sendable {
    /// Retrieves the current access token.
    /// - Returns: A valid token string, or nil if no token is available.
    func getAccessToken() async throws -> String?

    /// Attempts to refresh the session and retrieve a new access token.
    /// - Returns: The new token if successful, or nil/throws an error if the user needs to re-login.
    func refreshToken() async throws -> String?
}
