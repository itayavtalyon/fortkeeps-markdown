import Foundation

/// A replacement in UTF-16 offsets of the text before the edit.
public struct TextEdit: Equatable, Sendable {
    public let range: Range<Int>
    public let replacement: String
    /// The selection after the edit.
    public let selection: Range<Int>

    public init(range: Range<Int>, replacement: String, selection: Range<Int>) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }
}

/// Return in a list item (design log 001 › Editor).
public enum ListContinuation {
    /// The edit Return makes in a list item, or nil for a plain newline. A
    /// task continues as `- [ ] `; Return on an empty item ends the list.
    public static func returnEdit(in text: String, selection: Range<Int>) -> TextEdit? {
        let units = Array(text.utf16)
        let lineStart = units[..<selection.lowerBound].lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
        let lineEnd = units[selection.lowerBound...].firstIndex(of: 0x0A) ?? units.count
        let line = String(decoding: units[lineStart ..< lineEnd], as: UTF16.self)
        guard let match = line.prefixMatch(
            of: /((?:[ ]{0,3}>[ ]?)*)([ \t]*)([-*+]|(\d{1,9})([.)]))([ \t]+|$)(\[[ xX]\](?:[ \t]+|$))?/
        ) else { return nil }
        let contentStart = lineStart + match.0.utf16.count
        guard selection.lowerBound >= contentStart else { return nil }
        let markerStart = lineStart + match.1.utf16.count + match.2.utf16.count
        let content = units[contentStart ..< lineEnd]
        if content.allSatisfy({ $0 == 0x20 || $0 == 0x09 }) {
            return TextEdit(range: markerStart ..< lineEnd, replacement: "", selection: markerStart ..< markerStart)
        }
        var marker = String(match.3)
        if let number = match.4, let delimiter = match.5 {
            // At most nine digits, so the number fits an Int.
            marker = "\(Int(number)! + 1)\(delimiter)" // swiftlint:disable:this force_unwrapping
        }
        let prefix = "\n" + match.1 + match.2 + marker + " " + (match.7 == nil ? "" : "[ ] ")
        let caret = selection.lowerBound + prefix.utf16.count
        return TextEdit(range: selection, replacement: prefix, selection: caret ..< caret)
    }
}

/// When an edit starts a new undo group (design log 001 › Undo).
public struct UndoGrouping: Sendable {
    public enum Event: Sendable {
        case typed(String)
        case caretJump
        case returnKey
        case formatCommand
        case paste
        case listContinuation
        case checkbox
        case replaceAll
        case resolveApply
        case compositionCommitted
    }

    public enum Decision: Equatable, Sendable {
        /// Add the edit to the open group.
        case continueGroup
        /// Close the open group and open one for this edit.
        case newGroup
        /// The edit is one group by itself.
        case ownGroup
        /// Close the open group; the event is not an edit.
        case closeGroup
    }

    /// A typed run ends on whitespace after this many seconds without typing.
    public static let pause = 1.0

    private var isOpen = false
    private var lastTime = 0.0
    private var endsInWhitespace = false

    public init() {}

    public mutating func register(_ event: Event, at time: Double) -> Decision {
        switch event {
        case let .typed(text):
            let decision: Decision = isOpen && !(endsInWhitespace && time - lastTime >= Self.pause)
                ? .continueGroup : .newGroup
            isOpen = true
            lastTime = time
            endsInWhitespace = text.last.map(\.isWhitespace) == true
            return decision
        case .caretJump:
            isOpen = false
            return .closeGroup
        default:
            isOpen = false
            return .ownGroup
        }
    }
}

/// The `maxUTF8Bytes` cut (design log 001 › Editor).
public enum ByteLimit {
    /// The longest prefix of `insertion` that keeps the text within `limit`
    /// UTF-8 bytes once it replaces `range` (UTF-16 offsets). The cut falls on
    /// a grapheme boundary, which is also a UTF-8 boundary.
    public static func fitting(
        _ insertion: String,
        replacing range: Range<Int>,
        in text: String,
        limit: Int?
    ) -> String {
        guard let limit else { return insertion }
        let units = Array(text.utf16)
        let removed = String(decoding: units[range], as: UTF16.self).utf8.count
        var room = limit - (text.utf8.count - removed)
        var kept = ""
        for character in insertion {
            room -= character.utf8.count
            guard room >= 0 else { break }
            kept.append(character)
        }
        return kept
    }
}
