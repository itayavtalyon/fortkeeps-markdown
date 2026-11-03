#if os(macOS)
    import AppKit
    import MarkdownCore
    @testable import MarkdownViews
    import Testing

    /// Design log 004 › Outside changes: the view side of the undoable reload
    /// and of Resolve Apply.
    extension MarkdownViewMacTests {
        @Test
        func `an undoable reload shows the new text with the caret on its text, and Undo restores it`() {
            let view = Self.givenView("a\nb\nc\n")
            view.textView.setSelectedRange(NSRange(location: 4, length: 0))

            view.reload(text: "a\nB2\nc\n", undoActionName: "Reload")

            #expect(view.textView.string == "a\nB2\nc\n")
            #expect(view.textView.selectedRange() == NSRange(location: 5, length: 0))
            #expect(view.controller.undoManager.undoActionName == "Reload")
            view.controller.undoManager.undo()
            #expect(view.text == "a\nb\nc\n")
        }

        @Test
        func `replacing the text shows it and is one undo group`() {
            let view = Self.givenView("a\nb\n")

            view.replaceText("a\nc\nb\n")

            #expect(view.textView.string == "a\nc\nb\n")
            view.controller.undoManager.undo()
            #expect(view.textView.string == "a\nb\n")
        }

        /// A moved file: links and images resolve against its new folder.
        @Test
        func `the host can move the document's base`() {
            let view = Self.givenView("a\n")
            let moved = URL(filePath: "/tmp/Moved/a.md")

            view.documentURL = moved

            #expect(view.documentURL == moved)
            #expect(view.controller.documentURL == moved)
        }

        /// A host's own Undo button, such as the reload note's, undoes the view's groups.
        @Test
        func `the view's undo manager is its own`() {
            let view = Self.givenView("a\n")

            #expect(view.undoManager === view.controller.undoManager)
        }
    }
#endif
