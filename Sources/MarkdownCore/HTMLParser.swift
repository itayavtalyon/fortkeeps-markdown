import cmark_gfm

/// A parsed piece of pasted HTML: an element, or text with an empty name.
struct HTMLNode: Equatable {
    let name: String
    let attributes: [String: String]
    let children: [HTMLNode]
    let text: String

    init(name: String, attributes: [String: String], children: [HTMLNode]) {
        self.name = name
        self.attributes = attributes
        self.children = children
        text = ""
    }

    init(text: String) {
        name = ""
        attributes = [:]
        children = []
        self.text = text
    }

    var isText: Bool {
        name.isEmpty
    }

    func attribute(_ name: String) -> String? {
        attributes[name]
    }

    /// The text of the node and its descendants; `br` is a line break.
    var textContent: String {
        isText ? text : name == "br" ? "\n" : children.map(\.textContent).joined()
    }
}

/// A hand-written HTML tokenizer and tree builder for Paste (design log 001 ›
/// Paste). It drops comments, doctypes, and the bodies of `script` and `style`.
/// It closes elements the way HTML implies (`p`, `li`, table rows and cells).
enum HTMLParser {
    enum Token: Equatable {
        case start(String, [String: String])
        case end(String)
        case text(String)
    }

    /// Deeper elements are added to the deepest open one, so a hostile paste
    /// cannot overflow the stack of a recursive walk. At 256 a walk on a test
    /// thread overflowed (signal 10); pasted documents nest a few dozen deep.
    static let maximumDepth = 64

    static let voidElements: Set = ["br", "img", "input", "hr", "meta", "link", "wbr", "col", "area", "base", "source"]
    static let rawTextElements: Set = ["script", "style"]
    static let blockElements: Set = [
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "pre", "blockquote", "table", "thead",
        "tbody",
        "tfoot", "tr", "td", "th", "section", "article", "header", "footer", "nav", "aside", "main", "figure",
        "figcaption",
        "address", "dl", "dt", "dd", "hr", "form", "fieldset", "details", "summary"
    ]

    static func parse(_ html: String) -> [HTMLNode] {
        build(tokens(html))
    }

    // MARK: tokens

    static func tokens(_ html: String) -> [Token] {
        let bytes = Array(html.utf8)
        var tokens: [Token] = []
        var position = 0
        var textStart = 0
        func flushText(upTo end: Int) {
            if textStart < end {
                tokens.append(.text(decode(bytes[textStart ..< end])))
            }
        }
        while position < bytes.count {
            guard bytes[position] == UInt8(ascii: "<"), let tag = readTag(bytes, at: position) else {
                position += 1
                continue
            }
            flushText(upTo: position)
            if let token = tag.token {
                tokens.append(token)
            }
            position = tag.end
            if case let .start(name, _) = tag.token, rawTextElements.contains(name) {
                position = rawTextEnd(bytes, from: position, name: name)
            }
            textStart = position
        }
        flushText(upTo: bytes.count)
        return tokens
    }

    /// A tag, comment, or declaration at `start`, or nil when `<` is text.
    private static func readTag(_ bytes: [UInt8], at start: Int) -> (token: Token?, end: Int)? {
        let next = start + 1 < bytes.count ? bytes[start + 1] : 0
        if bytes[start...].starts(with: Array("<!--".utf8)) {
            return (nil, find(Array("-->".utf8), in: bytes, from: start + 4).map { $0 + 3 } ?? bytes.count)
        }
        if next == UInt8(ascii: "!") || next == UInt8(ascii: "?") {
            return (nil, find([UInt8(ascii: ">")], in: bytes, from: start).map { $0 + 1 } ?? bytes.count)
        }
        if next == UInt8(ascii: "/"), start + 2 < bytes.count, isLetter(bytes[start + 2]) {
            let name = readName(bytes, from: start + 2)
            let end = find([UInt8(ascii: ">")], in: bytes, from: name.end).map { $0 + 1 } ?? bytes.count
            return (.end(name.text), end)
        }
        guard isLetter(next) else { return nil }
        let name = readName(bytes, from: start + 1)
        let attributes = readAttributes(bytes, from: name.end)
        return (.start(name.text, attributes.values), attributes.end)
    }

    private static func readName(_ bytes: [UInt8], from start: Int) -> (text: String, end: Int) {
        var end = start
        while end < bytes.count, isNameByte(bytes[end]) {
            end += 1
        }
        return (string(bytes[start ..< end]).lowercased(), end)
    }

    private static func readAttributes(_ bytes: [UInt8], from start: Int) -> (values: [String: String], end: Int) {
        var values: [String: String] = [:]
        var position = start
        while position < bytes.count {
            while position < bytes.count, isSpace(bytes[position]) || bytes[position] == UInt8(ascii: "/") {
                position += 1
            }
            guard position < bytes.count, bytes[position] != UInt8(ascii: ">") else { break }
            var nameEnd = position
            while nameEnd < bytes.count, !isSpace(bytes[nameEnd]), !Self.attributeEnds.contains(bytes[nameEnd]) {
                nameEnd += 1
            }
            let name = string(bytes[position ..< max(nameEnd, position + 1)]).lowercased()
            position = max(nameEnd, position + 1)
            var value = ""
            if position < bytes.count, bytes[position] == UInt8(ascii: "=") {
                (value, position) = readValue(bytes, from: position + 1)
            }
            values[name] = values[name] ?? value
        }
        return (values, min(position + 1, bytes.count))
    }

