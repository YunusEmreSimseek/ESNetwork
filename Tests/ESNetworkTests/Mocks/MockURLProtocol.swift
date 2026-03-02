//
//  MockURLProtocol.swift
//  ESNetwork
//
//  Created by yesimsek on 27.02.2026.
//
import Foundation

/// A custom URLProtocol used to mock network requests without making actual internet calls.
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    /// A closure that allows us to define the response and data we want to return for a given request.
    public nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override public class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override public func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }
        
        do {
            let (response, data) = try handler(request)
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            client?.urlProtocol(self, didLoad: data)
            
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override public func stopLoading() {}
}
