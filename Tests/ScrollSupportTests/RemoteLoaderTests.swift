import Foundation
import MarkdownViews
@testable import ScrollSupport
import Testing

/// Design › Images: the remote load, through a fake transport.
struct RemoteLoaderTests {
    static let url = URL(string: "https://e.com/a.png")!

    static func givenPNG() throws -> Data {
        try ImageCheckTests.givenImage("public.png")
    }

    @Test
    func `a loaded image is returned`() async throws {
        let png = try Self.givenPNG()
        let transport = FakeTransport(["https://e.com/a.png": FakeTransport.ok(png)])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .image(png))
    }

    @Test(arguments: [(5_000_000, true), (5_000_001, false)])
    func `a body over 5,000,000 bytes is too large`(size: Int, fits: Bool) async throws {
        var body = try Self.givenPNG()
        body.append(Data(count: size - body.count))
        let transport = FakeTransport(["https://e.com/a.png": FakeTransport.ok(body)])

        let result = await RemoteLoader(transport: transport).load(Self.url)

        #expect(result == (fits ? .image(body) : .failed(reason: .tooLarge)))
    }

    @Test
    func `the transport is asked for at most 5,000,000 bytes`() async throws {
        let transport = try FakeTransport(["https://e.com/a.png": FakeTransport.ok(Self.givenPNG())])
        _ = await RemoteLoader(transport: transport).load(Self.url)

        #expect(transport.limits == [5_000_000])
    }

    @Test
    func `bytes that are not an allowed image are unsupported`() async {
        let transport = FakeTransport(["https://e.com/a.png": FakeTransport.ok(Data("<svg/>".utf8))])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .failed(reason: .unsupported))
    }

    @Test(arguments: [404, 500, 304, 199])
    func `a status that is not 2xx is a network failure`(status: Int) async {
        let transport = FakeTransport([
            "https://e.com/a.png": .success(TransportResponse(status: status, location: nil, body: Data()))
        ])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .failed(reason: .network))
    }

    @Test(arguments: [(TransportFailure.timedOut, ImageFailure.timedOut), (.network, .network)])
    func `a transport failure becomes the matching card`(failure: TransportFailure, reason: ImageFailure) async {
        let transport = FakeTransport(["https://e.com/a.png": .failure(failure)])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .failed(reason: reason))
    }

    @Test
    func `a request sends no cookies`() async throws {
        let transport = try FakeTransport(["https://e.com/a.png": FakeTransport.ok(Self.givenPNG())])
        _ = await RemoteLoader(transport: transport).load(Self.url)

        let request = try #require(transport.requests.first)
        #expect(!request.httpShouldHandleCookies)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test
    func `three redirects are followed, each hop checked`() async throws {
        let png = try Self.givenPNG()
        let transport = FakeTransport([
            "https://e.com/a.png": FakeTransport.redirect("https://f.com/b.png"),
            "https://f.com/b.png": FakeTransport.redirect("/c.png", status: 301),
            "https://f.com/c.png": FakeTransport.redirect("https://g.com/d.png", status: 307),
            "https://g.com/d.png": FakeTransport.ok(png)
        ])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .image(png))
        #expect(transport.requests.map { $0.url?.absoluteString } == [
            "https://e.com/a.png", "https://f.com/b.png", "https://f.com/c.png", "https://g.com/d.png"
        ])
        #expect(transport.requests.allSatisfy { !$0.httpShouldHandleCookies })
    }

    @Test
    func `a fourth redirect is a network failure`() async throws {
        let transport = try FakeTransport([
            "https://e.com/a.png": FakeTransport.redirect("https://e.com/1.png"),
            "https://e.com/1.png": FakeTransport.redirect("https://e.com/2.png"),
            "https://e.com/2.png": FakeTransport.redirect("https://e.com/3.png"),
            "https://e.com/3.png": FakeTransport.redirect("https://e.com/4.png"),
            "https://e.com/4.png": FakeTransport.ok(Self.givenPNG())
        ])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .failed(reason: .network))
        #expect(transport.requests.count == 4)
    }

    @Test(arguments: [
        "http://e.com/b.png", "https://127.0.0.1/b.png", "https://localhost/b.png", "https://[::1]/b.png",
        "https://printer.local/b.png", "data:image/png;base64,AA", "file:///etc/passwd", "//10.0.0.1/b.png"
    ])
    func `a redirect to http or a blocked host is refused and not followed`(location: String) async {
        let transport = FakeTransport(["https://e.com/a.png": FakeTransport.redirect(location)])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .refused(reason: nil))
        #expect(transport.requests.count == 1)
    }

    @Test
    func `a redirect with no location is a network failure`() async {
        let transport = FakeTransport([
            "https://e.com/a.png": .success(TransportResponse(status: 302, location: nil, body: Data()))
        ])

        #expect(await RemoteLoader(transport: transport).load(Self.url) == .failed(reason: .network))
    }

    @Test(.timeLimit(.minutes(1)))
    func `a load that outlasts the timeout fails as timed out`() async {
        let transport = FakeTransport([:])

        let result = await RemoteLoader(transport: transport, timeout: .milliseconds(20)).load(Self.url)

        #expect(result == .failed(reason: .timedOut))
    }
}
