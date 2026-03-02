@testable import ESNetwork
import XCTest

final class ESNetworkTests: XCTestCase {
    var sut: NetworkManager!
    var urlSession: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: configuration)
        sut = NetworkManager(session: urlSession)
    }

    override func tearDown() {
        sut = nil
        urlSession = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testRequest_WhenResponseIsSuccessful_ReturnsDecodedObject() async throws {
        let expectedModel = DummyModel(id: 1, name: "Emre")
        let encodedData = try JSONEncoder().encode(expectedModel)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, encodedData)
        }

        let result = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)

        XCTAssertEqual(result.id, expectedModel.id)
        XCTAssertEqual(result.name, expectedModel.name)
        XCTAssertEqual(result, expectedModel)
    }

    func testRequest_WhenDecodingFails_ThrowsDecodingError() async {
        let invalidJSONData = Data("this is not a valid json format".utf8)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, invalidJSONData)
        }

        do {
            _ = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)
            XCTFail("Expected the request to fail, but it succeeded.")
        } catch let error as NetworkError {
            if case .decodingFailed = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected a decodingFailed error, but got \(error) instead.")
            }
        } catch {
            XCTFail("Threw an unexpected error type instead of NetworkError.")
        }
    }

    func testRequest_WhenStatusCodeIs404_ThrowsHttpError() async {
        let responseData = Data("Not Found".utf8)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        do {
            _ = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)
            XCTFail("Expected the request to fail, but it succeeded.")
        } catch let error as NetworkError {
            if case .httpError(let statusCode, let data) = error {
                XCTAssertEqual(statusCode, 404)
                XCTAssertEqual(data, responseData)
            } else {
                XCTFail("Expected an httpError, but got \(error) instead.")
            }
        } catch {
            XCTFail("Threw an unexpected error type instead of NetworkError.")
        }
    }

    func testRequest_When401Unauthorized_RefreshesTokenAndRetriesSuccessfully() async throws {
        let mockAuth = MockAuthProvider()
        sut = NetworkManager(session: urlSession, authProvider: mockAuth)

        let expectedModel = DummyModel(id: 99, name: "Refreshed User")
        let encodedData = try JSONEncoder().encode(expectedModel)

        var requestCount = 0

        MockURLProtocol.requestHandler = { request in
            requestCount += 1

            if requestCount == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            } else {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer new_token_123")

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, encodedData)
            }
        }

        let result = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)

        XCTAssertEqual(mockAuth.refreshCallCount, 1, "Refresh token should be called exactly once.")
        XCTAssertEqual(requestCount, 2, "The network request should be executed twice (initial + retry).")
        XCTAssertEqual(result.name, expectedModel.name, "Should return the successfully decoded model after retry.")
    }

    func testRequest_When401UnauthorizedAndRefreshFails_ThrowsUnauthorizedError() async {
        let mockAuth = MockAuthProvider()
        mockAuth.refreshedTokenToReturn = nil
        sut = NetworkManager(session: urlSession, authProvider: mockAuth)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)
            XCTFail("Expected unauthorized error, but the request succeeded.")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unauthorized, "Should throw .unauthorized when refresh fails.")
            XCTAssertEqual(mockAuth.refreshCallCount, 1, "Refresh method should be called exactly once.")
        } catch {
            XCTFail("Threw an unexpected error type: \(error)")
        }
    }

    func testRequest_WhenNoInternetConnection_ThrowsNoInternetError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)
            XCTFail("Expected to throw an error, but it succeeded.")
        } catch let error as NetworkError {
            if case .noInternetConnection = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected noInternetConnection error, but got \(error) instead.")
            }
        } catch {
            XCTFail("Threw an unexpected error type.")
        }
    }

    func testRequest_WithNoResponseBody_SucceedsWithoutThrowing() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            try await sut.request(DummyEndpoint.getDummy)
            XCTAssertTrue(true, "Request completed successfully without throwing any errors.")
        } catch {
            XCTFail("Expected success, but threw an error: \(error)")
        }
    }

    func testRequest_WhenUsingInterceptor_AppliesModifiedHeaders() async throws {
        let interceptor = MockHeaderInterceptor()
        sut = NetworkManager(session: urlSession, interceptors: [interceptor])

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Model"), "iPhone_15")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try! JSONEncoder().encode(DummyModel(id: 1, name: "Test")))
        }

        _ = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)
    }

    func testRequest_WhenTimeoutOccurs_ThrowsTimeoutError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await sut.request(DummyEndpoint.getDummy, responseType: DummyModel.self)
            XCTFail("Expected timeout error, but request succeeded.")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error type.")
        }
    }

    func testRequest_WhenQueryParametersProvided_ConstructsCorrectURL() async throws {
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("query=swift"))
            XCTAssertTrue(urlString.contains("page=1"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try! JSONEncoder().encode(DummyModel(id: 1, name: "Test")))
        }

        _ = try await sut.request(DummyQueryEndpoint.search, responseType: DummyModel.self)
    }

    func testEndpoint_WhenTimeoutIntervalProvided_SetsCorrectTimeoutOnRequest() throws {
        struct CustomTimeoutEndpoint: Endpoint {
            var baseURL: String { "https://test.com" }
            var path: String { "/" }
            var method: HTTPMethod { .get }
            var task: HTTPTask { .requestPlain }
            var timeoutInterval: TimeInterval { return 10.0 }
        }

        let endpoint = CustomTimeoutEndpoint()

        let request = try endpoint.asURLRequest()

        XCTAssertEqual(request.timeoutInterval, 10.0, "The URLRequest should have the custom timeout interval.")
    }

    private struct FailingEncodable: Encodable {
        func encode(to encoder: Encoder) throws {
            throw NSError(domain: "TestEncodingError", code: 999, userInfo: nil)
        }
    }

    private struct FailingBodyEndpoint: Endpoint {
        var baseURL: String { return "https://api.test.com" }
        var path: String { return "/upload" }
        var method: HTTPMethod { return .post }
        var task: HTTPTask { return .requestWithBody(FailingEncodable()) }
    }

    func testEndpoint_WhenBodyEncodingFails_ThrowsEncodingFailedError() {
        let endpoint = FailingBodyEndpoint()

        XCTAssertThrowsError(try endpoint.asURLRequest(), "Expected to throw an error when body encoding fails.") { error in
            guard case .encodingFailed = error as? NetworkError else {
                XCTFail("Expected .encodingFailed error, but got \(error) instead.")
                return
            }
        }
    }

    private struct InvalidURLEndpoint: Endpoint {
        var baseURL: String { return "ht tp://invalid url" }
        var path: String { return "" }
        var method: HTTPMethod { return .get }
        var task: HTTPTask { return .requestPlain }
    }

    func testEndpoint_WhenBaseURLIsInvalid_ThrowsInvalidURLError() {
        let endpoint = InvalidURLEndpoint()

        XCTAssertThrowsError(try endpoint.asURLRequest(), "Expected to throw an error for invalid URL.") { error in
            XCTAssertEqual(error as? NetworkError, NetworkError.invalidURL, "Error should be .invalidURL.")
        }
    }
}
