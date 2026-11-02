import Foundation
import MarkdownCore

/// Design log 004 › Outside changes: a reload Undo can reverse, and Resolve Apply.
extension MarkdownTextController {
    /// The outside version as one undo group named `undoActionName` (design
    /// log 004 › Outside changes). Only the changed span is replaced, so the
    /// caret stays on its text. Reports `reload`; its undo reports `groupReason` `reload`.
    func reload(text newText: String, undoActionName: String) {
        replaceChangedSpan(with: newText, reason: .reload, event: .reload, actionName: undoActionName)
    }

    /// A Resolve Apply: one undo group with reason `edit`, named `undoActionName` when given.
    func replaceText(_ newText: String, undoActionName: String? = nil) {
        replaceChangedSpan(with: newText, reason: .edit, event: .resolveApply, actionName: undoActionName)
    }

    private func replaceChangedSpan(
        with newText: String,
        reason: TextChange.Reason,
        event: UndoGrouping.Event,
        actionName: String? = nil
    ) {
        let old = Array(text.utf16)
        let new = Array(newText.utf16)
        // Whole characters only: the span starts and ends outside a surrogate pair.
        var prefix = zip(old, new).prefix { $0 == $1 }.count
        if prefix > 0, UTF16.isLeadSurrogate(old[prefix - 1]) {
            prefix -= 1
        }
        var suffix = zip(old[prefix...].reversed(), new[prefix...].reversed()).prefix { $0 == $1 }.count
        if suffix > 0, UTF16.isTrailSurrogate(old[old.count - suffix]) {
            suffix -= 1
        }
        let span = prefix ..< old.count - suffix
        guard !span.isEmpty || new.count != old.count else { return }
        let replacement = String(decoding: new[prefix ..< new.count - suffix], as: UTF16.self)
        let delta = new.count - old.count
        // A bound after the span moves with it; one inside it goes to the span's new end.
        let moved = { (bound: Int) in
            bound <= span.lowerBound ? bound : bound >= span.upperBound ? bound + delta
                : min(bound, span.lowerBound + replacement.utf16.count)
        }
        let kept = moved(selection.lowerBound) ..< moved(selection.upperBound)
        let edit = TextEdit(range: span, replacement: replacement, selection: kept)
        apply(edit, reason: reason, event: event, time: 0, actionName: actionName)
        selection = kept
        onDisplayChange?()
    }
}
