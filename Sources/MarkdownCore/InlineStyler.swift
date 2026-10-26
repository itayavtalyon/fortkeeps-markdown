import cmark_gfm
import cmark_gfm_extensions

/// The inline spans of one editor line's content, from an inline-only cmark
/// parse. A line is one line of input, so cmark's inline positions hold here,
/// except for the autolink extension's, which are found by search.
struct InlineStyler {
    typealias Span = MarkdownStyler.StyleSpan
    typealias Node = ParsedMarkdown.Node

    let features: MarkdownFeatures

    /// Spans in line UTF-16 offsets for the content range of `units`.
    func spans(in units: [UInt16], content: Range<Int>) -> [Span] {
        guard !content.isEmpty else { return [] }
        let text = String(decoding: units[content], as: UTF16.self)
        var walker = Walker(bytes: Array(text.utf8), unitOffset: Self.unitOffsets(of: text), base: content.lowerBound)
        cmark_gfm_core_extensions_ensure_registered()
        // NULL only when malloc fails.
        let parser = cmark_parser_new(CMARK_OPT_INLINE_ONLY)! // swiftlint:disable:this force_unwrapping
        defer { cmark_parser_free(parser) }
        for (name, isOn) in [("strikethrough", features.strikethrough), ("autolink", features.autolink)] where isOn {
            // NULL only for a name the core extensions do not register.
            let syntax = cmark_find_syntax_extension(name)! // swiftlint:disable:this force_unwrapping
            cmark_parser_attach_syntax_extension(parser, syntax)
        }
        cmark_parser_feed(parser, text, text.utf8.count)
        let root = cmark_parser_finish(parser)! // swiftlint:disable:this force_unwrapping - NULL only when malloc fails
        defer { cmark_node_free(root) }
        walker.walk(root)
        return walker.spans
    }

    /// The UTF-16 offset of each UTF-8 byte offset of the text, and of its end.
    private static func unitOffsets(of text: String) -> [Int] {
        var offsets: [Int] = []
        var unit = 0
        for scalar in text.unicodeScalars {
            offsets += Array(repeating: unit, count: scalar.utf8.count)
            unit += scalar.utf16.count
        }
        return offsets + [unit]
    }

    private struct Walker {
        let bytes: [UInt8]
        let unitOffset: [Int]
        let base: Int
        var spans: [Span] = []
        /// Where the next bare-URL search starts.
        var searchFrom = 0

        init(bytes: [UInt8], unitOffset: [Int], base: Int) {
            self.bytes = bytes
            self.unitOffset = unitOffset
            self.base = base
        }

        mutating func add(_ bytes: Range<Int>, _ token: MarkdownStyler.StyleToken) {
            spans.append(Span(
                range: base + unitOffset[bytes.lowerBound] ..< base + unitOffset[bytes.upperBound],
                token: token
            ))
        }

        /// A node's byte range from its 1-based inclusive columns.
        func range(of node: Node) -> Range<Int> {
            let start = min(max(Int(node.pointee.start_column) - 1, 0), bytes.count)
            return start ..< min(max(Int(node.pointee.end_column), start), bytes.count)
        }

        /// The range from the first child's start to the last child's end, or
        /// an empty range at `fallback`.
        func childRange(of node: Node, fallback: Int) -> Range<Int> {
            guard let first = cmark_node_first_child(node), let last = cmark_node_last_child(node) else {
                return fallback ..< fallback
            }
            return range(of: first).lowerBound ..< max(range(of: first).lowerBound, range(of: last).upperBound)
        }

        mutating func walk(_ node: Node) {
            for child in DocumentBuilder.children(of: node) {
                switch DocumentBuilder.typeName(child) {
                case "emph": wrapped(child, .emphasis)
                case "strong": wrapped(child, .strong)
                case "strikethrough": wrapped(child, .strikethrough)
                case "code": code(child)
                case "link", "image": link(child)
                default: walk(child)
                }
            }
        }

        /// Delimiters around the children, the token over them.
        private mutating func wrapped(_ node: Node, _ token: MarkdownStyler.StyleToken) {
            let outer = range(of: node)
            let inner = childRange(of: node, fallback: outer.lowerBound)
            add(outer.lowerBound ..< inner.lowerBound, .syntax)
            add(inner, token)
            walk(node)
            add(inner.upperBound ..< outer.upperBound, .syntax)
        }

        /// cmark gives a code span's content; the backtick runs sit around it,
        /// past any padding space.
        private mutating func code(_ node: Node) {
            let content = range(of: node)
            let count = Int(node.pointee.backtick_count)
            var open = content.lowerBound
            while open > 0, bytes[open - 1] != UInt8(ascii: "`") {
                open -= 1
            }
            var close = content.upperBound
            while close < bytes.count, bytes[close] != UInt8(ascii: "`") {
                close += 1
            }
            add(max(0, open - count) ..< open, .syntax)
            add(open ..< close, .code)
            add(close ..< min(bytes.count, close + count), .syntax)
        }

        /// `[text](url)`, `![alt](url)`, `<url>`, or a bare URL from the
        /// autolink extension, whose positions are not kept.
        private mutating func link(_ node: Node) {
            let outer = range(of: node)
            let isImage = DocumentBuilder.typeName(node) == "image"
            let opener = isImage ? Array("![".utf8) : Array("[".utf8)
            if bytes[outer.lowerBound...].starts(with: opener) {
                let inner = childRange(of: node, fallback: outer.lowerBound + opener.count)
                add(outer.lowerBound ..< inner.lowerBound, .syntax)
                if !isImage {
                    add(inner, .link)
                    walk(node)
                }
                add(inner.upperBound ..< outer.upperBound, .syntax)
            } else if bytes[outer.lowerBound...].starts(with: Array("<".utf8)) {
                add(outer.lowerBound ..< outer.lowerBound + 1, .syntax)
                add(outer.lowerBound + 1 ..< outer.upperBound - 1, .link)
                add(outer.upperBound - 1 ..< outer.upperBound, .syntax)
            } else {
                bareURL(DocumentBuilder.plainText(of: node))
            }
        }

        private mutating func bareURL(_ text: String) {
            let encoded = Array(text.utf8)
            guard !encoded.isEmpty,
                  let start = (searchFrom ..< bytes.count).first(where: { bytes[$0...].starts(with: encoded) })
            else { return }
            add(start ..< start + encoded.count, .link)
            searchFrom = start + encoded.count
        }
    }
}
