/// The rendered characters and their runs (see `RenderedText.Run`).
extension DocumentBuilder {
    mutating func walkInlines(_ node: Node) {
        for child in Self.children(of: node) {
            switch Self.typeName(child) {
            case "text", "html_inline":
                appendAligned(Self.literal(child), from: span(of: child).lowerBound)
                directionText += Self.literal(child)
            case "code":
                appendAligned(Self.literal(child), from: span(of: child).lowerBound)
            case "softbreak":
                appendHidden(features.softBreakAsLine ? "\n" : " ", at: sourceEnd)
                directionText += " "
            case "linebreak":
                appendHidden("\n", at: sourceEnd)
                directionText += " "
            case "link":
                let start = length
                walkInlines(child)
                links.append(RenderedText.Link(
                    range: start ..< length,
                    destination: Self.url(child),
                    sourceRange: span(of: child)
                ))
            case "image":
                images.append(RenderedText.Image(
                    offset: length,
                    destination: Self.url(child),
                    alt: Self.plainText(of: child),
                    sourceRange: span(of: child)
                ))
                appendHidden("\u{FFFC}", source: span(of: child))
            default:
                walkInlines(child)
            }
        }
    }

    mutating func append(_ text: String) {
        string += text
        length += text.utf16.count
    }

    mutating func appendHidden(_ text: String, at offset: Int) {
        appendHidden(text, source: offset ..< offset)
    }

    mutating func appendHidden(_ text: String, source: Range<Int>) {
        runs.append(RenderedText.Run(
            rendered: length,
            renderedLength: text.utf16.count,
            source: source.lowerBound,
            sourceLength: source.count,
            text: nil
        ))
        append(text)
        sourceEnd = source.upperBound
    }

    /// Scalars that matched the same source bytes, collected into one run.
    private struct VerbatimRun {
        let rendered: Int
        let source: Int
        var text: String

        func continues(atSource source: Int, rendered: Int) -> Bool {
            self.source + text.utf8.count == source && self.rendered + text.utf16.count == rendered
        }

        var run: RenderedText.Run {
            RenderedText.Run(
                rendered: rendered,
                renderedLength: text.utf16.count,
                source: source,
                sourceLength: text.utf8.count,
                text: Substring(text)
            )
        }
    }

    /// Matches each scalar of `literal` to the source bytes it came from:
    /// the same bytes, the same bytes after a backslash escape, or an entity.
    /// Whitespace between them is skipped. A scalar with no match stands for
    /// one source character (cmark draws NUL as U+FFFD), which keeps the rest
    /// aligned.
    mutating func appendAligned(_ literal: String, from hint: Int) {
        // The autolink extension leaves empty text nodes with stray positions.
        guard !literal.isEmpty else { return }
        let end = max(hint, alignmentEnd)
        var cursor = alignmentStart(of: literal, hint: hint, end: end)
        var rendered = length
        var verbatim: VerbatimRun?
        let literalBytes = Array(literal.utf8)
        var literalOffset = 0
        for scalar in literal.unicodeScalars {
            let encoded = Array(String(scalar).utf8)
            let match = match(literalBytes[literalOffset...], length: encoded.count, from: cursor, before: end)
            literalOffset += encoded.count
            if case let .same(at) = match, verbatim?.continues(atSource: at, rendered: rendered) == true {
                verbatim?.text.unicodeScalars.append(scalar)
                cursor = at + encoded.count
                rendered += scalar.utf16.count
                continue
            }
            if let run = verbatim?.run {
                runs.append(run)
            }
            verbatim = nil
            switch match {
            case let .same(at):
                verbatim = VerbatimRun(rendered: rendered, source: at, text: String(scalar))
                cursor = at + encoded.count
            case let .entity(at, entityLength):
                runs.append(RenderedText.Run(
                    rendered: rendered, renderedLength: scalar.utf16.count, source: at, sourceLength: entityLength,
                    text: nil
                ))
                cursor = at + entityLength
            case .none:
                let consumed = cursor < end ? min(scalarLength(at: cursor), end - cursor) : 0
                runs.append(RenderedText.Run(
                    rendered: rendered, renderedLength: scalar.utf16.count, source: cursor, sourceLength: consumed,
                    text: nil
                ))
                cursor += consumed
            }
            rendered += scalar.utf16.count
        }
        if let run = verbatim?.run {
            runs.append(run)
        }
        append(literal)
        sourceEnd = cursor
    }

    /// Where an inline's characters start. swift-cmark 0.9.0 can shift the
    /// start of an inline after a line break inside a block (a lazy line, an
    /// indented line) by the block's indentation, and can end a paragraph
    /// early on a lazy line. When the whole literal does not align from the
    /// hint, the first offset after the last run where it does is used.
    private func alignmentStart(of literal: String, hint: Int, end: Int) -> Int {
        if hint >= sourceEnd, hint < end, aligns(literal, from: hint, before: end) {
            return hint
        }
        return (sourceEnd ..< max(sourceEnd, end)).first { aligns(literal, from: $0, before: end) } ?? max(
            hint,
            sourceEnd
        )
    }

