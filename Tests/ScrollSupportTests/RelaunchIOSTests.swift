#if os(iOS)
    import Foundation
    import MarkdownCore
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Relaunch (plan 02 › 2f; log 001 Q14): each open file comes back with its
    /// place in the text and its Lock.
    extension DocumentSessionTests {
        /// The screen in a window under a nav bar, laid out, as the app shows it.
        func shown(_ screen: DocumentViewController?) throws -> DocumentViewController {
            let screen = try #require(screen)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
            window.rootViewController = UINavigationController(rootViewController: screen)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            windows.append(window)
            return screen
        }

        /// Must-pass (plan 02 › 2f), on iOS.
        @Test
        func `a relaunch restores two documents with their places and Lock`() async throws {
            let lines = (1 ... 80).map { "line \($0)" }.joined(separator: "\n\n")
            let text = "# One\n\n\(lines)\n\n# Two\n\n\(lines)\n"
            let first = try given("a.md", Array(text.utf8))
            let second = try given("b.md", Array(text.utf8))
            let screenA = try await shown(session.open(first))
            let screenB = try await shown(session.open(second))
            let two = (text as NSString).range(of: "# Two").location
            try await screenA.markdownView.showOutlineItem(#require(screenA.markdownView.loadOutline().last))
            screenB.toggleLock()
            let placeA = screenA.markdownView.anchor
            #expect(placeA.block == two)
            session.keepPlaces()

            let relaunched = DocumentSession(store: FileListStore(defaults: defaults), environment: session.environment)
            #expect(relaunched.store.lists.open.map(\.url) == [first, second].map(FileListStore.key))
            let againA = try await shown(relaunched.open(first))
            let againB = try await shown(relaunched.open(second))

            #expect(againA.markdownView.anchor == placeA)
            #expect(againA.markdownView.anchor.block == two)
            #expect(againA.markdownView.mode == .editor)
            #expect(againB.markdownView.mode == .editorLocked)
            #expect(againB.markdownView.anchor.block == 0)
        }

        /// An iPad tab not yet shown since the relaunch, or a large file still loading.
        @Test
        func `a screen not yet laid out keeps the place it was given`() async throws {
            let url = try given("a.md", Array("# A\n\nb\n".utf8))
            let screen = try #require(await session.open(url))
            let place = FileListStore.Place(
                anchor: MarkdownAnchor(block: 5, offsetInBlock: 0, selection: 5 ..< 5),
                locked: false
            )

            screen.restore(place)

            #expect(screen.place == place)
        }

        @Test
        func `closing a file keeps its place for the next open`() async throws {
            let url = try given("a.md", Array("# A\n\nb\n".utf8))
            try await shown(session.open(url)).toggleLock()

            await session.close(url)

            #expect(try await shown(session.open(url)).markdownView.mode == .editorLocked)
        }

        @Test
        func `the iPad reopens the open files as tabs`() async throws {
            let first = try given("a.md")
            let second = try given("b.md")
            _ = await session.open(first)
            _ = await session.open(second)
            let relaunched = DocumentSession(store: FileListStore(defaults: defaults), environment: session.environment)
            let browser = BrowserViewController(session: relaunched)

            await browser.reopen()

            #expect(browser.tabs.tabs.map(\.document.fileName) == ["a.md", "b.md"])
            #expect(browser.tabs.selected?.startsTyping == false)
        }
    }
#endif
