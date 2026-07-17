import Foundation

/// Intercepts `URLSession` requests in tests so `APIClient` can be exercised
/// against canned responses without hitting the network.
final class MockURLProtocol: URLProtocol {
    /// Set by each test right before making a request. Returns (statusCode, body data).
    /// `nonisolated(unsafe)`: tests run serially against this shared stub and each
    /// test sets it before issuing its own request, so there's no real data race.
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol.requestHandler must be set before making a request")
        }

        do {
            let (statusCode, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeMockedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
