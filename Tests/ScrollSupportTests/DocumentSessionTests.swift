#if os(iOS)
    import Foundation
    import MarkdownCore
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Design › Files (log 001) and iPhone home screen (log 002): the open
    /// documents of the iOS app, one per file.
    @MainActor
    final class DocumentSessionTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "DocumentSession-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "DocumentSessionTests-\(UUID().uuidString)") ?? .standard
        var presented: [UIViewController] = []
        let host = UIViewController()
        /// Windows a test shows a screen in, kept until the test ends.
        var windows: [UIWindow] = []

        lazy var session: DocumentSession = {
            let session = DocumentSession(
                store: FileListStore(defaults: defaults),
                environment: ScrollEnvironment(
                    transport: FakeTransport([:]),
                    access: FakeAccess(),
                    openURL: { _ in },
                    openFile: { _ in },
                    closeFile: { _ in },
                    present: { [weak self] controller, _ in self?.presented.append(controller) },
                    appFolder: folder,
                    runPrint: { _, _ in },
                    defaults: UserDefaults(suiteName: "Scroll-\(UUID().uuidString)") ?? .standard,
                    pasteboard: .withUniqueName(),
                    cache: ImageCache(directory: folder.appending(path: "Cache"))
                )
            )
            session.alertHost = host
            return session
        }()

        func given(_ name: String, _ bytes: [UInt8] = Array("a\n".utf8)) throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data(bytes).write(to: url)
            return url
        }

        @Test
        func `a file opens once and is in Open`() async throws {
            let url = try given("a.md")

            let first = await session.open(url)
            let again = await session.open(url)

            #expect(first != nil)
            #expect(first === again)
            #expect(session.store.lists.open.map(\.url) == [FileListStore.key(url)])
            #expect(session.screen(for: url) === first)
        }

        @Test
        func `two quick opens of a file give one screen`() async throws {
            let url = try given("a.md")

            async let first = session.open(url)
            async let second = session.open(url)
            let screens = await [first, second]

            #expect(screens[0] != nil)
            #expect(screens[0] === screens[1])
        }

        @Test
        func `a closed file opens again on a new screen`() async throws {
            let url = try given("a.md")
            let first = try #require(await session.open(url))
            await session.close(url)

            let again = try #require(await session.open(url))

            #expect(again !== first)
            #expect(!again.document.documentState.contains(.closed))
        }

        @Test
        func `closing a file closes its document and moves it to Recent`() async throws {
            let url = try given("a.md")
            let screen = try #require(await session.open(url))

            await session.close(url)

            #expect(screen.document.documentState.contains(.closed))
            #expect(session.screen(for: url) == nil)
            #expect(session.store.lists.recent.map(\.url) == [FileListStore.key(url)])
            await session.close(url)
        }

        @Test
        func `closing an Open file from before a relaunch moves it to Recent`() async throws {
            let url = try given("a.md")
            session.store.opened(url, at: .now)

            await session.close(url)

            #expect(session.store.lists.recent.map(\.url) == [FileListStore.key(url)])
        }

        @Test(arguments: [
            ("a.png", [UInt8]("x".utf8), "Open a .md, .markdown, or .txt file."),
            ("a.md", [0xFF], "This file is not UTF-8, so it was not opened.")
        ])
        func `a file it refuses shows the alert and opens nothing`(
            name: String, bytes: [UInt8], message: String
        ) async throws {
            let url = try given(name, bytes)

            let screen = await session.open(url)

            #expect(screen == nil)
            let alert = try #require(presented.first as? UIAlertController)
            #expect(alert.title == "Can’t open “\(name)”")
            #expect(alert.message == message)
            #expect(alert.actions.map(\.title) == ["OK"])
            #expect(session.store.lists.open.isEmpty)
        }

        @Test
        func `a file that is gone shows the alert with the system reason`() async throws {
            let screen = await session.open(folder.appending(path: "gone.md"))

            #expect(screen == nil)
            let alert = try #require(presented.first as? UIAlertController)
            #expect(alert.title == "Can’t open “gone.md”")
            #expect(alert.message?.isEmpty == false)
        }

        @Test
        func `a new file is Untitled, then Untitled 2, in the app's folder`() async throws {
            let first = try #require(await session.newFile())
            let second = try #require(await session.newFile())

            #expect(first.document.fileURL.lastPathComponent == "Untitled.md")
            #expect(second.document.fileURL.lastPathComponent == "Untitled 2.md")
            #expect(first.document.fileURL.deletingLastPathComponent().standardizedFileURL
                == folder.standardizedFileURL)
            #expect(try Data(contentsOf: first.document.fileURL).isEmpty)
        }

        @Test
        func `a new file in a folder it cannot write shows the alert`() async {
            var environment = session.environment
            environment.appFolder = URL(filePath: "/System/none")
            let session = DocumentSession(store: FileListStore(defaults: defaults), environment: environment)
            session.alertHost = host

            #expect(await session.newFile() == nil)
            #expect(presented.count == 1)
        }

        @Test(.timeLimit(.minutes(1)))
        func `a renamed file keeps its screen and its row under the new name`() async throws {
            let url = try given("a.md")
            let screen = try #require(await session.open(url))
            let moved = folder.appending(path: "b.md")
            try FileManager.default.moveItem(at: url, to: moved)

            screen.document.presentedItemDidMove(to: moved)
            while session.screen(for: moved) == nil {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(session.screen(for: url) == nil)
            #expect(session.store.lists.open.map(\.url) == [FileListStore.key(moved)])
            #expect(screen.markdownView.documentURL == moved)
            #expect(await session.open(moved) === screen)
        }
    }
#endif
