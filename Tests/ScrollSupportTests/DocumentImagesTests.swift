import Foundation
import MarkdownViews
@testable import ScrollSupport
import Synchronization
import Testing

/// Design › Images: the image side of the app's host, for one document.
@MainActor
struct DocumentImagesTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "DocumentImagesTests-\(UUID().uuidString)")
    let clock = FakeClock()
    let access = FakeAccess()
    var document: URL {
        folder.appending(path: "docs/a.md")
    }

    var cache: ImageCache {
        ImageCache(directory: folder.appending(path: "Caches"), now: clock.now)
    }

    func given(_ answers: [String: Result<TransportResponse, TransportFailure>] = [:]) -> Harness {
        Harness(FakeTransport(answers), cache: cache, access: access)
    }

    func request(_ destination: String, in document: URL? = nil) -> ImageRequest {
        ImageRequest(destination: destination, documentURL: document ?? self.document, maxPixelSize: .zero)
    }

    static func png() throws -> Data {
        try ImageCheckTests.givenImage("public.png")
    }

    // MARK: remote

    @Test
    func `opening a document makes zero requests`() async {
        let harness = given()
        let (images, transport) = (harness.images, harness.transport)

        #expect(await images.image(for: request("https://e.com/a.png")) == .remoteNotLoaded(host: "e.com"))
        #expect(transport.requests.isEmpty)
    }

    @Test
    func `a cached image shows on a later open with no request`() async throws {
        let png = try Self.png()
        try cache.store(png, for: #require(URL(string: "https://e.com/a.png")))
        let harness = given()
        let (images, transport) = (harness.images, harness.transport)

        #expect(await images.image(for: request("https://e.com/a.png")) == .image(png))
        #expect(transport.requests.isEmpty)
    }

    @Test
    func `activating a card fetches once and caches the image`() async throws {
        let png = try Self.png()
        let harness = given(["https://e.com/a.png": FakeTransport.ok(png)])
        let (images, transport) = (harness.images, harness.transport)
        let activation = ImageActivation(
            destination: "https://e.com/a.png", documentURL: document, card: .remoteNotLoaded(host: "e.com")
        )

        images.activateImage(activation)
        images.activateImage(activation)
        #expect(await harness.next() == "https://e.com/a.png")
        #expect(await harness.next() == "https://e.com/a.png")

        #expect(await images.image(for: request("https://e.com/a.png")) == .image(png))
        #expect(transport.requests.count == 1)
        #expect(try cache.image(for: #require(URL(string: "https://e.com/a.png"))) == png)
    }

    @Test
    func `a card shows loading while its fetch runs`() async {
        let harness = given()
        let images = harness.images

        images.activateImage(ImageActivation(destination: "https://e.com/a.png", documentURL: document, card: .loading))

        #expect(await harness.next() == "https://e.com/a.png")
        #expect(await images.image(for: request("https://e.com/a.png")) == .loading)
    }

    @Test
    func `a failed fetch shows its card`() async {
        let harness = given(["https://e.com/a.png": .failure(.timedOut)])
        let images = harness.images

        images.activateImage(ImageActivation(destination: "https://e.com/a.png", documentURL: document, card: .loading))
        _ = await harness.next()
        _ = await harness.next()

        #expect(await images.image(for: request("https://e.com/a.png")) == .failed(reason: .timedOut))
    }

    @Test
    func `a failed reload keeps the old copy with the reason`() async throws {
        let png = try Self.png()
        try cache.store(png, for: #require(URL(string: "https://e.com/a.png")))
        let harness = given(["https://e.com/a.png": .failure(.network)])
        let (images, transport) = (harness.images, harness.transport)

        images.reloadImage(request("https://e.com/a.png"))
        #expect(await harness.next() == "https://e.com/a.png")

        #expect(await images.image(for: request("https://e.com/a.png")) == .image(png, reloadFailure: .network))
        #expect(transport.requests.count == 1)
        #expect(try cache.image(for: #require(URL(string: "https://e.com/a.png"))) == png)
    }

    @Test
    func `a reload with no old copy shows the failed card`() async {
        let harness = given(["https://e.com/a.png": .failure(.network)])
        let images = harness.images

        images.reloadImage(request("https://e.com/a.png"))
        _ = await harness.next()
        _ = await harness.next()

        #expect(await images.image(for: request("https://e.com/a.png")) == .failed(reason: .network))
    }

    @Test
    func `a failed reload keeps the copy loaded in this session`() async throws {
        let png = try Self.png()
        let harness = given(["https://e.com/a.png": FakeTransport.ok(png)])
        let (images, transport) = (harness.images, harness.transport)
        images.activateImage(ImageActivation(destination: "https://e.com/a.png", documentURL: document, card: .loading))
        _ = await harness.next()
        _ = await harness.next()
        cache.clear()
        transport.answer("https://e.com/a.png", with: .failure(.timedOut))

        images.reloadImage(request("https://e.com/a.png"))
        _ = await harness.next()

        #expect(await images.image(for: request("https://e.com/a.png")) == .image(png, reloadFailure: .timedOut))
    }

    @Test
    func `a failed reload keeps the shown copy when another document changed the cache`() async throws {
        let png = try Self.png()
        let other = try ImageCheckTests.givenImage("public.png", width: 2, height: 2)
        let harness = given(["https://e.com/a.png": FakeTransport.ok(png)])
        let (images, transport) = (harness.images, harness.transport)
        images.activateImage(ImageActivation(destination: "https://e.com/a.png", documentURL: document, card: .loading))
        _ = await harness.next()
        _ = await harness.next()
        try cache.store(other, for: #require(URL(string: "https://e.com/a.png")))
        transport.answer("https://e.com/a.png", with: .failure(.network))

        images.reloadImage(request("https://e.com/a.png"))
        _ = await harness.next()

        #expect(await images.image(for: request("https://e.com/a.png")) == .image(png, reloadFailure: .network))
    }

    @Test
    func `a reload of a local image reads it again`() async {
        let harness = given()
        let (images, transport) = (harness.images, harness.transport)

        images.reloadImage(request("a.png"))

        #expect(await harness.next() == "a.png")
        #expect(transport.requests.isEmpty)
    }

    @Test
    func `activating a refused or local card does nothing`() async throws {
        try givenFile("docs/a.png", Self.png())
        let harness = given()
        let (images, transport) = (harness.images, harness.transport)
        var refreshes = 0
        images.onRefresh = { _ in refreshes += 1 }

        images.activateImage(ImageActivation(destination: "http://e.com/a.png", documentURL: document, card: .loading))
        images.activateImage(ImageActivation(
            destination: "a.png",
            documentURL: document,
            card: .failed(reason: .network)
        ))
        images.activateImage(ImageActivation(destination: "a.png", documentURL: nil, card: .needsAccess))
        await Task.yield()

        #expect(refreshes == 0)
        #expect(transport.requests.isEmpty)
        #expect(access.requested.isEmpty)
    }

    @Test
    func `the app init uses the given transport`() async {
        let images = DocumentImages(transport: FakeTransport([:]), access: access)

        #expect(await images.image(for: request("http://e.com/a.png")) == .refused(reason: nil))
    }

    @Test
    func `a reload replaces the cached copy`() async throws {
        let old = try Self.png()
        let new = try ImageCheckTests.givenImage("public.png", width: 2, height: 2)
        try cache.store(old, for: #require(URL(string: "https://e.com/a.png")))
        let harness = given(["https://e.com/a.png": FakeTransport.ok(new)])
        let images = harness.images

        images.reloadImage(request("https://e.com/a.png"))
        _ = await harness.next()

        #expect(await images.image(for: request("https://e.com/a.png")) == .image(new))
        #expect(try cache.image(for: #require(URL(string: "https://e.com/a.png"))) == new)
    }

    @Test(.timeLimit(.minutes(1)))
    func `load all skips an image loaded in this session`() async throws {
        let png = try Self.png()
        let harness = given([
            "https://e.com/a.png": FakeTransport.ok(png), "https://f.com/b.png": FakeTransport.ok(png)
        ])
        harness.images.activateImage(
            ImageActivation(destination: "https://e.com/a.png", documentURL: document, card: .loading)
        )
        _ = await harness.next()
        _ = await harness.next()

        harness.images.loadAllImages(in: "![a](https://e.com/a.png) ![b](https://f.com/b.png)", documentURL: document)
        _ = await harness.next()
        _ = await harness.next()

        #expect(harness.transport.requests.compactMap { $0.url?.absoluteString } == [
            "https://e.com/a.png", "https://f.com/b.png"
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func `load all fetches each remote image of the text once, and nothing else`() async throws {
        let png = try Self.png()
        let harness = given([
            "https://e.com/a.png": FakeTransport.ok(png), "https://f.com/b.png": FakeTransport.ok(png)
        ])
        let (images, transport) = (harness.images, harness.transport)
        let text = """
        ![a](https://e.com/a.png) ![a again](https://e.com/a.png)
        ![b](https://f.com/b.png) ![http](http://e.com/c.png) ![local](c.png)
        """

        images.loadAllImages(in: text, documentURL: document)
        var done = Set<String>()
        while done.count < 2, let destination = await harness.next() {
            if case .image = await images.image(for: request(destination)) {
                done.insert(destination)
            }
        }

        #expect(Set(transport.requests.compactMap { $0.url?.absoluteString }) == done)
        #expect(transport.requests.count == 2)
    }

    func givenFile(_ path: String, _ data: Data) throws {
        let file = folder.appending(path: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file)
    }
}

/// A `DocumentImages` with its fake transport and the stream of refreshed destinations.
@MainActor
final class Harness {
    let images: DocumentImages
    let transport: FakeTransport
    private let refreshed: AsyncStream<String>.Iterator

    init(_ transport: FakeTransport, cache: ImageCache, access: FakeAccess) {
        self.transport = transport
        images = DocumentImages(loader: RemoteLoader(transport: transport), cache: cache, access: access)
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        images.onRefresh = { continuation.yield($0) }
        refreshed = stream.makeAsyncIterator()
    }

    /// The next destination the images refreshed.
    func next() async -> String? {
        // The iterator wraps one shared buffer, so a copy reads the same stream.
        var iterator = refreshed
        return await iterator.next(isolation: MainActor.shared)
    }
}

/// A folder-access port the test sets by hand. Every folder is readable
/// until `readable` is set.
final class FakeAccess: FolderAccess {
    private struct State {
        var readable: Set<URL>?
        var grant = false
        var requested: [URL] = []
    }

    private let state = Mutex(State())

    var readable: Set<URL> {
        get { state.withLock { $0.readable ?? [] } }
        set { state.withLock { $0.readable = newValue } }
    }

    var grantOnRequest: Bool {
        get { state.withLock { $0.grant } }
        set { state.withLock { $0.grant = newValue } }
    }

    var requested: [URL] {
        state.withLock { $0.requested }
    }

    func canRead(_ folder: URL) -> Bool {
        state.withLock { $0.readable.map { $0.contains(folder.standardizedFileURL) } ?? true }
    }

    func request(_ folder: URL) async -> Bool {
        state.withLock {
            $0.requested.append(folder)
            if $0.grant {
                $0.readable?.insert(folder.standardizedFileURL)
            }
            return $0.grant
        }
    }
}
