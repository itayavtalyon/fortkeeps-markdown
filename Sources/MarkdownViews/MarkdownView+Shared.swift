import Foundation
import MarkdownCore

/// The host interface both platform views share (design log 001 › Host
/// interface). One `MarkdownView` compiles per platform.
public extension MarkdownView {
    /// The host; the view holds it weakly. The host may set itself after
    /// creating the view.
    var host: MarkdownHost? {
        get { controller.host }
        set { controller.host = newValue }
    }

    var text: String {
        controller.text
    }

    /// The first visible block and the selection, in source bytes.
    var anchor: MarkdownAnchor {
        get {
            controller.document.anchor(
                firstVisibleSourceOffset: controller.sourceByte(ofDisplayOffset: firstVisibleOffset),
                selection: controller.sourceByte(ofDisplayOffset: controller.selection.lowerBound)
                    ..< controller.sourceByte(ofDisplayOffset: controller.selection.upperBound, affinity: .backward)
            )
        }
        set {
            let start = controller.displayOffset(ofSourceByte: newValue.selection.lowerBound)
            let end = max(start, controller.displayOffset(ofSourceByte: newValue.selection.upperBound))
            select(start ..< end)
            scroll(toOffset: controller.displayOffset(ofSourceByte: newValue.block + newValue.offsetInBlock))
        }
    }

    /// Replaces the text, clears Undo, keeps the anchor at the nearest block, and reports `reload`.
    func reload(text newText: String) {
        let kept = anchor
        controller.reload(text: newText)
        anchor = kept
    }

    /// The outside version as one undo group with the host's action name
    /// (design log 004 › Outside changes). The caret stays on its text and the
    /// view keeps its scroll place. Reports `reload`.
    func reload(text newText: String, undoActionName: String) {
        keepingPlace { controller.reload(text: newText, undoActionName: undoActionName) }
    }

    /// The view's own undo groups, for a host's Undo button.
    override var undoManager: UndoManager? {
        controller.undoManager
    }

    /// A Resolve Apply: the merged text as one undo group with reason `edit`,
    /// named `undoActionName` (Undo Resolve) when given.
    func replaceText(_ newText: String, undoActionName: String? = nil) {
        keepingPlace { controller.replaceText(newText, undoActionName: undoActionName) }
    }

    /// The file the relative links and images resolve against; a host sets it
    /// when the file moves.
    var documentURL: URL? {
        get { controller.documentURL }
        set { controller.documentURL = newValue }
    }

    private func keepingPlace(_ change: () -> Void) {
        let kept = anchor
        change()
        let selection = controller.selection
        anchor = kept
        select(selection)
    }

    /// The host has a new result for a destination.
    func refreshImage(destination: String) {
        controller.refreshImage(destination: destination)
    }

    /// The heading of a `#fragment` link (design log 001 › Links): the caret
    /// goes to its start, the view scrolls there, and VoiceOver focus moves
    /// there. False, with no change, when no heading has that GFM slug.
    @discardableResult
    func showHeading(fragment: String) -> Bool {
        guard let block = controller.document.headingBlock(forFragment: fragment) else { return false }
        let start = block.sourceRange.lowerBound
        anchor = MarkdownAnchor(block: start, offsetInBlock: 0, selection: start ..< start)
        moveAccessibilityFocusToSelection()
        return true
    }

    /// Performs a format command, as the format bar and the shortcuts do.
    func perform(_ command: FormatCommand) {
        controller.perform(command)
    }
}
