import Foundation

/// What the view reports to `MarkdownHost.textDidChange(_:)` after it
/// applies a change (design log 001 › Host interface). It lives here, not in
/// `MarkdownViews`, so the pure save policy can read it.
public struct TextChange: Equatable, Sendable {
    public enum Reason: Sendable {
        /// Typing, paste, a format command, list continuation, Replace All, Resolve Apply.
        case edit
        case checkbox
        case undo
        case redo
        case reload
    }

    public let reason: Reason
    /// The reason of the change that made this undo group. An undo or a redo
    /// carries the reason of the change it reverses or repeats (`edit` or
    /// `checkbox`), so the host can save a checkbox undo at once. Any other
    /// change carries its own reason.
    public let groupReason: Reason
    /// The UTF-16 range before the change.
    public let range: NSRange
    public let replacement: String
    /// The full text after the change.
    public let text: String

    public init(reason: Reason, groupReason: Reason, range: NSRange, replacement: String, text: String) {
        self.reason = reason
        self.groupReason = groupReason
        self.range = range
        self.replacement = replacement
        self.text = text
    }
}
