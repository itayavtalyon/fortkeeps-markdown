#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// Relaunch (screens §3.17, D10; log 004 Round 6): every window keeps
    /// its place, its Lock, and its sidebar.
    @MainActor
    struct RelaunchMacTests {
        let base = DocumentWindowTests()
        static let lines = (1 ... 60).map { "line \($0)" }.joined(separator: "\n\n")
        /// Two sits mid-text, so the window can scroll it to the top at any height.
        static let text = "# One\n\n\(lines)\n\n# Two\n\n\(lines)\n"

        /// What the system keeps for the window when the app quits.
        static func encode(_ controller: DocumentWindowController) throws -> Data {
            let coder = NSKeyedArchiver(requiringSecureCoding: true)
            controller.encodeRestorableState(with: coder)
            coder.finishEncoding()
            return coder.encodedData
        }

        static func restore(_ data: Data, _ controller: DocumentWindowController) throws {
            let coder = try NSKeyedUnarchiver(forReadingFrom: data)
            controller.restoreState(with: coder)
        }

        /// Must-pass (plan 02 › 2f).
        @Test
        func `relaunch restores two documents with their anchors and Lock`() async throws {
            let first = try base.given("a.md", Self.text)
            let second = try base.given("b.md", Self.text)
            let (documentA, windowA) = try base.open(first)
            let (documentB, windowB) = try base.open(second)
            await windowA.markdownView.showOutlineItem(windowA.markdownView.loadOutline()[1])
            windowA.toggleLock(nil)
            // Not animated, so the place is read on the final layout; new windows show the sidebar.
            windowA.split.splitViewItems[0].isCollapsed = false
            windowB.markdownView.select(9 ..< 13)
            windowA.window?.layoutIfNeeded()
            let anchors = (windowA.markdownView.anchor, windowB.markdownView.anchor)
            let saved = try (Self.encode(windowA), Self.encode(windowB))
            documentA.close()
            documentB.close()

            // A opens hidden and is restored shown; B opens shown and is restored hidden.
            let (_, againA) = try base.open(first)
            ScrollSettings(defaults: base.spy.defaults).showsSidebar = true
            let (_, againB) = try base.open(second)
            try Self.restore(saved.0, againA)
            try Self.restore(saved.1, againB)

            #expect(againA.markdownView.anchor == anchors.0)
            #expect(againB.markdownView.anchor == anchors.1)
            #expect(anchors.0 != anchors.1)
            #expect(againA.markdownView.mode == .editorLocked)
            #expect(againB.markdownView.mode == .editor)
            #expect(!againA.split.splitViewItems[0].isCollapsed)
            #expect(againB.split.splitViewItems[0].isCollapsed)
            await againA.outlineTask?.value
            #expect(SidebarTests.rows(againA).prefix(3) == ["Outline", "One", "Two"])
        }

        @Test
        func `a window with nothing kept opens as it is`() throws {
            let (_, controller) = try base.open(base.given())

            try Self.restore(Self.encode(DocumentWindowController(
                document: ScrollDocument(), environment: base.spy.environment
            )), controller)
            try Self.restore(
                NSKeyedArchiver.archivedData(withRootObject: [String: Int](), requiringSecureCoding: true),
                controller
            )

            #expect(controller.markdownView.mode == .editor)
            #expect(controller.markdownView.anchor == .documentStart)
        }
    }
#endif
