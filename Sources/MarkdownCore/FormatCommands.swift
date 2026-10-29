/// A format command (design log 001 › Format commands).
public enum FormatCommand: Equatable, Sendable {
    case bold
    case italic
    /// Command-K, with the clipboard's string.
    case link(clipboard: String?)
    case code
    case quote
    case checkbox
    /// Heading 1 to 3.
    case heading(Int)
    case body
    case bulletedList
}

/// The base behavior of each format command: it adds its format, and a
/// second run removes it. The exact cases of WAIT-2 (a heading inside a list
/// item, a mixed selection, nested markers) are not built. Offsets are UTF-16.
public enum FormatCommands {
    public static func apply(_ command: FormatCommand, to text: String, selection: Range<Int>) -> TextEdit {
        let (units, start) = text.linesTouching(selection)
        return apply(command, to: units, selection: selection.lowerBound - start ..< selection.upperBound - start)
            .shifted(by: start)
    }

    /// True when the selection already has the command's format: the format
    /// bar shows the button as pressed.
    public static func isActive(_ command: FormatCommand, in text: String, selection: Range<Int>) -> Bool {
        let (units, start) = text.linesTouching(selection)
        return isActive(command, in: units, selection: selection.lowerBound - start ..< selection.upperBound - start)
    }

    // Every command reads only the lines its selection touches, so it works
    // on those lines, in their own offsets.

    private static func apply(_ command: FormatCommand, to units: [UInt16], selection: Range<Int>) -> TextEdit {
        switch command {
        case .bold: wrap("**", in: units, selection: selection)
        case .italic: wrap("*", in: units, selection: selection)
        case .code where Lines(units, selection).count > 1: fence(units, selection)
        case .code: wrap("`", in: units, selection: selection)
        case let .link(clipboard): link(units, selection, clipboard: clipboard)
        case .quote: prefixLines(units, selection, prefix: "> ", has: { $0.hasPrefix("> ") })
        case .bulletedList: prefixLines(units, selection, prefix: "- ", has: { $0.hasPrefix("- ") })
        case .checkbox: prefixLines(units, selection, prefix: "- [ ] ", has: isTask)
        case let .heading(level): heading(units, selection, level: level)
        case .body: heading(units, selection, level: 0)
        }
    }

