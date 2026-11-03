#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Design log 004 › Outside changes: another app changes the file.
    extension DocumentViewControllerTests {
        func changeOnDisk(_ text: String, _ controller: DocumentViewController) throws {
            try Data(text.utf8).write(to: controller.document.fileURL)
            controller.document.noteChangeOnDisk()
        }

        /// Unsaved edits, then another app writes the file.
        func dialog() async throws -> (DocumentViewController, UIAlertController) {
            let controller = try await screen("- [ ] one\nb\n")
            controller.markdownView.replaceText("- [ ] one\nmine\n")
            try changeOnDisk("- [ ] one\nB\n", controller)
            return try (controller, #require(presented.last as? UIAlertController))
        }

        func disk(_ controller: DocumentViewController) throws -> String? {
            try String(bytes: Data(contentsOf: controller.document.fileURL), encoding: .utf8)
        }

        @Test
        func `an outside change with no edits reloads with the note, and its Undo restores the text`() async throws {
            let controller = try await screen("a\n")

            try changeOnDisk("b\n", controller)

            #expect(controller.markdownView.text == "b\n")
            #expect(controller.document.text == "b\n")
            #expect(!controller.document.hasUnsavedChanges)
            #expect(presented.isEmpty)
            #expect(strips(controller).map(\.accessibilityLabel) == ["Updated with changes from another app."])
            tapStrip("Undo", controller)
            #expect(controller.markdownView.text == "a\n")
            #expect(controller.document.hasUnsavedChanges)
            #expect(strips(controller).isEmpty)
        }

        @Test(.timeLimit(.minutes(2)))
        func `the file presenter hands a change to the screen`() async throws {
            let controller = try await screen("a\n")

            try Data("b\n".utf8).write(to: controller.document.fileURL)
            controller.document.presentedItemDidChange()

            while controller.markdownView.text != "b\n" {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test(.timeLimit(.minutes(2)))
        func `the note goes after its time, but not while the pointer is over it`() async throws {
            let controller = try await screen("a\n")
            controller.outside.noteDuration = .milliseconds(20)
            controller.outside.isPointerOver = true
            try changeOnDisk("b\n", controller)

            // Well past the time and the fade, even with the other tests on the main actor.
            try await Task.sleep(for: .seconds(2))
            #expect(!strips(controller).isEmpty)
            controller.noteHover(UIHoverGestureRecognizer())
            #expect(!controller.outside.isPointerOver)

            while !strips(controller).isEmpty {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test
        func `the file's own bytes, as last read or written, are not an outside change`() async throws {
            let controller = try await screen("a\n")

            controller.document.noteChangeOnDisk()
            try FileManager.default.removeItem(at: controller.document.fileURL)
            controller.document.noteChangeOnDisk()

            #expect(strips(controller).isEmpty)
        }

        /// Another app rewrote the file with CRLF: the bytes differ, the text does not.
        @Test
        func `new bytes with the same text show nothing`() async throws {
            let controller = try await screen("a\n")

            try changeOnDisk("a\r\n", controller)

            #expect(strips(controller).isEmpty)
            #expect(controller.markdownView.undoManager?.canUndo == false)
        }

        @Test
        func `an outside change with edits shows the dialog with no default and no cancel`() async throws {
            let (controller, alert) = try await dialog()

            #expect(alert.title == "“a.md” changed outside Scroll")
            #expect(alert.message
                == "Another app edited this file while you had unsaved changes. Choose which version to keep.")
            #expect(alert.actions.map(\.title) == ["Use version on disk", "Keep my changes", "Compare"])
            #expect(alert.actions.map(\.style) == [.destructive, .default, .default])
            #expect(alert.preferredAction == nil)
            #expect(!controller.markdownView.isEditable)
        }

        @Test
        func `a checkbox click while the dialog is visible changes no byte`() async throws {
            let (controller, _) = try await dialog()

            #expect(!controller.markdownView.controller.checkboxAccessibility(0).isEnabled)
            controller.document.apply(Self.change(.checkbox, "- [x] one\nmine\n"))
            _ = await ScrollDocumentIOSTests.autosaved(controller.document)

            #expect(try disk(controller) == "- [ ] one\nB\n")
        }

        @Test
        func `a second change while the dialog is up asks once`() async throws {
            let (controller, _) = try await dialog()

            try changeOnDisk("C\n", controller)

            #expect(presented.count == 1)
        }

        @Test
        func `using the version on disk loads its text and clears Undo`() async throws {
            let (controller, alert) = try await dialog()

            tap(alert.actions[0])

            #expect(controller.markdownView.text == "- [ ] one\nB\n")
            #expect(!controller.document.hasUnsavedChanges)
            #expect(controller.markdownView.undoManager?.canUndo == false)
            #expect(controller.markdownView.isEditable)
        }

        @Test
        func `keeping my changes writes them on the next autosave, and the status says so`() async throws {
            let (controller, alert) = try await dialog()

            tap(alert.actions[1])
            #expect(controller.markdownView.isEditable)
            #expect(await ScrollDocumentIOSTests.autosaved(controller.document))

            #expect(try disk(controller) == "- [ ] one\nmine\n")
            #expect(controller.statusText.hasSuffix(" · Saved your changes over the other version."))
            controller.markdownView.replaceText("- [ ] one\nmine 2\n")
            #expect(controller.statusText.hasSuffix(" · Saving…"))
            #expect(await ScrollDocumentIOSTests.autosaved(controller.document))
            #expect(controller.statusText.hasSuffix(" · Saved"))
        }

        /// Log 004 Round 7: the strip, with saves and edits paused.
        @Test
        func `bytes that are not text pause the document, and keep my changes writes the text back`() async throws {
            let controller = try await screen("a\n")

            try Data([0x61, 0xFF, 0x0A]).write(to: controller.document.fileURL)
            controller.document.noteChangeOnDisk()

            #expect(strips(controller).map(\.accessibilityLabel)
                == ["“a.md” changed outside Scroll and can’t be read as text."])
            #expect(!controller.markdownView.isEditable)
            #expect(controller.document.pausesSaves)
            #expect(presented.isEmpty)
            tapStrip("Keep my changes", controller)
            #expect(controller.markdownView.isEditable)
            #expect(await ScrollDocumentIOSTests.autosaved(controller.document))
            #expect(try disk(controller) == "a\n")
            #expect(controller.statusText.hasSuffix(" · Saved your changes over the other version."))
        }

        @Test
        func `close on the unreadable strip asks before the text goes`() async throws {
            let controller = try await screen("a\n")
            try Data([0x00]).write(to: controller.document.fileURL)
            controller.document.noteChangeOnDisk()

            tapStrip("Close", controller)

            let alert = try #require(presented.last as? UIAlertController)
            #expect(alert.title == "Close without saving? The text will be lost.")
        }

        @Test
        func `the compare view's Apply writes once, and its Undo restores the text from before`() async throws {
            let (controller, alert) = try await dialog()

            tap(alert.actions[2])
            let compare = try #require(presented.last as? UINavigationController)
            #expect(compare.modalPresentationStyle == .fullScreen)
            #expect(compare.topViewController?.title == "Compare versions of “a.md”")
            let resolve = try #require(controller.outside.resolveView)
            #expect(compare.topViewController?.view === resolve)
            #expect(resolve.changeRows[0].panes.map(\.title) == ["Your Changes", "On Disk"])
            resolve.controller.choose(.theirs, change: 0)
            resolve.applyButton.sendActions(for: .primaryActionTriggered)

            #expect(controller.outside.resolveView == nil)
            #expect(controller.markdownView.isEditable)
            #expect(controller.markdownView.text == "- [ ] one\nB\n")
            #expect(await ScrollDocumentIOSTests.autosaved(controller.document))
            #expect(try disk(controller) == "- [ ] one\nB\n")
            #expect(controller.markdownView.undoManager?.undoActionName == "Resolve")
            controller.markdownView.undoManager?.undo()
            #expect(controller.markdownView.text == "- [ ] one\nmine\n")
        }

        @Test
        func `the compare view's Cancel writes nothing and shows the dialog again`() async throws {
            let (controller, alert) = try await dialog()

            tap(alert.actions[2])
            try #require(controller.outside.resolveView).cancelButton.sendActions(for: .primaryActionTriggered)
            _ = await ScrollDocumentIOSTests.autosaved(controller.document)

            #expect(controller.outside.resolveView == nil)
            #expect(presented.compactMap { $0 as? UIAlertController }.count == 2)
            #expect(!controller.markdownView.isEditable)
            #expect(try disk(controller) == "- [ ] one\nB\n")
        }

        /// The text saved, then typed on: the saved bytes are the screen's own.
        @Test
        func `a save of the screen's own text, typed on since, is no outside change`() async throws {
            let controller = try await screen("a\n")
            controller.markdownView.replaceText("b\n")
            #expect(await ScrollDocumentIOSTests.autosaved(controller.document))
            controller.markdownView.replaceText("c\n")

            controller.document.noteChangeOnDisk()

            #expect(presented.isEmpty)
        }

        @Test
        func `after a choice, the next outside change with edits asks again`() async throws {
            let (controller, alert) = try await dialog()
            tap(alert.actions[0])
            controller.markdownView.replaceText("mine again\n")

            try changeOnDisk("C\n", controller)

            #expect(presented.count == 2)
        }

        @Test
        func `a second reload stops the first note's timer`() async throws {
            let controller = try await screen("a\n")
            try changeOnDisk("b\n", controller)
            let first = controller.outside.noteTask

            try changeOnDisk("c\n", controller)

            #expect(first?.isCancelled == true)
        }

        /// Unsaved edits, and the presenter calls with the file as it was read.
        @Test
        func `the file as it was read is no outside change, even with edits`() async throws {
            let controller = try await screen("a\n")
            controller.markdownView.replaceText("b\n")

            controller.document.noteChangeOnDisk()

            #expect(presented.isEmpty)
            #expect(controller.markdownView.text == "b\n")
            #expect(strips(controller).isEmpty)
        }
    }
#endif
