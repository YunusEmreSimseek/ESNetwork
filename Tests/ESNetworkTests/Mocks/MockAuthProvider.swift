//
//  MockAuthProvider.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
@testable import ESNetwork
import Foundation

// MARK: - Mock Auth Provider
final class MockAuthProvider: AuthProvider, @unchecked Sendable {
    var tokenToReturn: String? = "old_token"
    var refreshedTokenToReturn: String? = "new_token_123"
    var refreshCallCount = 0

    func getAccessToken() async throws -> String? {
        return tokenToReturn
    }

    func refreshToken() async throws -> String? {
        refreshCallCount += 1
        tokenToReturn = refreshedTokenToReturn
        return refreshedTokenToReturn
    }
}