    private static func readValue(_ bytes: [UInt8], from start: Int) -> (String, Int) {
        var position = start
        while position < bytes.count, isSpace(bytes[position]) {
            position += 1
        }
        guard position < bytes.count else { return ("", position) }
        let quote = bytes[position]
        if quote == UInt8(ascii: "\"") || quote == UInt8(ascii: "'") {
            let end = find([quote], in: bytes, from: position + 1) ?? bytes.count
            return (decode(bytes[position + 1 ..< end]), min(end + 1, bytes.count))
        }
        var end = position
        while end < bytes.count, !isSpace(bytes[end]), bytes[end] != UInt8(ascii: ">") {
            end += 1
        }
        return (decode(bytes[position ..< end]), end)
    }

    /// The offset after `</name>` (any case), or the end of the input.
    private static func rawTextEnd(_ bytes: [UInt8], from start: Int, name: String) -> Int {
        let closing = Array("</\(name)".utf8)
        var position = start
        while let candidate = find([UInt8(ascii: "<")], in: bytes, from: position) {
            let slice = bytes[candidate ..< min(candidate + closing.count, bytes.count)]
            if slice.count == closing.count, zip(slice, closing).allSatisfy({ $0 | 0x20 == $1 | 0x20 }) {
                return find([UInt8(ascii: ">")], in: bytes, from: candidate).map { $0 + 1 } ?? bytes.count
            }
            position = candidate + 1
        }
        return bytes.count
    }

    private static func find(_ needle: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard start < bytes.count else { return nil }
        return (start ..< bytes.count).first { bytes[$0...].starts(with: needle) }
    }

    private static let attributeEnds: Set = [UInt8(ascii: "="), UInt8(ascii: ">"), UInt8(ascii: "/")]

    private static func isNameByte(_ byte: UInt8) -> Bool {
        isLetter(byte) || isDigit(byte) || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ":")
    }

    /// Bytes of a Swift string cut at ASCII bytes are valid UTF-8, and so is
    /// cmark's entity output.
    static func string(_ bytes: some Sequence<UInt8>) -> String {
        String(bytes: bytes, encoding: .utf8)! // swiftlint:disable:this force_unwrapping
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(byte | 0x20)
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(byte)
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        [UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"), 0x0C].contains(byte)
    }

    /// HTML entities, decoded by cmark's own HTML5 entity table.
    static func decode(_ bytes: ArraySlice<UInt8>) -> String {
        guard bytes.contains(UInt8(ascii: "&")) else { return string(bytes) }
        var buffer = cmark_strbuf()
        cmark_strbuf_init(cmark_get_default_mem_allocator(), &buffer, 0)
        defer { cmark_strbuf_free(&buffer) }
        Array(bytes).withUnsafeBufferPointer { source in
            houdini_unescape_html_f(&buffer, source.baseAddress, bufsize_t(source.count))
        }
        return string(UnsafeBufferPointer(start: buffer.ptr, count: Int(buffer.size)))
    }

    // MARK: tree

    private struct Open {
        let name: String
        let attributes: [String: String]
        var children: [HTMLNode] = []

        var node: HTMLNode {
            HTMLNode(name: name, attributes: attributes, children: children)
        }
    }

    static func build(_ tokens: [Token]) -> [HTMLNode] {
        var stack = [Open(name: "", attributes: [:])]
        func close(through index: Int) {
            while stack.count > index {
                let open = stack.removeLast()
                stack[stack.count - 1].children.append(open.node)
            }
        }
        for token in tokens {
            switch token {
            case let .text(text):
                stack[stack.count - 1].children.append(HTMLNode(text: text))
            case let .end(name):
                if let index = stack.lastIndex(where: { $0.name == name }), index > 0 {
                    close(through: index)
                }
            case let .start(name, attributes):
                if let index = impliedEnd(of: name, in: stack.map(\.name)) {
                    close(through: index)
                }
                if voidElements.contains(name) || rawTextElements.contains(name) {
                    stack[stack.count - 1].children.append(HTMLNode(name: name, attributes: attributes, children: []))
                } else if stack.count <= maximumDepth {
                    stack.append(Open(name: name, attributes: attributes))
                }
            }
        }
        close(through: 1)
        return stack[0].children
    }

    /// The stack index of an open element that a new start tag closes.
    private static func impliedEnd(of name: String, in open: [String]) -> Int? {
        func nearest(_ closed: Set<String>, within: Set<String>) -> Int? {
            guard let index = open.lastIndex(where: { closed.contains($0) || within.contains($0) }),
                  closed.contains(open[index])
            else { return nil }
            return index
        }
        if name == "li" {
            return nearest(["li"], within: ["ul", "ol"])
        }
        if name == "td" || name == "th" {
            return nearest(["td", "th"], within: ["tr", "table"])
        }
        if name == "tr" {
            return nearest(["tr"], within: ["table", "thead", "tbody", "tfoot"])
        }
        if ["thead", "tbody", "tfoot"].contains(name) {
            return nearest(["thead", "tbody", "tfoot"], within: ["table"])
        }
        return nil
    }
}
