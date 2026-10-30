import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design › Tasks: checkbox clicks, their undo, and their accessibility,
/// driven through the controller with a recording host.
@MainActor
struct MarkdownTextControllerCheckboxTests {
    @Test(arguments: [MarkdownMode.editor, .rendered])
    func `a checkbox click flips the byte and reports checkbox`(mode: MarkdownMode) {
        let (controller, host) = MarkdownTextControllerTests.givenController("- [ ] task\n", mode: mode)

        controller.toggleTask(0)

        #expect(controller.text == "- [x] task\n")
        #expect(host.changes.map(\.reason) == [.checkbox])
        #expect(host.changes.first?.range == NSRange(location: 3, length: 1))
        #expect(host.changes.first?.replacement == "x")
        #expect(host.changes.first?.text == "- [x] task\n")
    }

    @Test
    func `in the locked editor a checkbox is not enabled and a click changes nothing`() {
        let (controller, host) = MarkdownTextControllerTests.givenController("- [ ] task\n", mode: .editorLocked)

        controller.toggleTask(0)

        #expect(controller.checkboxAccessibility(0).isEnabled == false)
        #expect(controller.text == "- [ ] task\n")
        #expect(host.changes.isEmpty)
    }

    @Test
    func `while not editable a checkbox is not enabled`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("- [ ] task\n")

        controller.isEditable = false

        #expect(controller.checkboxAccessibility(0).isEnabled == false)
    }

    @Test(arguments: ["x", "X"])
    func `a click on a checked task makes it a space`(marker: String) {
        let (controller, _) = MarkdownTextControllerTests.givenController("- [\(marker)] task\n")

        controller.toggleTask(0)

        #expect(controller.text == "- [ ] task\n")
    }

    @Test
    func `a selection a text view reports past the end is cut to the text`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("ab")

        #expect(controller.clamped(1 ..< 9) == 1 ..< 2)
        #expect(controller.clamped(5 ..< 9) == 2 ..< 2)
    }

    @Test
    func `a checkbox after a byte order mark flips its own marker`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("\u{FEFF}- [ ] task\n")

        controller.toggleTask(0)

        #expect(controller.text == "\u{FEFF}- [x] task\n")
    }

    @Test
    func `the checkbox accessibility value is done or not done and its label is the task text`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("- [x] one\n- [ ] two\n")

        #expect(controller.checkboxAccessibility(0).value == "done")
        #expect(controller.checkboxAccessibility(1).value == "not done")
        #expect(controller.checkboxAccessibility(1).label == "two")
        #expect(controller.checkboxAccessibility(0).isEnabled)
    }

    @Test
    func `a checkbox click is one undo group and undo reports undo`() {
        let (controller, host) = MarkdownTextControllerTests.givenController("- [ ] task\n")

        controller.toggleTask(0)
        controller.undoManager.undo()

        #expect(controller.text == "- [ ] task\n")
        #expect(host.changes.map(\.reason) == [.checkbox, .undo])
    }

    @Test
    func `redo reports redo`() {
        let (controller, host) = MarkdownTextControllerTests.givenController("- [ ] task\n")

        controller.toggleTask(0)
        controller.undoManager.undo()
        controller.undoManager.redo()

        #expect(controller.text == "- [x] task\n")
        #expect(host.changes.map(\.reason) == [.checkbox, .undo, .redo])
    }
}
