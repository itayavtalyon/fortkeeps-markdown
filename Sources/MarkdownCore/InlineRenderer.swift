import Foundation

/// The inline Markdown of HTML nodes: emphasis, code spans, links, images,
/// and text escaped only where a character would otherwise start syntax.
struct InlineRenderer {
    let documentURL: URL?
    /// A heading or a table cell: `br` is a space.
    let singleLine: Bool
    /// A table cell: `|` is escaped.
    let escapesPipes: Bool

    enum Atom: Equatable {
        case text(String)
        case markup(String)
        case lineBreak
    }

    func paragraph(_ nodes: [HTMLNode]) -> String {
        assemble(collapse(nodes.flatMap(atoms)))
    }

    // MARK: atoms

    func atoms(_ node: HTMLNode) -> [Atom] {
        guard !node.isText else { return [.text(Self.collapseWhitespace(node.text))] }
        let children = node.children
        switch node.name {
        case "br": return singleLine ? [.text(" ")] : [.lineBreak]
        case "strong", "b": return wrapped("**", children)
        case "em", "i": return wrapped("*", children)
        case "del", "s", "strike": return wrapped("~~", children)
        case "code": return [.markup(Self.codeSpan(Self.collapseWhitespace(node.textContent)))]
        case "a": return link(node)
        case "img": return image(node)
        case "input", "script", "style": return []
        default: return children.flatMap(atoms)
        }
    }

    /// Spaces at the edge of an emphasis move outside it, where they keep
    /// the delimiters flanking.
    private func wrapped(_ delimiter: String, _ children: [HTMLNode]) -> [Atom] {
        var inner = children.flatMap(atoms)
        guard inner.contains(where: {
            if case let .text(text) = $0 {
                !text.allSatisfy(\.isWhitespace)
            } else {
                true
            }
        })
        else { return inner }
        var before: [Atom] = []
        var after: [Atom] = []
        if case let .text(text) = inner.first, text.hasPrefix(" ") {
            inner[0] = .text(String(text.drop { $0 == " " }))
            before = [.text(" ")]
        }
        if case let .text(text) = inner.last, text.hasSuffix(" ") {
            inner[inner.count - 1] = .text(String(text.reversed().drop { $0 == " " }.reversed()))
            after = [.text(" ")]
        }
        return before + [.markup(delimiter)] + inner + [.markup(delimiter)] + after
    }

    /// `[text](href)` for an https or mailto href; the text only for any other.
    /// A `]` in the label is escaped, so pasted text cannot close the label
    /// and open a link of its own.
    private func link(_ node: HTMLNode) -> [Atom] {
        let inner = node.children.flatMap(atoms)
        guard let href = node.attribute("href"), ["https", "mailto"].contains(URLScheme.of(href) ?? ""), !inner.isEmpty
        else { return inner }
        return [.markup("[")] + Self.protectClosingBrackets(inner) + [.markup("](" + Self.destination(href) + ")")]
    }

    /// Splits `]` out of text atoms as the markup `\]`. Markup stays markup,
    /// so a code span can still contain a bracket, and the later escape pass
    /// does not turn the backslash into a second one.
    private static func protectClosingBrackets(_ atoms: [Atom]) -> [Atom] {
        atoms.flatMap { atom -> [Atom] in
            guard case let .text(text) = atom, text.contains("]") else { return [atom] }
            var result: [Atom] = []
            var current = ""
            for character in text {
                if character == "]" {
                    if !current.isEmpty {
                        result.append(.text(current))
                        current = ""
                    }
                    result.append(.markup(#"\]"#))
                } else {
                    current.append(character)
                }
            }
            if !current.isEmpty {
                result.append(.text(current))
            }
            return result
        }
    }

    /// `![alt](src)` when the image rules allow the source; the alt text otherwise.
    private func image(_ node: HTMLNode) -> [Atom] {
        let alt = node.attribute("alt") ?? ""
        guard let source = node.attribute("src"),
              ImageRules.classify(source, documentURL: documentURL) != .refused
        else {
            return [.text(Self.collapseWhitespace(alt))]
        }
        return [.markup("![" + Self.backslashed(alt, "\\[]") + "](" + Self.destination(source) + ")")]
    }

    /// A destination as it reads back: a backslash escapes itself, and a
    /// destination with a space or a bracket goes in angle brackets with its
    /// `<` and `>` escaped, so it cannot close early and start new syntax.
    /// The URL standard drops tabs and line breaks from a URL.
    static func destination(_ url: String) -> String {
        let url = backslashed(String(url.unicodeScalars.filter { !"\t\n\r".unicodeScalars.contains($0) }), "\\")
        return url.contains(where: { " ()<>".contains($0) }) ? "<" + backslashed(url, "<>") + ">" : url
    }

    /// The text with a backslash before each character of `characters`.
    static func backslashed(_ text: String, _ characters: String) -> String {
        text.reduce(into: "") { result, character in
            if characters.contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
    }

    /// A backtick run longer than any inside, padded when the code starts or
    /// ends with a backtick.
    static func codeSpan(_ code: String) -> String {
        let longest = code.split(whereSeparator: { $0 != "`" }).reduce(0) { max($0, $1.count) }
        let fence = String(repeating: "`", count: longest + 1)
        let pad = code.hasPrefix("`") || code.hasSuffix("`") ? " " : ""
        return fence + pad + code + pad + fence
    }

    /// HTML whitespace (space, tab, line feed, carriage return, form feed)
    /// collapses to one space. A no-break space stays.
    static func collapseWhitespace(_ text: String) -> String {
        text.replacing(/[ \t\n\r\f]+/, with: " ")
    }

    // MARK: assembly

    /// One space between words across atoms, none at a line's start or end.
    func collapse(_ atoms: [Atom]) -> [Atom] {
        var result: [Atom] = []
        var afterSpace = true
        // Drops the space that ends the last text atom, when only empty
        // text follows it.
        func trimTrailingSpace() {
            guard let index = result.lastIndex(where: { $0 != .text("") }),
                  case let .text(text) = result[index], text.hasSuffix(" ")
            else { return }
            result[index] = .text(String(text.dropLast()))
        }
        for atom in atoms {
            switch atom {
            case let .text(text):
                var kept = ""
                for character in text {
                    if character == " " {
                        if !afterSpace {
                            kept.append(character)
                        }
                        afterSpace = true
                    } else {
                        kept.append(character)
                        afterSpace = false
                    }
                }
                result.append(.text(kept))
            case .markup:
                result.append(atom)
                afterSpace = false
            case .lineBreak:
                trimTrailingSpace()
                result.append(atom)
                afterSpace = true
            }
        }
        trimTrailingSpace()
        return result.filter { $0 != .text("") }
    }

    func assemble(_ atoms: [Atom]) -> String {
        var output = ""
        for (index, atom) in atoms.enumerated() {
            switch atom {
            case let .text(text):
                let next = atoms[(index + 1)...].lazy.compactMap { atom -> Character? in
                    switch atom {
                    case let .text(text), let .markup(text): text.first
                    case .lineBreak: "\n"
                    }
                }.first
                let atLineStart = output.isEmpty || output.hasSuffix("\n")
                output += MarkdownEscaper(escapesPipes: escapesPipes)
                    .escape(text, atLineStart: atLineStart, previous: atLineStart ? nil : output.last, next: next)
            case let .markup(text):
                output += text
            case .lineBreak:
                output += "\\\n"
            }
        }
        return output
    }
}
