//
//  DummyEndpoint.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
@testable import ESNetwork
import Foundation

// MARK: - Dummy Endpoint
enum DummyEndpoint: Endpoint {
    case getDummy

    var baseURL: String { return "https://api.test.com" }
    var path: String { return "/dummy" }
    var method: HTTPMethod { return .get }
    var task: HTTPTask { return .requestPlain }
}

// MARK: - Dummy Query Endpoint
enum DummyQueryEndpoint: Endpoint {
    case search
    var baseURL: String { "https://api.test.com" }
    var path: String { "/search" }
    var method: HTTPMethod { .get }
    var task: HTTPTask { .requestWithQueryParameters(["query": "swift", "page": "1"]) }
}
