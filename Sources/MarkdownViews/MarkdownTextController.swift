import Foundation
import MarkdownCore

/// The view behavior shared by the Mac view and the iOS view: the working
/// text, the mode, edits and their undo groups, checkboxes, links, copy, and
/// image requests. The platform views draw what it holds and forward events
/// to it. Offsets are UTF-16 offsets in `displayString` unless named otherwise.
@MainActor
final class MarkdownTextController {
    weak var host: MarkdownHost?
    let features: MarkdownFeatures
    let presentation: MarkdownPresentation
    let documentURL: URL?
    let maxUTF8Bytes: Int?

    private(set) var text: String
    private(set) var mode: MarkdownMode
    /// False pauses edits and disables checkboxes in any mode.
    var isEditable = true
    var selection: Range<Int> = 0 ..< 0
    /// Reduce Motion, or iOS Auto-Play Animated Images off: a gif shows frame 1.
    var reduceMotion = false
    /// The largest size the view draws an image at.
    var maxImagePixelSize = CGSize(width: 8192, height: 8192)
    let undoManager = UndoManager()

    /// Called after the text or the mode changes, so the view redraws.
    var onDisplayChange: (() -> Void)?
    /// Called when an image result arrives or changes.
    var onImageChange: ((String) -> Void)?

    private var grouping = UndoGrouping()
    /// The open undo group: later edits of the same typed run join it.
    private var openGroup: UndoGroup?
    private var cachedDocument: MarkdownDocument?
    // Internal for the links and images extension.
    var imageResults: [String: ImageResult] = [:]
    var imageTasks: [String: Task<Void, Never>] = [:]
    var lastImageRequest: ImageRequest?

    init(
        text: String,
        features: MarkdownFeatures,
        presentation: MarkdownPresentation,
        mode: MarkdownMode,
        maxUTF8Bytes: Int?,
        documentURL: URL?
    ) {
        self.text = text
        self.features = features
        self.presentation = presentation
        self.mode = mode
        self.maxUTF8Bytes = maxUTF8Bytes
        self.documentURL = documentURL
        undoManager.groupsByEvent = false
    }

    /// The model of the current text, built when first needed after an edit,
    /// so typing does not parse the whole text.
    var document: MarkdownDocument {
        if let cachedDocument {
            return cachedDocument
        }
        let built = MarkdownDocument(text: text, features: features, presentation: presentation)
        cachedDocument = built
        return built
    }

    var displayString: String {
        mode == .rendered ? document.rendered.string : text
    }

    var checksSpelling: Bool {
        mode == .editor
    }

    var acceptsEdits: Bool {
        mode == .editor && isEditable
    }

    // MARK: edits

    /// The part of a proposed replacement that fits `maxUTF8Bytes`.
    func allowedReplacement(for range: Range<Int>, proposed: String) -> String {
        ByteLimit.fitting(proposed, replacing: range, in: text, limit: maxUTF8Bytes)
    }

    /// The text view changed its text: the edit is already on screen.
    func textViewDidReplace(_ range: Range<Int>, with replacement: String, event: UndoGrouping.Event, at time: Double) {
        apply(
            TextEdit(range: range, replacement: replacement, selection: selection),
            reason: .edit,
            event: event,
            time: time
        )
    }

    /// An insertion cut to `maxUTF8Bytes`: the text view did not apply it, so
    /// the controller applies the kept prefix and the view redraws.
    func replaceCut(_ range: Range<Int>, with kept: String, event: UndoGrouping.Event, at time: Double) {
        apply(TextEdit(range: range, replacement: kept, selection: selection), reason: .edit, event: event, time: time)
        let caret = range.lowerBound + kept.utf16.count
        selection = caret ..< caret
        onDisplayChange?()
    }

    /// A range cut to the display string, for a selection a text view reports.
    func clamped(_ range: Range<Int>) -> Range<Int> {
        let limit = displayString.utf16.count
        return min(range.lowerBound, limit) ..< min(range.upperBound, limit)
    }

    /// The caret moved without an edit: a typed run ends.
    func caretMoved() {
        openGroup = nil
        _ = grouping.register(.caretJump, at: 0)
    }

    /// Return in a list item; false leaves the newline to the text view.
    func pressReturn() -> Bool {
        guard acceptsEdits, let edit = ListContinuation.returnEdit(in: text, selection: selection) else { return false }
        apply(edit, reason: .edit, event: .listContinuation, time: 0)
        selection = edit.selection
        onDisplayChange?()
        return true
    }

    func perform(_ command: FormatCommand) {
        guard acceptsEdits else { return }
        let edit = FormatCommands.apply(command, to: text, selection: selection)
        apply(edit, reason: .edit, event: .formatCommand, time: 0)
        selection = edit.selection
        onDisplayChange?()
    }

    /// A checkbox click flips one byte. It is one undo group.
    func toggleTask(_ index: Int) {
        guard checkboxAccessibility(index).isEnabled else { return }
        let offset = utf16Offset(ofSourceByte: document.tasks[index].byteOffset)
        let marker = (text as NSString).substring(with: NSRange(location: offset, length: 1))
        let edit = TextEdit(range: offset ..< offset + 1, replacement: marker == " " ? "x" : " ", selection: selection)
        apply(edit, reason: .checkbox, event: .checkbox, time: 0)
        onDisplayChange?()
    }

