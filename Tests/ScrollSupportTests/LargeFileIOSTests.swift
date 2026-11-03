#if os(iOS)
    import Foundation
    import MarkdownCore
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Large files on iOS (screens §3.14; log 004 Round 6): any size opens;
    /// above 5 MB the screen shows its progress while the file loads.
    extension DocumentSessionTests {
        /// One code block: cheap to style, so the test is about the open.
        static func text(bytes: Int) -> String {
            "```\n" + String(repeating: "0123456789abcdef\n", count: bytes / 17) + "```\n"
        }

        /// Must-pass (plan 02 › 2f), on iOS.
        @Test
        func `a file larger than 64 KiB opens at once`() async throws {
            let text = Self.text(bytes: 100_000)

            let screen = try #require(await session.open(given("big.md", Array(text.utf8))))

            #expect(screen.markdownView.text == text)
            #expect(screen.largeLoad == nil)
        }

        @Test(.timeLimit(.minutes(2)))
        func `a screen closed while its large file loads styles nothing`() async throws {
            let url = try given("big.md", Array(Self.text(bytes: 6_000_000).utf8))
            let screen = try #require(await session.open(url))

            await session.close(url)
            await screen.largeLoadTask?.value

            #expect(screen.markdownView.text.isEmpty)
        }

        /// Must-pass (plan 02 › 2f), on iOS.
        @Test(.timeLimit(.minutes(2)))
        func `a 6 MB file shows the screen with its progress, then its text, ready to edit`() async throws {
            let text = Self.text(bytes: 6_000_000)
            let url = try given("big.md", Array(text.utf8))
            let kept = MarkdownAnchor(block: 0, offsetInBlock: 0, selection: 500 ..< 500)
            session.store.keep(FileListStore.Place(anchor: kept, locked: false), for: url)

            let screen = try await shown(session.open(url))
            let load = try #require(screen.largeLoad)
            #expect(load.label.text == "Opening “big.md”…")
            #expect(screen.markdownView.isHidden)
            #expect(screen.markdownView.text.isEmpty)

            await screen.largeLoadTask?.value

            #expect(load.wasShown)
            #expect(load.bar.progress == 1)
            #expect(load.superview == nil)
            #expect(screen.largeLoad == nil)
            #expect(!screen.markdownView.isHidden)
            #expect(screen.markdownView.text == text)
            #expect(screen.markdownView.mode == .editor)
            #expect(screen.markdownView.undoManager?.canUndo == false)
            screen.view.layoutIfNeeded()
            #expect(screen.markdownView.anchor.selection == 500 ..< 500)
        }

        @Test(.timeLimit(.minutes(2)))
        func `a large file that is not UTF-8 is refused, and its screen closes`() async throws {
            var bytes = Array(Self.text(bytes: 6_000_000).utf8)
            bytes[10] = 0xFF
            let url = try given("big.md", bytes)

            let screen = try #require(await session.open(url))
            await screen.largeLoadTask?.value

            #expect((presented.last as? UIAlertController)?.title == "Can’t open “big.md”")
            #expect(session.screen(for: url) == nil)
        }
    }
#endif