    /// True when every scalar of the literal matches the source from the offset.
    private func aligns(_ literal: String, from start: Int, before end: Int) -> Bool {
        var cursor = start
        let literalBytes = Array(literal.utf8)
        var literalOffset = 0
        for scalar in literal.unicodeScalars {
            let length = scalar.utf8.count
            defer { literalOffset += length }
            switch match(literalBytes[literalOffset...], length: length, from: cursor, before: end) {
            case let .same(at): cursor = at + length
            case let .entity(at, length): cursor = at + length
            case .none: return false
            }
        }
        return true
    }

    private enum Match {
        case same(at: Int)
        case entity(at: Int, length: Int)
        case none
    }

    /// Matches the scalar that starts `rest` (`length` bytes). An entity is
    /// checked before the same byte: `&amp;` draws `&`, and matching that `&`
    /// alone would leave `amp;` in the way. Text that only looks like an
    /// entity (`&x;`) stays in the literal as it is, so it matches as itself.
    private func match(_ rest: ArraySlice<UInt8>, length: Int, from cursor: Int, before end: Int) -> Match {
        let encoded = rest.prefix(length)
        var position = cursor
        while position < end {
            if let entity = decodedEntity(at: position, before: end, rest: rest) {
                return .entity(at: position, length: entity)
            }
            if isEscape(of: encoded, at: position, before: end) {
                return .same(at: position + 1)
            }
            if bytes[position...].starts(with: encoded), position + encoded.count <= end {
                return .same(at: position)
            }
            guard Self.whitespace.contains(bytes[position]) else { return .none }
            position += 1
        }
        return .none
    }

    /// The length of an entity at the offset that the literal does not hold as text.
    private func decodedEntity(at position: Int, before end: Int, rest: ArraySlice<UInt8>) -> Int? {
        guard bytes[position] == UInt8(ascii: "&"),
              let entity = entityLength(at: position, before: end) else { return nil }
        return rest.starts(with: bytes[position ..< position + entity]) ? nil : entity
    }

    /// A backslash escape, also of a backslash. In a code span or a URL the
    /// backslash is a character, so a mismatch falls through to the plain match.
    private func isEscape(of encoded: ArraySlice<UInt8>, at position: Int, before end: Int) -> Bool {
        bytes[position] == UInt8(ascii: "\\") && position + 1 < end && bytes[(position + 1)...].starts(with: encoded)
    }

    private static let whitespace: Set<UInt8> = [
        UInt8(ascii: " "),
        UInt8(ascii: "\t"),
        UInt8(ascii: "\r"),
        UInt8(ascii: "\n")
    ]

    /// The UTF-8 length of the scalar that starts at the offset.
    private func scalarLength(at offset: Int) -> Int {
        switch bytes[offset] {
        case 0xF0...: 4
        case 0xE0...: 3
        case 0xC0...: 2
        default: 1
        }
    }

    /// The length of `&name;` or `&#digits;` at the offset.
    private func entityLength(at start: Int, before end: Int) -> Int? {
        let isNameByte: (UInt8) -> Bool = { byte in
            byte == UInt8(ascii: "#") || Character(Unicode.Scalar(byte)).isLetter || Character(Unicode.Scalar(byte))
                .isNumber
        }
        var position = start + 1
        while position < end, position - start <= 32, isNameByte(bytes[position]) {
            position += 1
        }
        let closes = position < end && bytes[position] == UInt8(ascii: ";")
        return closes ? position + 1 - start : nil
    }

    /// A code or HTML block, one literal line at a time.
    mutating func appendLines(_ literal: String, firstLine: Int) {
        guard !literal.isEmpty else { return }
        let body = literal.hasSuffix("\n") ? literal.dropLast() : Substring(literal)
        for (index, line) in body.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineIndex = min(firstLine - 1 + index, lineStarts.count - 1)
            let contentEnd = lineEnd(lineIndex)
            if index > 0 {
                appendHidden("\n", source: lineEnd(lineIndex - 1) ..< lineStarts[lineIndex])
            }
            // Each literal line ends its source line, after any container
            // prefix; cmark writes a partly consumed tab as spaces, so the line
            // is aligned character by character within its own source line.
            let blockEnd = alignmentEnd
            alignmentEnd = contentEnd
            sourceEnd = lineStarts[lineIndex]
            appendAligned(String(line), from: lineStarts[lineIndex])
            alignmentEnd = blockEnd
            sourceEnd = contentEnd
        }
    }

    /// The offset of the line ending (or the text end) of a 0-based line.
    func lineEnd(_ line: Int) -> Int {
        var end = line + 1 < lineStarts.count ? lineStarts[line + 1] : bytes.count
        while end > lineStarts[line], [UInt8(ascii: "\n"), UInt8(ascii: "\r")].contains(bytes[end - 1]) {
            end -= 1
        }
        return end
    }

    /// The drawn characters of a range, with each image as `Image: {alt}`.
    /// A U+FFFC typed in the text is not an image and stays.
    func visibleText(_ range: Range<Int>, in utf16: [UInt16]) -> String {
        var text = ""
        var start = range.lowerBound
        for unit in range where utf16[unit] == 0xFFFC {
            text += String(decoding: utf16[start ..< unit], as: UTF16.self)
            text += images.first { $0.offset == unit }.map { "Image: " + $0.alt } ?? "\u{FFFC}"
            start = unit + 1
        }
        return text + String(decoding: utf16[start ..< range.upperBound], as: UTF16.self)
    }
}
