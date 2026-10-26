/// Reads the block syntax at the start of one editor line: quote markers, a
/// code fence, list markers, a task marker, a heading, and table rows.
struct LineScanner {
    typealias Span = MarkdownStyler.StyleSpan

    let units: [UInt16]
    let caret: Int?
    var position = 0
    var spans: [Span] = []
    var isQuote = false

    private static let space = UInt16(UInt8(ascii: " "))
    private static let tab = UInt16(UInt8(ascii: "\t"))

    private func isBlank(_ index: Int) -> Bool {
        index >= units.count || units[index] == Self.space || units[index] == Self.tab
    }

    /// The offset after at most three spaces.
    private func indented(from start: Int) -> Int {
        var index = start
        while index < units.count, index - start < 3, units[index] == Self.space {
            index += 1
        }
        return index
    }

    private func skippingBlanks(from start: Int) -> Int {
        var index = start
        while index < units.count, isBlank(index) {
            index += 1
        }
        return index
    }

    private mutating func syntax(_ range: Range<Int>) {
        spans.append(Span(range: range, token: .syntax))
    }

    mutating func readQuotes() {
        while true {
            let marker = indented(from: position)
            guard marker < units.count, units[marker] == UInt16(UInt8(ascii: ">")) else { return }
            let end = marker + 1 < units.count && units[marker + 1] == Self.space ? marker + 2 : marker + 1
            syntax(marker ..< end)
            position = end
            isQuote = true
        }
    }

    /// A run of three or more backticks or tildes opens a fence. A backtick
    /// fence's info string holds no backtick.
    mutating func readOpeningFence() -> MarkdownStyler.LineState.Fence? {
        let start = indented(from: position)
        guard let fence = fenceRun(at: start), fence.length >= 3 else { return nil }
        if fence.character == UInt16(UInt8(ascii: "`")), units[(start + fence.length)...].contains(fence.character) {
            return nil
        }
        syntax(start ..< units.count)
        position = units.count
        return fence
    }

    private func fenceRun(at start: Int) -> MarkdownStyler.LineState.Fence? {
        guard start < units.count,
              [UInt16(UInt8(ascii: "`")), UInt16(UInt8(ascii: "~"))].contains(units[start]) else { return nil }
        var end = start
        while end < units.count, units[end] == units[start] {
            end += 1
        }
        return MarkdownStyler.LineState.Fence(character: units[start], length: end - start)
    }

    /// Inside a fence the line is code, unless it closes the fence: a run of
    /// the same character at least as long, then only blanks.
    mutating func finishInFence(_ fence: MarkdownStyler.LineState.Fence) -> MarkdownStyler.StyledLine {
        let start = indented(from: position)
        if let run = fenceRun(at: start), run.character == fence.character, run.length >= fence.length,
           skippingBlanks(from: start + run.length) == units.count
        {
            syntax(start ..< units.count)
            return finish(exiting: MarkdownStyler.LineState())
        }
        if position < units.count {
            spans.append(Span(range: position ..< units.count, token: .code))
        }
        return finish(exiting: MarkdownStyler.LineState(fence: fence))
    }

    /// Bullet and ordered list markers, each with the blanks after it.
    mutating func readListMarkers() -> Bool {
        var found = false
        while let end = listMarkerEnd(at: skippingBlanks(from: position)) {
            let start = skippingBlanks(from: position)
            let next = skippingBlanks(from: end)
            syntax(start ..< next)
            position = next
            found = true
        }
        return found
    }

    private func listMarkerEnd(at start: Int) -> Int? {
        guard start < units.count else { return nil }
        if [UInt16(UInt8(ascii: "-")), UInt16(UInt8(ascii: "*")), UInt16(UInt8(ascii: "+"))].contains(units[start]) {
            return isBlank(start + 1) ? start + 1 : nil
        }
        var end = start
        while end < units.count, end - start < 9,
              (UInt16(UInt8(ascii: "0")) ... UInt16(UInt8(ascii: "9"))).contains(units[end])
        {
            end += 1
        }
        guard end > start, end < units.count,
              [UInt16(UInt8(ascii: ".")), UInt16(UInt8(ascii: ")"))].contains(units[end]) else { return nil }
        return isBlank(end + 1) ? end + 1 : nil
    }

    /// `[ ]`, `[x]`, or `[X]` after a list marker. The caret inside the marker
    /// shows it raw and dimmed.
    mutating func readTaskMarker() {
        let start = position
        guard start + 3 <= units.count, units[start] == UInt16(UInt8(ascii: "[")),
              units[start + 2] == UInt16(UInt8(ascii: "]")),
              [Self.space, UInt16(UInt8(ascii: "x")), UInt16(UInt8(ascii: "X"))].contains(units[start + 1]),
              isBlank(start + 3)
        else { return }
        let marker = start ..< start + 3
        if let caret, (marker.lowerBound ... marker.upperBound).contains(caret) {
            syntax(marker)
        } else {
            spans.append(Span(range: marker, token: .checkbox(checked: units[start + 1] != Self.space)))
        }
        position = skippingBlanks(from: marker.upperBound)
    }

    /// One to six `#` and a blank start an ATX heading.
    mutating func readHeading() -> Int? {
        let start = indented(from: position)
        var end = start
        while end < units.count, end - start < 7, units[end] == UInt16(UInt8(ascii: "#")) {
            end += 1
        }
        guard (1 ... 6).contains(end - start), isBlank(end) else { return nil }
        let next = skippingBlanks(from: end)
        syntax(start ..< next)
        position = next
        return end - start
    }

    /// A GFM delimiter row (`|---|:-:|`) is all syntax.
    mutating func readTableDelimiterRow() -> Bool {
        let start = skippingBlanks(from: position)
        let text = String(decoding: units[start...], as: UTF16.self)
        guard text.contains("|"),
              text.wholeMatch(of: /\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*/) != nil
        else { return false }
        var end = units.count
        while end > start, isBlank(end - 1) {
            end -= 1
        }
        syntax(start ..< end)
        return true
    }

    /// A line whose content starts with `|` is a table row: each unescaped
    /// pipe is syntax.
    mutating func markTablePipes(in content: Range<Int>) {
        let start = skippingBlanks(from: content.lowerBound)
        guard start < units.count, units[start] == UInt16(UInt8(ascii: "|")) else { return }
        var backslashes = 0
        for index in start ..< content.upperBound {
            if units[index] == UInt16(UInt8(ascii: "|")), backslashes.isMultiple(of: 2) {
                syntax(index ..< index + 1)
            }
            backslashes = units[index] == UInt16(UInt8(ascii: "\\")) ? backslashes + 1 : 0
        }
    }

    /// The spans in line order. A block style comes before the inline spans
    /// that start where it starts.
    func finish(exiting: MarkdownStyler.LineState) -> MarkdownStyler.StyledLine {
        let ordered = spans.enumerated()
            .filter { !$0.element.range.isEmpty }
            .sorted { ($0.element.range.lowerBound, $0.offset) < ($1.element.range.lowerBound, $1.offset) }
            .map(\.element)
        return MarkdownStyler.StyledLine(range: 0 ..< units.count, spans: ordered, exiting: exiting)
    }
}
