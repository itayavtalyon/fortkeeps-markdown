import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design log 004 › Outside changes: the undoable reload and Resolve Apply.
extension MarkdownTextControllerTests {
    @Test
    func `an undoable reload replaces only the changed span, keeps the caret, and reports reload`() {
        let (controller, host) = Self.givenController("a\nb\nc\n")
        controller.selection = 4 ..< 4

        controller.reload(text: "a\nB2\nc\n", undoActionName: "Reload")

        #expect(controller.text == "a\nB2\nc\n")
        #expect(controller.selection == 5 ..< 5)
        #expect(host.changes.last == TextChange(
            reason: .reload,
            groupReason: .reload,
            range: NSRange(location: 2, length: 1),
            replacement: "B2",
            text: "a\nB2\nc\n"
        ))
        #expect(controller.undoManager.undoActionName == "Reload")
    }

    @Test
    func `undo and redo of an undoable reload carry the reload group reason`() {
        let (controller, host) = Self.givenController("a\nb\n")
        controller.reload(text: "a\nc\n", undoActionName: "Reload")

        controller.undoManager.undo()
        #expect(controller.text == "a\nb\n")
        #expect(host.changes.last?.reason == .undo)
        #expect(host.changes.last?.groupReason == .reload)
        #expect(controller.undoManager.redoActionName == "Reload")

        controller.undoManager.redo()
        #expect(controller.text == "a\nc\n")
        #expect(host.changes.last?.reason == .redo)
        #expect(host.changes.last?.groupReason == .reload)
    }

    /// The span never splits a surrogate pair: each pair shares its first or its second code unit.
    @Test(arguments: [("a😀b", "a😁b"), ("a\u{10000}", "a\u{1F400}"), ("a😀b", "a😀😀b"), ("😀", "")])
    func `the changed span keeps whole characters`(old: String, new: String) {
        let (controller, host) = Self.givenController(old)

        controller.reload(text: new, undoActionName: "Reload")

        #expect(controller.text == new)
        #expect(host.changes.last?.text == new)
        controller.undoManager.undo()
        #expect(controller.text == old)
    }

    @Test(arguments: [
        (0 ..< 0, 0 ..< 0),
        (2 ..< 3, 2 ..< 4),
        (3 ..< 6, 4 ..< 7)
    ])
    func `a selection before, over, or after the changed span stays on its text`(
        before: Range<Int>, after: Range<Int>
    ) {
        let (controller, _) = Self.givenController("a\nb\nc\n")
        controller.selection = before

        controller.reload(text: "a\nB2\nc\n", undoActionName: "Reload")

        #expect(controller.selection == after)
    }

    @Test
    func `an undoable reload of the same text changes nothing`() {
        let (controller, host) = Self.givenController("a\n")

        controller.reload(text: "a\n", undoActionName: "Reload")

        #expect(host.changes.isEmpty)
        #expect(!controller.undoManager.canUndo)
    }

    @Test
    func `replacing the text is one edit undo group`() {
        let (controller, host) = Self.givenController("a\nb\n")

        controller.replaceText("a\nc\nb\n")

        #expect(host.changes.last?.reason == .edit)
        #expect(host.changes.last?.range == NSRange(location: 2, length: 0))
        controller.undoManager.undo()
        #expect(controller.text == "a\nb\n")
        #expect(host.changes.last?.groupReason == .edit)
    }

    /// A caret at the start of an insertion stays before it; one inside a span
    /// that shrinks goes to the span's new end.
    @Test(arguments: [("a\nc\n", 2, "a\nb\nc\n", 2), ("a\nbbbb\nc\n", 5, "a\nB\nc\n", 3)])
    func `a caret at or inside the changed span stays on its text`(old: String, caret: Int, new: String, after: Int) {
        let (controller, _) = Self.givenController(old)
        controller.selection = caret ..< caret

        controller.reload(text: new, undoActionName: "Reload")

        #expect(controller.selection == after ..< after)
    }

    @Test
    func `a replacement can name its undo group`() {
        let (controller, _) = Self.givenController("a\n")

        controller.replaceText("b\n", undoActionName: "Resolve")

        #expect(controller.undoManager.undoActionName == "Resolve")
    }
}