    /// The accessibility of a checkbox: the task text, `done` or `not done`,
    /// and whether a click may change it.
    func checkboxAccessibility(_ index: Int) -> CheckboxState {
        let task = document.tasks[index]
        return CheckboxState(
            label: task.text,
            value: task.checked ? "done" : "not done",
            isEnabled: isEditable && mode != .editorLocked
        )
    }

    /// Replaces the text, clears Undo, and reports `reload`.
    func reload(text newText: String) {
        let old = text.utf16.count
        text = newText
        cachedDocument = nil
        undoManager.removeAllActions()
        openGroup = nil
        grouping = UndoGrouping()
        selection = clamped(selection)
        host?.textDidChange(TextChange(
            reason: .reload,
            range: NSRange(location: 0, length: old),
            replacement: newText,
            text: newText
        ))
        onDisplayChange?()
    }

    private func apply(_ edit: TextEdit, reason: TextChange.Reason, event: UndoGrouping.Event?, time: Double) {
        let units = Array(text.utf16)
        let removed = String(decoding: units[edit.range], as: UTF16.self)
        text = String(decoding: units[..<edit.range.lowerBound], as: UTF16.self) + edit.replacement
            + String(decoding: units[edit.range.upperBound...], as: UTF16.self)
        cachedDocument = nil
        let change = Change(location: edit.range.lowerBound, removed: removed, inserted: edit.replacement)
        if let event {
            record(change, decision: grouping.register(event, at: time))
        }
        host?.textDidChange(TextChange(
            reason: reason,
            range: NSRange(location: edit.range.lowerBound, length: edit.range.count),
            replacement: edit.replacement,
            text: text
        ))
    }

    // MARK: undo

    /// One applied replacement, enough to reverse it.
    private struct Change {
        let location: Int
        let removed: String
        let inserted: String

        var inverse: Change {
            Change(location: location, removed: inserted, inserted: removed)
        }
    }

    /// The changes of one undo group, in order. A class, so a typed run can
    /// keep adding to a group that is already registered.
    private final class UndoGroup {
        var changes: [Change]

        init(_ changes: [Change]) {
            self.changes = changes
        }
    }

    private func record(_ change: Change, decision: UndoGrouping.Decision) {
        if decision == .continueGroup, let openGroup {
            openGroup.changes.append(change)
            return
        }
        let group = UndoGroup([change])
        register(group)
        // After an own group UndoGrouping opens a new one, so the group can stay open.
        openGroup = group
    }

    /// Registers a group as one undo action. Undoing it registers the
    /// reversed group as the redo action.
    private func register(_ group: UndoGroup) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated {
                controller.reverse(group)
            }
        }
        undoManager.endUndoGrouping()
    }

    private func reverse(_ group: UndoGroup) {
        let reason: TextChange.Reason = undoManager.isUndoing ? .undo : .redo
        openGroup = nil
        _ = grouping.register(.caretJump, at: 0)
        let inverse = UndoGroup(group.changes.reversed().map(\.inverse))
        for change in inverse.changes {
            let range = change.location ..< change.location + change.removed.utf16.count
            apply(
                TextEdit(range: range, replacement: change.inserted, selection: selection),
                reason: reason,
                event: nil,
                time: 0
            )
            // The caret goes to the end of the restored text.
            let caret = change.location + change.inserted.utf16.count
            selection = caret ..< caret
        }
        register(inverse)
        onDisplayChange?()
    }

    // MARK: modes

    /// Changes the mode in place and keeps the anchor: the selection and the
    /// first visible offset move to the same source characters. Returns the
    /// first visible offset in the new mode.
    @discardableResult
    func setMode(_ newMode: MarkdownMode, firstVisibleOffset: Int = 0) -> Int {
        let start = sourceByte(ofDisplayOffset: selection.lowerBound)
        let end = sourceByte(ofDisplayOffset: selection.upperBound)
        let visible = sourceByte(ofDisplayOffset: firstVisibleOffset)
        mode = newMode
        let lowerBound = displayOffset(ofSourceByte: start)
        selection = lowerBound ..< max(lowerBound, displayOffset(ofSourceByte: end))
        onDisplayChange?()
        return displayOffset(ofSourceByte: visible)
    }

    func sourceByte(ofDisplayOffset offset: Int) -> Int {
        mode == .rendered ? document.rendered.sourceOffset(atRendered: offset) : sourceByte(ofUTF16: offset)
    }

    func displayOffset(ofSourceByte byte: Int) -> Int {
        mode == .rendered ? document.rendered.renderedOffset(atSource: byte) : utf16Offset(ofSourceByte: byte)
    }

    /// Source bytes exclude a leading BOM; text offsets include it.
    private var bomLength: (utf8: Int, utf16: Int) {
        text.hasPrefix("\u{FEFF}") ? (3, 1) : (0, 0)
    }

    func sourceByte(ofUTF16 offset: Int) -> Int {
        let utf16 = text.utf16
        let index = utf16.index(utf16.startIndex, offsetBy: min(offset, utf16.count))
        return max(0, text.utf8.distance(from: text.utf8.startIndex, to: index) - bomLength.utf8)
    }

    func utf16Offset(ofSourceByte byte: Int) -> Int {
        let utf8 = text.utf8
        let index = utf8.index(utf8.startIndex, offsetBy: min(byte + bomLength.utf8, utf8.count))
        return text.utf16.distance(from: text.utf16.startIndex, to: index)
    }
}

/// What VoiceOver reads for a checkbox.
struct CheckboxState: Equatable {
    let label: String
    /// `done` or `not done`.
    let value: String
    let isEnabled: Bool
}
