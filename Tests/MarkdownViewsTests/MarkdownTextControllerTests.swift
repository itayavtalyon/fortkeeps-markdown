import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design › Host interface, Modes, Tasks, Links, Images, Undo: the shared view
/// behavior, driven through the controller with a recording host.
@MainActor
struct MarkdownTextControllerTests {
    static let documentURL = URL(fileURLWithPath: "/Users/me/notes/doc.md")

    static func givenController(
        _ text: String,
        mode: MarkdownMode = .editor,
        features: MarkdownFeatures = MarkdownFeatures(),
        maxUTF8Bytes: Int? = nil
    ) -> (MarkdownTextController, RecordingHost) {
        let host = RecordingHost()
        let controller = MarkdownTextController(
            text: text,
            features: features,
            presentation: MarkdownPresentation(),
            mode: mode,
            maxUTF8Bytes: maxUTF8Bytes,
            documentURL: documentURL
        )
        controller.host = host
        return (controller, host)
    }

    // MARK: links

    @Test
    func `a Command-click in the editor opens the link`() {
        let (controller, host) = Self.givenController("see [site](https://e.com/x)")

        controller.click(atDisplayOffset: 6, modifiers: .command)

        #expect(host.opened.map(\.destination) == ["https://e.com/x"])
        #expect(host.opened.first?.resolvedURL == URL(string: "https://e.com/x"))
        #expect(host.opened.first?.modifiers == .command)
        #expect(host.opened.first?.source == .markdown)
    }

    @Test
    func `a plain click in the editor opens nothing`() {
        let (controller, host) = Self.givenController("see [site](https://e.com/x)")

        controller.click(atDisplayOffset: 6, modifiers: [])

        #expect(host.opened.isEmpty)
    }

    @Test(arguments: [MarkdownMode.editorLocked, .rendered])
    func `a click opens the link in the locked editor and in rendered mode`(mode: MarkdownMode) {
        let (controller, host) = Self.givenController("see [site](other.md)", mode: mode)
        let offset = mode == .rendered ? 5 : 6

        controller.click(atDisplayOffset: offset, modifiers: [])

        #expect(host.opened.map(\.destination) == ["other.md"])
        #expect(host.opened.first?.resolvedURL == URL(fileURLWithPath: "/Users/me/notes/other.md"))
    }

    @Test
    func `a click outside any link opens nothing`() {
        let (controller, host) = Self.givenController("plain [site](https://e.com)", mode: .rendered)

        controller.click(atDisplayOffset: 1, modifiers: [])

        #expect(host.opened.isEmpty)
    }

    // MARK: checkboxes

    @Test(arguments: [MarkdownMode.editor, .rendered])
    func `a checkbox click flips the byte and reports checkbox`(mode: MarkdownMode) {
        let (controller, host) = Self.givenController("- [ ] task\n", mode: mode)

        controller.toggleTask(0)

        #expect(controller.text == "- [x] task\n")
        #expect(host.changes.map(\.reason) == [.checkbox])
        #expect(host.changes.first?.range == NSRange(location: 3, length: 1))
        #expect(host.changes.first?.replacement == "x")
        #expect(host.changes.first?.text == "- [x] task\n")
    }

    @Test
    func `in the locked editor a checkbox is not enabled and a click changes nothing`() {
        let (controller, host) = Self.givenController("- [ ] task\n", mode: .editorLocked)

        controller.toggleTask(0)

        #expect(controller.checkboxAccessibility(0).isEnabled == false)
        #expect(controller.text == "- [ ] task\n")
        #expect(host.changes.isEmpty)
    }

    @Test
    func `while not editable a checkbox is not enabled`() {
        let (controller, _) = Self.givenController("- [ ] task\n")

        controller.isEditable = false

        #expect(controller.checkboxAccessibility(0).isEnabled == false)
    }

    @Test
    func `the checkbox accessibility value is done or not done and its label is the task text`() {
        let (controller, _) = Self.givenController("- [x] one\n- [ ] two\n")

        #expect(controller.checkboxAccessibility(0).value == "done")
        #expect(controller.checkboxAccessibility(1).value == "not done")
        #expect(controller.checkboxAccessibility(1).label == "two")
        #expect(controller.checkboxAccessibility(0).isEnabled)
    }

    @Test
    func `a checkbox click is one undo group and undo reports undo`() {
        let (controller, host) = Self.givenController("- [ ] task\n")

        controller.toggleTask(0)
        controller.undoManager.undo()

        #expect(controller.text == "- [ ] task\n")
        #expect(host.changes.map(\.reason) == [.checkbox, .undo])
    }

    @Test
    func `redo reports redo`() {
        let (controller, host) = Self.givenController("- [ ] task\n")

        controller.toggleTask(0)
        controller.undoManager.undo()
        controller.undoManager.redo()

        #expect(controller.text == "- [x] task\n")
        #expect(host.changes.map(\.reason) == [.checkbox, .undo, .redo])
    }

