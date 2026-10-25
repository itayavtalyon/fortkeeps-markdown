import cmark_gfm
import cmark_gfm_extensions
import Foundation

/// One cmark-gfm parse of a text with the extensions that `features` turns on
/// (design log 001 › Parse). The instance owns the parser and the tree, and
/// frees both. The parser stays alive because rendering needs its extension list.
final class ParsedMarkdown {
    typealias Node = UnsafeMutablePointer<cmark_node>
    typealias Parser = UnsafeMutablePointer<cmark_parser>

    let root: Node
    private let parser: Parser
    private let features: MarkdownFeatures

    init(_ text: String, features: MarkdownFeatures) {
        self.features = features
        parser = Self.makeParser(options: CMARK_OPT_DEFAULT, features: features)
        root = Self.parse(text, with: parser)
        if !features.html {
            Self.showHTMLAsText(in: root, features: features)
        }
    }

    deinit {
        cmark_node_free(root)
        cmark_parser_free(parser)
    }

    /// cmark-gfm's HTML for the tree. Raw HTML passes through only when
    /// `html` is true; the tag filter then shows the disallowed tags as text.
    func html() -> String {
        var options = CMARK_OPT_DEFAULT
        if features.html {
            options |= CMARK_OPT_UNSAFE
        }
        if features.softBreakAsLine {
            options |= CMARK_OPT_HARDBREAKS
        }
        // NULL only when malloc fails.
        let rendered = cmark_render_html(
            root,
            options,
            cmark_parser_get_syntax_extensions(parser)
        )! // swiftlint:disable:this force_unwrapping
        defer { free(rendered) }
        return String(cString: rendered)
    }

    private static func parse(_ text: String, with parser: Parser) -> Node {
        cmark_parser_feed(parser, text, text.utf8.count)
        return cmark_parser_finish(parser)! // swiftlint:disable:this force_unwrapping - NULL only when malloc fails
    }

    private static func makeParser(options: Int32, features: MarkdownFeatures) -> Parser {
        cmark_gfm_core_extensions_ensure_registered()
        let parser = cmark_parser_new(options)! // swiftlint:disable:this force_unwrapping - NULL only when malloc fails
        let extensions = [
            ("table", features.tables),
            ("strikethrough", features.strikethrough),
            ("autolink", features.autolink),
            ("tagfilter", features.html),
            ("tasklist", features.taskLists)
        ]
        for (name, isOn) in extensions where isOn {
            // NULL only for a name the core extensions do not register.
            let syntax = cmark_find_syntax_extension(name)! // swiftlint:disable:this force_unwrapping
            cmark_parser_attach_syntax_extension(parser, syntax)
        }
        return parser
    }

    /// C0 controls that are inert in Markdown, tried in turn as a same-length
    /// stand-in for a neutralized `<`. Tab, LF, VT, FF, and CR are whitespace.
    static let sentinels: [Unicode.Scalar] = (UInt8(0x01) ... 0x1F)
        .filter { !(0x09 ... 0x0D).contains($0) }
        .map(Unicode.Scalar.init)

    /// `html` false: inline HTML becomes text, and an HTML block is parsed again
    /// as Markdown with every line that would open an HTML block neutralized.
    /// markdown-it with `html: false` (the log 010 reference) never builds an
    /// HTML block, and cmark always does. A sentinel of the same byte length
    /// keeps every source offset; a backslash is the fallback when the block
    /// already holds every sentinel.
    private static func showHTMLAsText(in root: Node, features: MarkdownFeatures) {
        nodes(in: root, ofType: [CMARK_NODE_HTML_INLINE]).forEach(makeText)
        for block in nodes(in: root, ofType: [CMARK_NODE_HTML_BLOCK]) {
            let lines = literal(of: block)
            let sentinel = sentinels.first { !lines.unicodeScalars.contains($0) }
            let replacement = sentinel.map(String.init) ?? "\\<"
            let neutral = lines.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
                .map { neutralize($0.element, with: replacement, isOpener: $0.offset == 0) }
                .joined(separator: "\n")
            let snippet = ParsedMarkdown(neutral, features: features)
            if let sentinel {
                restore(sentinel, in: snippet.root)
            }
            while let child = cmark_node_first_child(snippet.root) {
                cmark_node_insert_before(block, child)
            }
            cmark_node_free(block)
        }
    }

    /// The block's first line always opens it, so it is neutralized without a
    /// probe: the next parse cannot rebuild the same block, and each nested
    /// block it finds is shorter. Any HTML block opens with `<` after at most
    /// three spaces, so only such a later line needs the probe parse.
    private static func neutralize(_ line: Substring, with replacement: String, isOpener: Bool) -> String {
        let bracket = line.firstIndex { $0 != " " } ?? line.endIndex
        let indent = line.distance(from: line.startIndex, to: bracket)
        let startsWithBracket = indent < 4 && line[bracket...].first == "<"
        guard isOpener || (startsWithBracket && opensHTMLBlock(line)) else { return String(line) }
        precondition(startsWithBracket)
        return line[..<bracket] + replacement + line[line.index(after: bracket)...]
    }

    /// HTML blocks are core CommonMark, so the probe attaches no extension.
    private static func opensHTMLBlock(_ line: Substring) -> Bool {
        // NULL only when malloc fails.
        let parser = cmark_parser_new(CMARK_OPT_DEFAULT)! // swiftlint:disable:this force_unwrapping
        defer { cmark_parser_free(parser) }
        let root = parse(String(line), with: parser)
        defer { cmark_node_free(root) }
        return cmark_node_get_type(cmark_node_first_child(root)) == CMARK_NODE_HTML_BLOCK
    }

    private static func restore(_ sentinel: Unicode.Scalar, in root: Node) {
        for node in nodes(in: root, ofType: [CMARK_NODE_TEXT, CMARK_NODE_CODE]) {
            let characters = literal(of: node)
            if characters.unicodeScalars.contains(sentinel) {
                cmark_node_set_literal(node, characters.replacingOccurrences(of: String(sentinel), with: "<"))
            }
        }
    }

    /// The nodes of the given leaf types, in document order. A leaf node gets
    /// only an enter event, so each node appears once.
    private static func nodes(in root: Node, ofType types: [cmark_node_type]) -> [Node] {
        var found: [Node] = []
        let iterator = cmark_iter_new(root)
        defer { cmark_iter_free(iterator) }
        while cmark_iter_next(iterator) != CMARK_EVENT_DONE {
            if let node = cmark_iter_get_node(iterator), types.contains(cmark_node_get_type(node)) {
                found.append(node)
            }
        }
        return found
    }

    /// Keeps the node, its source position, and its characters; only the type changes.
    private static func makeText(_ node: Node) {
        let characters = literal(of: node)
        // A text node fits wherever an inline HTML node fits.
        precondition(cmark_node_set_type(node, CMARK_NODE_TEXT) == 1)
        cmark_node_set_literal(node, characters)
    }

    private static func literal(of node: Node) -> String {
        // HTML, text, and code nodes always carry a literal.
        String(cString: cmark_node_get_literal(node)!) // swiftlint:disable:this force_unwrapping
    }
}
