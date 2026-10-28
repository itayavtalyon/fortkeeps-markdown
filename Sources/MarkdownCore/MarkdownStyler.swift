/// The editor's live styling (design log 001 › Editor, log 010 X-16): one
/// line at a time, block syntax by line rules and inline syntax by the parser.
/// Positions are UTF-16 offsets, the unit TextKit uses.
public struct MarkdownStyler: Sendable {
    public enum StyleToken: Equatable, Sendable {
        /// A dimmed syntax character (`text3`, regular weight).
        case syntax
        case heading(level: Int)
        case strong
        case emphasis
        case code
        case link
        /// Quote text (`text2`).
        case quote
        case strikethrough
        /// A drawn checkbox in place of `[ ]` or `[x]`.
        case checkbox(checked: Bool)
    }

    public struct StyleSpan: Equatable, Sendable {
        public let range: Range<Int>
        public let token: StyleToken
    }

    /// What one line hands to the next: an open code fence.
    public struct LineState: Equatable, Sendable {
        let fence: CodeFence?

        public init() {
            fence = nil
        }

        init(fence: CodeFence?) {
            self.fence = fence
        }

        public var isInFence: Bool {
            fence != nil
        }
    }

    public struct StyledLine: Equatable, Sendable {
        /// The line's UTF-16 range: in the line for `styleLine`, in the text for `styleText`.
        public let range: Range<Int>
        public let spans: [StyleSpan]
        public let exiting: LineState
    }

    let features: MarkdownFeatures

    public init(features: MarkdownFeatures) {
        self.features = features
    }

    /// Styles one line without its line ending. `caret` is a UTF-16 offset in the line.
    public func styleLine(_ line: String, entering state: LineState, caret: Int?) -> StyledLine {
        var scanner = LineScanner(units: Array(line.utf16), caret: caret)
        scanner.readQuotes()
        if let fence = state.fence {
            return scanner.finishInFence(fence)
        }
        if let fence = scanner.readOpeningFence() {
            return scanner.finish(exiting: LineState(fence: fence))
        }
        let listed = scanner.readListMarkers()
        if listed, features.taskLists {
            scanner.readTaskMarker()
        }
        let headingLevel = listed ? nil : scanner.readHeading()
        let content = scanner.position ..< scanner.units.count
        if let level = headingLevel, !content.isEmpty {
            scanner.spans.append(StyleSpan(range: content, token: .heading(level: level)))
        } else if scanner.isQuote, !content.isEmpty {
            scanner.spans.append(StyleSpan(range: content, token: .quote))
        }
        if features.tables, scanner.readTableDelimiterRow() {
            return scanner.finish(exiting: LineState())
        }
        scanner.spans += InlineStyler(features: features).spans(in: scanner.units, content: content)
        if features.tables {
            scanner.markTablePipes(in: content)
        }
        return scanner.finish(exiting: LineState())
    }

    /// Styles every line of a text in order, the first line entering `state`.
    /// `caret` is a UTF-16 offset in the text.
    public func styleText(_ text: String, entering state: LineState = LineState(), caret: Int?) -> [StyledLine] {
        var state = state
        var start = 0
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let length = line.utf16.count
            let lineCaret = caret.flatMap { (start ... start + length).contains($0) ? $0 - start : nil }
            let styled = styleLine(String(line), entering: state, caret: lineCaret)
            defer {
                state = styled.exiting
                start += length + 1
            }
            return StyledLine(range: start ..< start + length, spans: styled.spans, exiting: styled.exiting)
        }
    }

    /// The UTF-16 range of the line that holds `offset` and the line on each
    /// side, without the last line's ending: the lines the editor restyles
    /// after an edit.
    /// It scans only those lines, so a keystroke costs the same in any length of text.
    public static func neighborhood(of offset: Int, in text: String) -> Range<Int> {
        let units = text.utf16
        func lineStart(_ index: String.Index) -> String.Index {
            units[..<index].lastIndex(of: 0x0A).map(units.index(after:)) ?? units.startIndex
        }
        func lineEnd(_ index: String.Index) -> String.Index {
            units[index...].firstIndex(of: 0x0A) ?? units.endIndex
        }
        let caret = units.index(units.startIndex, offsetBy: min(offset, units.count))
        let start = lineStart(caret)
        let end = lineEnd(caret)
        let first = start == units.startIndex ? start : lineStart(units.index(before: start))
        let last = end == units.endIndex ? end : lineEnd(units.index(after: end))
        return units.distance(from: units.startIndex, to: first) ..< units.distance(from: units.startIndex, to: last)
    }
}

/// An open code fence: its character and the length of its run.
struct CodeFence: Equatable {
    let character: UInt16
    let length: Int

    /// A run closes the fence when it uses the same character and is at least as long.
    func closes(_ fence: CodeFence) -> Bool {
        character == fence.character && length >= fence.length
    }
}