    // MARK: edits

    @Test
    func `a typed edit reports edit with the range before the change`() {
        let (controller, host) = Self.givenController("ab")

        controller.textViewDidReplace(1 ..< 1, with: "X", event: .typed("X"), at: 0)

        #expect(controller.text == "aXb")
        #expect(host.changes.first == TextChange(
            reason: .edit,
            range: NSRange(location: 1, length: 0),
            replacement: "X",
            text: "aXb"
        ))
    }

    @Test
    func `undo puts the caret at the end of the restored text`() {
        let (controller, _) = Self.givenController("ab cd")
        controller.selection = 5 ..< 5
        controller.textViewDidReplace(5 ..< 5, with: "!", event: .typed("!"), at: 0)
        controller.selection = 6 ..< 6
        controller.textViewDidReplace(0 ..< 2, with: "XYZ", event: .paste, at: 0)

        controller.undoManager.undo()
        #expect(controller.selection == 2 ..< 2)
        controller.undoManager.undo()
        #expect(controller.selection == 5 ..< 5)
    }

    @Test
    func `a cut insertion applies the kept prefix, moves the caret, and redraws`() {
        let (controller, host) = Self.givenController("ab", maxUTF8Bytes: 4)
        var redraws = 0
        controller.onDisplayChange = { redraws += 1 }

        controller.replaceCut(2 ..< 2, with: "cd", event: .typed("cdef"), at: 0)

        #expect(controller.text == "abcd")
        #expect(controller.selection == 4 ..< 4)
        #expect(redraws == 1)
        #expect(host.changes.map(\.replacement) == ["cd"])
    }

    @Test
    func `typing with a pause after whitespace makes two undo groups`() {
        let (controller, _) = Self.givenController("")
        for (index, character) in "hello ".enumerated() {
            controller.textViewDidReplace(
                index ..< index,
                with: String(character),
                event: .typed(String(character)),
                at: Double(index) / 10
            )
        }
        for (index, character) in "world".enumerated() {
            controller.textViewDidReplace(
                6 + index ..< 6 + index,
                with: String(character),
                event: .typed(String(character)),
                at: 1.6 + Double(index) / 10
            )
        }

        controller.undoManager.undo()

        #expect(controller.text == "hello ")
    }

    @Test
    func `the byte limit cuts an insertion and keeps one undo group`() {
        let (controller, _) = Self.givenController("abc", maxUTF8Bytes: 5)

        let kept = controller.allowedReplacement(for: 3 ..< 3, proposed: "defgh")
        controller.textViewDidReplace(3 ..< 3, with: kept, event: .paste, at: 0)
        controller.undoManager.undo()

        #expect(kept == "de")
        #expect(controller.text == "abc")
    }

    @Test
    func `pressing Return in a list item continues the list as one edit`() {
        let (controller, host) = Self.givenController("- [x] a")
        controller.selection = 7 ..< 7

        #expect(controller.pressReturn())
        #expect(controller.text == "- [x] a\n- [ ] ")
        #expect(controller.selection == 14 ..< 14)
        #expect(host.changes.map(\.reason) == [.edit])
    }

    @Test
    func `pressing Return outside a list leaves it to the text view`() {
        let (controller, host) = Self.givenController("plain")
        controller.selection = 5 ..< 5

        #expect(!controller.pressReturn())
        #expect(host.changes.isEmpty)
    }

    @Test
    func `a format command applies its edit and selection and reports edit`() {
        let (controller, host) = Self.givenController("a word b")
        controller.selection = 2 ..< 6

        controller.perform(.bold)

        #expect(controller.text == "a **word** b")
        #expect(controller.selection == 4 ..< 8)
        #expect(host.changes.map(\.reason) == [.edit])
    }

    @Test(arguments: [MarkdownMode.rendered, .editorLocked])
    func `a format command does nothing where the text cannot change`(mode: MarkdownMode) {
        let (controller, host) = Self.givenController("a word b", mode: mode)
        controller.selection = 2 ..< 6

        controller.perform(.bold)

        #expect(controller.text == "a word b")
        #expect(host.changes.isEmpty)
    }

    // MARK: reload

    @Test
    func `reload replaces the text, clears undo, and reports reload`() {
        let (controller, host) = Self.givenController("- [ ] a\n")
        controller.toggleTask(0)

        controller.reload(text: "new\n")

        #expect(controller.text == "new\n")
        #expect(!controller.undoManager.canUndo)
        #expect(host.changes.last == TextChange(
            reason: .reload,
            range: NSRange(location: 0, length: 8),
            replacement: "new\n",
            text: "new\n"
        ))
    }
}
