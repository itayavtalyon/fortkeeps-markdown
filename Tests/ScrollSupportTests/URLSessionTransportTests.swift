import Foundation
@testable import ScrollSupport
import Synchronization
import Testing

/// Design › Images: the URLSession transport, against a stub protocol.
struct URLSessionTransportTests {
    static func transport() -> URLSessionTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSessionTransport(configuration: configuration)
    }

    @Test
    func `a response gives its status and body`() async throws {
        let url = StubProtocol.answer("ok", status: 200, body: Data("abc".utf8))

        let response = try await Self.transport().send(URLRequest(url: url), limit: 10)

        #expect(response == TransportResponse(status: 200, location: nil, body: Data("abc".utf8)))
    }

    @Test
    func `the body is read to one byte past the limit`() async throws {
        let url = StubProtocol.answer("big", status: 200, body: Data(count: 100))

        let response = try await Self.transport().send(URLRequest(url: url), limit: 10)

        #expect(response.body.count == 11)
    }

    @Test
    func `a redirect is returned, not followed`() async throws {
        let target = StubProtocol.answer("target", status: 200, body: Data())
        let url = StubProtocol.answer("hop", status: 302, headers: ["Location": target.absoluteString])

        let response = try await Self.transport().send(URLRequest(url: url), limit: 10)

        #expect(response.status == 302)
        #expect(response.location == target.absoluteString)
        #expect(!StubProtocol.requested.contains(target))
    }

    @Test
    func `the session keeps no cookies and no cache`() {
        let configuration = URLSessionTransport().session.configuration

        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.httpCookieAcceptPolicy == .never)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test
    func `a cookie set by one response is not sent with the next`() async throws {
        let transport = Self.transport()
        let first = StubProtocol.answer("cookie1", status: 200, headers: ["Set-Cookie": "id=1; Path=/"])
        let second = StubProtocol.answer("cookie2", status: 200)

        _ = try await transport.send(URLRequest(url: first), limit: 10)
        _ = try await transport.send(URLRequest(url: second), limit: 10)

        #expect(StubProtocol.headers(of: second)?["Cookie"] == nil)
    }

    @Test(arguments: [(URLError.Code.timedOut, TransportFailure.timedOut), (.notConnectedToInternet, .network)])
    func `a failure maps to the matching transport failure`(code: URLError.Code, failure: TransportFailure) async {
        let url = StubProtocol.fail("fail\(code.rawValue)", with: URLError(code))

        await #expect(throws: failure) { try await Self.transport().send(URLRequest(url: url), limit: 10) }
    }
}

/// Answers each stub URL from a table, and records each request it starts.
final class StubProtocol: URLProtocol {
    private struct Answer {
        var status = 200
        var headers: [String: String] = [:]
        var body = Data()
        var error: URLError?
    }

    private static let base = URL(string: "https://stub.example")!
    private static let table = Mutex<[URL: Answer]>([:])
    private static let log = Mutex<[URL: [String: String]]>([:])

    static var requested: [URL] {
        log.withLock { Array($0.keys) }
    }

    static func headers(of url: URL) -> [String: String]? {
        log.withLock { $0[url] }
    }

    static func answer(_ name: String, status: Int, headers: [String: String] = [:], body: Data = Data()) -> URL {
        let url = base.appending(path: "\(name)-\(UUID().uuidString)")
        table.withLock { $0[url] = Answer(status: status, headers: headers, body: body) }
        return url
    }

    static func fail(_ name: String, with error: URLError) -> URL {
        let url = base.appending(path: "\(name)-\(UUID().uuidString)")
        table.withLock { $0[url] = Answer(error: error) }
        return url
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let answer = Self.table.withLock({ $0[url] }),
              let response = HTTPURLResponse(
                  url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: answer.headers
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.log.withLock { $0[url] = request.allHTTPHeaderFields ?? [:] }
        if let error = answer.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let location = answer.headers["Location"], let target = URL(string: location) {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
