#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// Design log 004 › Outside changes: another app changes the file.
    extension DocumentWindowTests {
        static let note = "Updated with changes from another app."

        func changeOnDisk(_ url: URL, _ text: String, _ document: ScrollDocument) throws {
            try Data(text.utf8).write(to: url)
            document.noteChangeOnDisk()
        }

        /// Open with unsaved edits, then another app writes `disk`.
        func dialog() throws -> (ScrollDocument, DocumentWindowController) {
            let url = try given("a.md", "- [ ] one\nb\n")
            let (document, controller) = try open(url)
            controller.markdownView.replaceText("- [ ] one\nmine\n")
            try changeOnDisk(url, "- [ ] one\nB\n", document)
            return (document, controller)
        }

        func disk(_ document: ScrollDocument) throws -> Data {
            try Data(contentsOf: #require(document.fileURL))
        }

        @Test
        func `an outside change with no edits reloads with the note, and its Undo restores the text`() throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)

            try changeOnDisk(url, "b\n", document)

            #expect(controller.markdownView.text == "b\n")
            #expect(document.text == "b\n")
            #expect(!document.isDocumentEdited)
            #expect(spy.alerts.isEmpty)
            #expect(Self.texts(controller).contains(Self.note))
            #expect(controller.markdownView.undoManager?.undoActionName == "Reload")
            try #require(Self.button("Undo", in: controller.window?.contentView)).performClick(nil)
            #expect(controller.markdownView.text == "a\n")
            #expect(document.isDocumentEdited)
            #expect(!Self.texts(controller).contains(Self.note))
        }

        @Test(.timeLimit(.minutes(2)))
        func `the file presenter hands a change to the window`() async throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)

            try Data("b\n".utf8).write(to: url)
            document.presentedItemDidChange()

            while controller.markdownView.text != "b\n" {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test(.timeLimit(.minutes(2)))
        func `the note goes after its time, but not while the pointer is over it`() async throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            controller.outside.noteDuration = .milliseconds(20)
            var overs = 0
            controller.outside.isPointerOver = { _ in
                overs += 1
                return overs == 1
            }

            try changeOnDisk(url, "b\n", document)
            while Self.texts(controller).contains(Self.note) {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(overs == 2)
        }

        @Test
        func `the pointer test finds no note when there is none, and no pointer over an empty view`() throws {
            let (_, controller) = try open(given())

            #expect(!controller.isPointerOverNote())
            let empty = NSView()
            #expect(!controller.outside.isPointerOver(empty))
            controller.window?.contentView?.addSubview(empty)
            #expect(!controller.outside.isPointerOver(empty))
        }

        @Test
        func `a typed edit takes the note away`() throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            try changeOnDisk(url, "b\n", document)

            controller.markdownView.replaceText("c\n")

            #expect(!Self.texts(controller).contains(Self.note))
        }

        @Test
        func `the file's own bytes, as last read or written, are not an outside change`() throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)

            document.noteChangeOnDisk()
            try FileManager.default.removeItem(at: url)
            document.noteChangeOnDisk()

            #expect(!Self.texts(controller).contains(Self.note))
            #expect(controller.markdownView.undoManager?.canUndo == false)
        }

        /// Another app rewrote the file with CRLF: the bytes differ, the text does not.
        @Test
        func `new bytes with the same text show nothing and keep Undo as it was`() throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            controller.markdownView.replaceText("b\n")

            try changeOnDisk(url, "b\r\n", document)

            #expect(!Self.texts(controller).contains(Self.note))
            #expect(spy.alerts.isEmpty)
            #expect(controller.markdownView.undoManager?.undoActionName != "Reload")
        }

        @Test
        func `an outside change with edits shows the dialog; Return and Esc do nothing`() throws {
            let (_, controller) = try dialog()

            let alert = try #require(spy.alert)
            #expect(alert.messageText == "“a.md” changed outside Scroll")
            #expect(alert.informativeText
                == "Another app edited this file while you had unsaved changes. Choose which version to keep.")
            #expect(alert.buttons.map(\.title) == ["Use Version on Disk", "Keep My Changes", "Compare…"])
            #expect(alert.buttons.map { $0.accessibilityHelp() } == [
                "Replaces your changes with the other app's version and clears Undo.",
                "Saves your version over the other app's.",
                "Shows both versions so you can choose each change."
            ])
            // The window laid the alert out; another layout would choose a first button again.
            #expect(alert.window.initialFirstResponder === alert.window.contentView)
            #expect(alert.buttons.map(\.keyEquivalent) == ["", "", ""])
            // Focus starts on no button, so Space cannot choose either.
            for key in ["\r", "\u{1b}"] {
                let event = try #require(NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                    context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0
                ))
                #expect(!alert.window.performKeyEquivalent(with: event))
            }
            #expect(!controller.markdownView.isEditable)
        }

        @Test(.timeLimit(.minutes(2)))
        func `a checkbox click while the dialog is visible changes no byte`() async throws {
            let (document, controller) = try dialog()

            #expect(!controller.markdownView.controller.checkboxAccessibility(0).isEnabled)
            document.apply(TextChange(
                reason: .checkbox, groupReason: .checkbox, range: NSRange(), replacement: "", text: "- [x] one\nmine\n"
            ))
            try await document.autosave(withImplicitCancellability: false)

            #expect(try disk(document) == Data("- [ ] one\nB\n".utf8))
        }

        @Test
        func `a second change while the dialog is up asks once`() throws {
            let (document, _) = try dialog()

            try changeOnDisk(#require(document.fileURL), "C\n", document)

            #expect(spy.alerts.count == 1)
        }

        @Test
        func `using the version on disk loads its text and clears Undo`() throws {
            let (document, controller) = try dialog()

            spy.answer?(.alertFirstButtonReturn)

            #expect(controller.markdownView.text == "- [ ] one\nB\n")
            #expect(document.text == "- [ ] one\nB\n")
            #expect(!document.isDocumentEdited)
            #expect(controller.markdownView.undoManager?.canUndo == false)
            #expect(controller.markdownView.isEditable)
        }

        @Test(.timeLimit(.minutes(2)))
        func `keeping my changes writes them on the next autosave, and the status says so`() async throws {
            let (document, controller) = try dialog()

            spy.answer?(.alertSecondButtonReturn)
            #expect(controller.markdownView.isEditable)
            #expect(Self.texts(controller).contains("Saved · 2 words"))
            try await document.autosave(withImplicitCancellability: false)

            #expect(try disk(document) == Data("- [ ] one\nmine\n".utf8))
            #expect(Self.texts(controller).contains("Saved your changes over the other version. · 2 words"))
            controller.markdownView.replaceText("- [ ] one\nmine 2\n")
            #expect(Self.texts(controller).contains("Saved · 3 words"))
        }

        /// Log 004 Round 7: the strip, with saves and edits paused.
        @Test(.timeLimit(.minutes(2)))
        func `bytes that are not text pause the document, and Keep My Changes writes the text back`() async throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)

            try Data([0x61, 0xFF, 0x0A]).write(to: url)
            document.noteChangeOnDisk()

            #expect(Self.texts(controller).contains("“a.md” changed outside Scroll and can’t be read as text."))
            #expect(!controller.markdownView.isEditable)
            #expect(document.pausesSaves)
            #expect(spy.alerts.isEmpty)
            try #require(Self.button("Keep My Changes", in: controller.window?.contentView)).performClick(nil)
            #expect(controller.markdownView.isEditable)
            #expect(!document.pausesSaves)
            try await document.autosave(withImplicitCancellability: false)
            #expect(try disk(document) == Data("a\n".utf8))
            #expect(Self.texts(controller).contains("Saved your changes over the other version. · 1 word"))
        }

        @Test
        func `text written after unreadable bytes follows the usual rules`() throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            try Data([0x00]).write(to: url)
            document.noteChangeOnDisk()

            try changeOnDisk(url, "b\n", document)

            #expect(controller.markdownView.text == "b\n")
            #expect(controller.markdownView.isEditable)
            #expect(!document.pausesSaves)
            #expect(!controller.outside.isUnreadable)
        }

        @Test(.timeLimit(.minutes(2)))
        func `the compare view's Apply writes once, and its Undo restores the text from before`() async throws {
            let (document, controller) = try dialog()

            spy.answer?(.alertThirdButtonReturn)
            let resolve = try #require(controller.outside.resolveView)
            #expect(controller.window?.title == "Compare versions of “a.md”")
            #expect(resolve.changeRows[0].panes.map(\.title) == ["Your Changes", "On Disk"])
            #expect(controller.markdownView.isHidden)
            #expect(controller.window?.firstResponder === resolve)
            resolve.controller.choose(.theirs, change: 0)
            resolve.applyButton.performClick(nil)

            #expect(controller.outside.resolveView == nil)
            #expect(!Self.contains(ResolveView.self, in: controller.window?.contentView))
            #expect(controller.window?.title == "a.md")
            #expect(!controller.markdownView.isHidden)
            #expect(controller.markdownView.isEditable)
            #expect(controller.markdownView.text == "- [ ] one\nB\n")
            try await document.autosave(withImplicitCancellability: false)
            #expect(try disk(document) == Data("- [ ] one\nB\n".utf8))
            #expect(controller.markdownView.undoManager?.undoActionName == "Resolve")
            controller.markdownView.undoManager?.undo()
            #expect(controller.markdownView.text == "- [ ] one\nmine\n")
        }

        @Test(.timeLimit(.minutes(2)))
        func `the compare view's Cancel writes nothing and shows the dialog again`() async throws {
            let (document, controller) = try dialog()

            spy.answer?(.alertThirdButtonReturn)
            try #require(controller.outside.resolveView).cancelButton.performClick(nil)
            try await document.autosave(withImplicitCancellability: false)

            #expect(controller.outside.resolveView == nil)
            #expect(spy.alerts.count == 2)
            #expect(controller.window?.title == "a.md")
            #expect(!controller.markdownView.isEditable)
            #expect(controller.markdownView.text == "- [ ] one\nmine\n")
            #expect(try disk(document) == Data("- [ ] one\nB\n".utf8))
        }

        static func contains(_ type: NSView.Type, in view: NSView?) -> Bool {
            (view?.subviews ?? []).contains { $0.isKind(of: type) || contains(type, in: $0) }
        }

        /// The text saved, then typed on: the saved bytes are the window's own.
        @Test(.timeLimit(.minutes(2)))
        func `a save of the window's own text, typed on since, is no outside change`() async throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            controller.markdownView.replaceText("b\n")
            try await document.autosave(withImplicitCancellability: false)
            controller.markdownView.replaceText("c\n")

            document.noteChangeOnDisk()

            #expect(spy.alerts.isEmpty)
        }

        @Test
        func `after a choice, the next outside change with edits asks again`() throws {
            let (document, controller) = try dialog()
            spy.answer?(.alertFirstButtonReturn)
            controller.markdownView.replaceText("mine again\n")

            try changeOnDisk(#require(document.fileURL), "C\n", document)

            #expect(spy.alerts.count == 2)
        }

        @Test
        func `a second reload stops the first note's timer`() throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            try changeOnDisk(url, "b\n", document)
            let first = controller.outside.noteTask

            try changeOnDisk(url, "c\n", document)

            #expect(first?.isCancelled == true)
        }

        /// A rename moves the base of relative links and images (log 004 Round 5).
        @Test(.timeLimit(.minutes(2)))
        func `a moved file moves the text's base`() async throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            let moved = folder.appending(path: "b.md")
            try FileManager.default.moveItem(at: url, to: moved)

            document.presentedItemDidMove(to: moved)

            while controller.markdownView.documentURL != moved {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
    }
#endif
