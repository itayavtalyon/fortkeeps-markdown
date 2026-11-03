#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// Large files (screens §3.14; log 004 Round 6): any size opens; above
    /// 5 MB the window shows its progress while the file loads.
    @MainActor
    struct LargeFileMacTests {
        let base = DocumentWindowTests()

        /// One code block: cheap to style, so the test is about the open.
        static func text(bytes: Int) -> String {
            "```\n" + String(repeating: "0123456789abcdef\n", count: bytes / 17) + "```\n"
        }

        /// Must-pass (plan 02 › 2f).
        @Test
        func `a file larger than 64 KiB opens at once`() throws {
            let text = Self.text(bytes: 100_000)
            let (document, controller) = try base.open(base.given("big.md", text))

            #expect(document.text == text)
            #expect(controller.markdownView.text == text)
            #expect(controller.largeLoad == nil)
        }

        /// Must-pass (plan 02 › 2f).
        @Test(.timeLimit(.minutes(2)))
        func `a 6 MB file shows the progress, then its text, ready to edit`() async throws {
            ScrollSettings(defaults: base.spy.defaults).showsSidebar = true
            let text = "# Big\n\n" + Self.text(bytes: 6_000_000)
            let (document, controller) = try base.open(base.given("big.md", text))
            let opening = controller.outlineTask
            let load = try #require(controller.largeLoad)
            #expect(load.label.stringValue == "Opening “big.md”…")
            #expect(!load.indicator.isIndeterminate)
            #expect(controller.markdownView.isHidden)
            #expect(throws: (any Error).self) { try document.data(ofType: ScrollDocument.typeName) }
            document.noteChangeOnDisk()
            #expect(!controller.outside.showsNote)

            await controller.largeLoadTask?.value

            #expect(load.wasShown)
            #expect(load.indicator.doubleValue == 1)
            #expect(controller.largeLoad == nil)
            #expect(load.view.superview == nil)
            #expect(!controller.markdownView.isHidden)
            #expect(controller.markdownView.text == text)
            #expect(document.text == text)
            #expect(controller.markdownView.mode == .editor)
            #expect(controller.markdownView.undoManager?.canUndo == false)
            // The reload of the text loads the Outline again.
            #expect(controller.outlineTask != opening)
            await controller.outlineTask?.value
            #expect(SidebarTests.rows(controller).prefix(2) == ["Outline", "Big"])
        }

        @Test(.timeLimit(.minutes(2)))
        func `a window closed while its large file loads styles nothing`() async throws {
            let (document, controller) = try base.open(base.given("big.md", Self.text(bytes: 6_000_000)))

            document.close()
            await controller.largeLoadTask?.value

            #expect(controller.markdownView.text.isEmpty)
        }

        @Test(.timeLimit(.minutes(2)))
        func `a large file that is not UTF-8 is refused, and its window closes`() async throws {
            var bytes = Data(Self.text(bytes: 6_000_000).utf8)
            bytes[10] = 0xFF
            let url = try base.given("big.md")
            try bytes.write(to: url)
            base.spy.response = .alertFirstButtonReturn
            let (document, controller) = try base.open(url)

            await controller.largeLoadTask?.value

            #expect(base.spy.alerts == ["Can’t Open “big.md”"])
            #expect(document.windowControllers.isEmpty)
        }
    }
#endif