    private static func isActive(_ command: FormatCommand, in units: [UInt16], selection: Range<Int>) -> Bool {
        let line = Lines(units, selection).text(0)
        switch command {
        case .bold: return wrapped("**", units, selection) || styled(.strong, units, selection)
        case .italic: return wrapped("*", units, selection) || styled(.emphasis, units, selection)
        case .code: return wrapped("`", units, selection) || styled(.code, units, selection)
        case .link: return false
        case .quote: return line.hasPrefix(">")
        case .bulletedList: return line.prefixMatch(of: #/[-*+] /#) != nil
        case .checkbox: return isTask(line)
        case let .heading(level): return headingLevel(line) == level
        case .body: return headingLevel(line) == 0
        }
    }

    // MARK: wrapping

    /// The runs of `character` just before and just after a range.
    private static func runs(_ character: UInt16, _ units: [UInt16], _ range: Range<Int>) -> (before: Int, after: Int) {
        let before = units[..<range.lowerBound].reversed().prefix { $0 == character }.count
        let after = units[range.upperBound...].prefix { $0 == character }.count
        return (before, after)
    }

    /// A delimiter of width 1 needs an odd run on each side, so `*` inside
    /// `**` is not italic; width 2 needs a run of at least 2.
    private static func holds(_ width: Int, _ run: (before: Int, after: Int)) -> Bool {
        width == 1 ? run.before % 2 == 1 && run.after % 2 == 1 : run.before >= width && run.after >= width
    }

    /// True when the styler gives the selection's line a span of `token` that
    /// holds the whole selection.
    private static func styled(_ token: MarkdownStyler.StyleToken, _ units: [UInt16], _ selection: Range<Int>) -> Bool {
        let lines = Lines(units, selection)
        let start = lines.ranges[0].lowerBound
        let local = selection.lowerBound - start ... selection.upperBound - start
        let spans = MarkdownStyler(features: MarkdownFeatures()).styleLine(lines.text(0), entering: .init(), caret: nil)
            .spans
        return spans.contains { span in
            span.token == token && span.range.lowerBound <= local.lowerBound && local.upperBound <= span.range
                .upperBound
        }
    }

    private static func wrapped(_ delimiter: String, _ units: [UInt16], _ selection: Range<Int>) -> Bool {
        let character = Array(delimiter.utf16)[0]
        return holds(delimiter.utf16.count, runs(character, units, selection))
    }

    private static func wrap(_ delimiter: String, in units: [UInt16], selection: Range<Int>) -> TextEdit {
        let lines = Lines(units, selection)
        if lines.count > 1 {
            return lines.edit { line in line.isEmpty ? line : delimiter + line + delimiter }
        }
        let width = delimiter.utf16.count
        let character = Array(delimiter.utf16)[0]
        if holds(width, runs(character, units, selection)) {
            let outer = selection.lowerBound - width ..< selection.upperBound + width
            let inner = string(units[selection])
            return TextEdit(
                range: outer,
                replacement: inner,
                selection: outer.lowerBound ..< outer.lowerBound + selection.count
            )
        }
        let selected = Array(units[selection])
        let inside = holds(
            width,
            (selected.prefix { $0 == character }.count, selected.reversed().prefix { $0 == character }.count)
        )
        if selection.count >= 2 * width, inside {
            let inner = string(units[selection.lowerBound + width ..< selection.upperBound - width])
            return TextEdit(
                range: selection,
                replacement: inner,
                selection: selection.lowerBound ..< selection.lowerBound + inner.utf16.count
            )
        }
        let start = selection.lowerBound + width
        return TextEdit(
            range: selection,
            replacement: delimiter + string(units[selection]) + delimiter,
            selection: start ..< start + selection.count
        )
    }

    /// Several lines of code become a fenced block; a fenced block loses its fences.
    private static func fence(_ units: [UInt16], _ selection: Range<Int>) -> TextEdit {
        let lines = Lines(units, selection)
        let texts = (0 ..< lines.count).map(lines.text)
        let fenced = texts.count >= 2 && texts[0].hasPrefix("```") && texts[texts.count - 1] == "```"
        let body = fenced ? texts.dropFirst().dropLast().joined(separator: "\n") : (["```"] + texts + ["```"])
            .joined(separator: "\n")
        return TextEdit(
            range: lines.range,
            replacement: body,
            selection: lines.range.lowerBound ..< lines.range.lowerBound + body.utf16.count
        )
    }

    // MARK: lines

    private static func isTask(_ line: String) -> Bool {
        line.prefixMatch(of: #/- \[[ xX]\] /#) != nil
    }

    /// Adds `prefix` to each line, or removes the existing format from each
    /// line when every line has it. Empty lines in a multi-line selection stay.
    private static func prefixLines(
        _ units: [UInt16],
        _ selection: Range<Int>,
        prefix: String,
        has: (String) -> Bool
    ) -> TextEdit {
        let lines = Lines(units, selection)
        let texts = (0 ..< lines.count).map(lines.text)
        let candidates = texts.filter { !$0.isEmpty || lines.count == 1 }
        let removing = !candidates.isEmpty && candidates.allSatisfy(has)
        return lines.edit { line in
            if removing {
                return isTask(line) && prefix != "- [ ] " ? line :
                    String(line.dropFirst(isTask(line) ? 6 : prefix.count))
            }
            return line.isEmpty && lines.count > 1 ? line : prefix + line
        }
    }

    private static func headingLevel(_ line: String) -> Int {
        line.prefixMatch(of: /(#{1,6})(?: |$)/).map(\.1.count) ?? 0
    }

    /// Sets each line's `#` run to `level` (0 removes it). A heading command on
    /// lines that already have its level removes it.
    private static func heading(_ units: [UInt16], _ selection: Range<Int>, level: Int) -> TextEdit {
        let lines = Lines(units, selection)
        let texts = (0 ..< lines.count).map(lines.text).filter { !$0.isEmpty }
        let target = level > 0 && !texts.isEmpty && texts.allSatisfy { headingLevel($0) == level } ? 0 : level
        return lines.edit { line in
            guard !line.isEmpty else { return line }
            let content = line.replacing(/^#{1,6}(?: +|$)/, with: "")
            return target == 0 ? content : String(repeating: "#", count: target) + " " + content
        }
    }

    // MARK: link

    /// Command-K: with a selection and an http(s) URL as the whole clipboard,
    /// `[selection](url)`; with a selection, `[selection](|)`; with none, `[|]()`.
    private static func link(_ units: [UInt16], _ selection: Range<Int>, clipboard: String?) -> TextEdit {
        let selected = string(units[selection])
        let url = clipboard?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else {
            return TextEdit(
                range: selection,
                replacement: "[]()",
                selection: selection.lowerBound + 1 ..< selection.lowerBound + 1
            )
        }
        if let url, url.wholeMatch(of: /https?:\/\/\S+/) != nil {
            let replacement = "[" + selected + "](" + url + ")"
            let end = selection.lowerBound + replacement.utf16.count
            return TextEdit(range: selection, replacement: replacement, selection: end ..< end)
        }
        let caret = selection.lowerBound + selected.utf16.count + 3
        return TextEdit(range: selection, replacement: "[" + selected + "]()", selection: caret ..< caret)
    }

    static func string(_ units: some Collection<UInt16>) -> String {
        String(decoding: units, as: UTF16.self)
    }
}

/// The lines a selection touches. A selection that ends at a line start does
/// not touch that line.
private struct Lines {
    let units: [UInt16]
    let selection: Range<Int>
    /// UTF-16 ranges of each line, without line endings.
    let ranges: [Range<Int>]

    init(_ units: [UInt16], _ selection: Range<Int>) {
        self.units = units
        self.selection = selection
        let start = units[..<selection.lowerBound].lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
        let lastOffset = selection.isEmpty ? selection.upperBound : max(selection.lowerBound, selection.upperBound - 1)
        let end = units[lastOffset...].firstIndex(of: 0x0A) ?? units.count
        var ranges: [Range<Int>] = []
        var lineStart = start
        for index in start ..< end where units[index] == 0x0A {
            ranges.append(lineStart ..< index)
            lineStart = index + 1
        }
        ranges.append(lineStart ..< end)
        self.ranges = ranges
    }

    var count: Int {
        ranges.count
    }

    var range: Range<Int> {
        ranges[0].lowerBound ..< ranges[ranges.count - 1].upperBound
    }

    func text(_ index: Int) -> String {
        FormatCommands.string(units[ranges[index]])
    }

    /// Replaces each line. A caret moves with its text; a selection that
    /// starts at the first line's start keeps that start and covers the
    /// changed lines.
    func edit(_ transform: (String) -> String) -> TextEdit {
        let replaced = ranges.indices.map { transform(text($0)) }
        let replacement = replaced.joined(separator: "\n")
        let start = range.lowerBound
        guard selection.isEmpty else {
            let lowerBound = selection.lowerBound == start ? start : selection.lowerBound + replaced[0].utf16
                .count - text(0).utf16.count
            return TextEdit(
                range: range,
                replacement: replacement,
                selection: lowerBound ..< start + replacement.utf16.count
            )
        }
        let caret = max(start, selection.lowerBound + replaced[0].utf16.count - text(0).utf16.count)
        return TextEdit(range: range, replacement: replacement, selection: caret ..< caret)
    }
}
