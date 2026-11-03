import Foundation
import MarkdownViews
@testable import ScrollSupport
import Testing

/// Design › Images: the rules and local files of `DocumentImages`.
extension DocumentImagesTests {
    @Test
    func `a refused destination and a local image in an untitled document are refused`() async {
        let images = given().images

        #expect(await images.image(for: request("http://e.com/a.png")) == .refused(reason: nil))
        #expect(await images.image(for: request("../../a.png")) == .refused(reason: nil))
        #expect(await images.image(for: ImageRequest(destination: "a.png", documentURL: nil, maxPixelSize: .zero)) ==
            .refused(reason: "Save the document to show local images."))
    }

    @Test(.timeLimit(.minutes(2)))
    func `a local image needs access until the folder is granted, then every card of it refreshes`() async throws {
        try givenFile("docs/a.png", Self.png())
        try givenFile("docs/b.png", Self.png())
        let harness = given()
        let images = harness.images
        access.readable = []

        #expect(await images.image(for: request("a.png")) == .needsAccess)
        #expect(await images.image(for: request("b.png")) == .needsAccess)

        access.grantOnRequest = true
        images.activateImage(ImageActivation(destination: "a.png", documentURL: document, card: .needsAccess))
        let first = await harness.next()
        let second = await harness.next()
        #expect(Set([first, second]) == ["a.png", "b.png"])
        #expect(access.requested == [document.deletingLastPathComponent()])
        #expect(try await images.image(for: request("a.png")) == .image(Self.png()))
    }

    @Test
    func `a refused folder request refreshes nothing`() async throws {
        try givenFile("docs/a.png", Self.png())
        let images = given().images
        var refreshes = 0
        images.onRefresh = { _ in refreshes += 1 }
        access.readable = []

        images.activateImage(ImageActivation(destination: "a.png", documentURL: document, card: .needsAccess))
        while access.requested.isEmpty {
            await Task.yield()
        }

        #expect(refreshes == 0)
    }

    @Test
    func `a local image is read from the document folder`() async throws {
        try givenFile("docs/img/a.png", Self.png())
        let images = given().images

        #expect(try await images.image(for: request("img/a.png")) == .image(Self.png()))
    }

    @Test
    func `a symlink out of the document folder is refused`() async throws {
        // Deeper than the document folder, so only the prefix check refuses it.
        try givenFile("other/deep/secret.png", Self.png())
        try givenFile("docs/a.md", Data())
        try FileManager.default.createSymbolicLink(
            at: folder.appending(path: "docs/link.png"),
            withDestinationURL: folder.appending(path: "other/deep/secret.png")
        )
        let images = given().images

        #expect(await images.image(for: request("link.png")) == .refused(reason: nil))
    }

    @Test
    func `a symlink inside the document folder is followed`() async throws {
        try givenFile("docs/real.png", Self.png())
        try FileManager.default.createSymbolicLink(
            at: folder.appending(path: "docs/link.png"), withDestinationURL: folder.appending(path: "docs/real.png")
        )
        let images = given().images

        #expect(try await images.image(for: request("link.png")) == .image(Self.png()))
    }

    @Test(.timeLimit(.minutes(2)))
    func `a FIFO is refused without a read`() async throws {
        try givenFile("docs/a.md", Data())
        #expect(mkfifo(folder.appending(path: "docs/pipe.png").path(percentEncoded: false), 0o600) == 0)
        let images = given().images

        #expect(await images.image(for: request("pipe.png")) == .refused(reason: nil))
    }

    @Test
    func `an unreadable file is refused and an empty one is unsupported`() async throws {
        try givenFile("docs/locked.png", Self.png())
        try givenFile("docs/empty.png", Data())
        let locked = folder.appending(path: "docs/locked.png").path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: locked) }
        let images = given().images

        #expect(await images.image(for: request("locked.png")) == .refused(reason: nil))
        #expect(await images.image(for: request("empty.png")) == .failed(reason: .unsupported))
    }

    @Test
    func `a missing file or a folder is refused`() async throws {
        try givenFile("docs/dir/x.png", Self.png())
        let images = given().images

        #expect(await images.image(for: request("missing.png")) == .refused(reason: nil))
        #expect(await images.image(for: request("dir")) == .refused(reason: nil))
    }

    @Test(arguments: [(5_000_000, true), (5_000_001, false)])
    func `a local file over 5,000,000 bytes is too large`(size: Int, fits: Bool) async throws {
        var data = try Self.png()
        data.append(Data(count: size - data.count))
        try givenFile("docs/big.png", data)
        let images = given().images

        #expect(await images.image(for: request("big.png")) == (fits ? .image(data) : .failed(reason: .tooLarge)))
    }

    @Test
    func `a local SVG or undecodable file is unsupported`() async throws {
        try givenFile("docs/a.svg", Data("<svg xmlns='http://www.w3.org/2000/svg'/>".utf8))
        try givenFile("docs/b.png", Data("not a png".utf8))
        let images = given().images

        #expect(await images.image(for: request("a.svg")) == .failed(reason: .unsupported))
        #expect(await images.image(for: request("b.png")) == .failed(reason: .unsupported))
    }
}
