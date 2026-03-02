//
//  MockHeaderInterceptor.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
@testable import ESNetwork
import Foundation

// MARK: - Mock Interceptor
final class MockHeaderInterceptor: NetworkInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue("iPhone_15", forHTTPHeaderField: "X-Device-Model")
        return request
    }

    func process(_ response: HTTPURLResponse, data: Data) async throws {}
}
