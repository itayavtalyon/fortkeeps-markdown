import Foundation

/// What Paste inserts (design log 001 › Paste).
public enum PasteConverter {
    /// The plain text when `pasteHtml` is off, when there is no HTML, or when
    /// the conversion is whitespace only; else the converted Markdown.
    public static func pasteText(
        html: String?,
        plainText: String,
        features: MarkdownFeatures,
        documentURL: URL?
    ) -> String {
        guard features.pasteHtml, let html else { return plainText }
        let markdown = markdown(fromHTML: html, documentURL: documentURL)
        return markdown.allSatisfy(\.isWhitespace) ? plainText : markdown
    }

    /// CommonMark and GFM for an HTML fragment, by the table in Design › Paste.
    public static func markdown(fromHTML html: String, documentURL: URL?) -> String {
        MarkdownRenderer(documentURL: documentURL).blocks(HTMLParser.parse(html)).map(\.text).joined(separator: "\n\n")
    }
}

/// Renders an HTML tree as Markdown blocks.
struct MarkdownRenderer {
    struct Block {
        let text: String
        let isList: Bool
    }

    let documentURL: URL?

    func blocks(_ nodes: [HTMLNode]) -> [Block] {
        var result: [Block] = []
        var inline: [HTMLNode] = []
        func flush() {
            let text = InlineRenderer(documentURL: documentURL, singleLine: false, escapesPipes: false)
                .paragraph(inline)
            if !text.isEmpty {
                result.append(Block(text: text, isList: false))
            }
            inline = []
        }
        for node in nodes {
            guard isBlock(node) else {
                inline.append(node)
                continue
            }
            flush()
            result += block(node)
        }
        flush()
        return result
    }

    /// An element is a block when its tag is, or when it holds a block.
    private func isBlock(_ node: HTMLNode) -> Bool {
        let name = node.name
        guard !node.isText else { return false }
        if name == "code" {
            return node.textContent.contains("\n")
        }
        return HTMLParser.blockElements.contains(name) || node.children.contains(where: isBlock)
    }

    private func block(_ node: HTMLNode) -> [Block] {
        let name = node.name
        switch name {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let text = InlineRenderer(documentURL: documentURL, singleLine: true, escapesPipes: false)
                .paragraph(node.children)
            // The tag names h1 to h6 end in their level.
            let level = name.last!.wholeNumberValue! // swiftlint:disable:this force_unwrapping
            return text.isEmpty ? [] : [Block(text: String(repeating: "#", count: level) + " " + text, isList: false)]
        case "pre", "code":
            return [Block(text: fenced(node.textContent), isList: false)]
        case "ul", "ol":
            return [Block(text: list(node, ordered: name == "ol"), isList: true)]
        case "blockquote":
            let inner = blocks(node.children).map(\.text).joined(separator: "\n\n")
            let quoted = inner.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.isEmpty ? ">" : "> " + $0 }
            return inner.isEmpty ? [] : [Block(text: quoted.joined(separator: "\n"), isList: false)]
        case "table":
            return TableRenderer(documentURL: documentURL).table(node).map { [Block(text: $0, isList: false)] } ?? []
        default:
            return blocks(node.children)
        }
    }

    /// A fence longer than any backtick run in the code.
    private func fenced(_ code: String) -> String {
        var body = code.hasPrefix("\n") ? String(code.dropFirst()) : code
        if body.hasSuffix("\n") {
            body.removeLast()
        }
        let longest = body.split(whereSeparator: { $0 != "`" }).reduce(0) { max($0, $1.count) }
        let fence = String(repeating: "`", count: max(3, longest + 1))
        return fence + "\n" + body + "\n" + fence
    }

    /// A list item's blocks: the first after the marker, the rest indented by
    /// the marker's width. A nested list follows on the next line.
    private func list(_ node: HTMLNode, ordered: Bool) -> String {
        var number = Int(node.attribute("start") ?? "") ?? 1
        var items: [String] = []
        for item in node.children where item.name == "li" {
            let marker = ordered ? "\(number)." : "-"
            number += 1
            var children = item.children
            let task = Self.taskPrefix(removingFrom: &children)
            let itemBlocks = blocks(children)
            let indent = String(repeating: " ", count: marker.count + 1)
            var text = ""
            for (index, block) in itemBlocks.enumerated() {
                if index > 0 {
                    text += block.isList ? "\n" : "\n\n"
                }
                text += block.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { line in
                    index == 0 && line.offset == 0 ? String(line.element) : line.element.isEmpty ? "" : indent + line
                        .element
                }.joined(separator: "\n")
            }
            items.append((marker + " " + task + text).trimmingCharacters(in: .whitespaces))
        }
        return items.joined(separator: "\n")
    }

    /// `[x] ` or `[ ] ` when the item starts with a checkbox input, which is removed.
    private static func taskPrefix(removingFrom children: inout [HTMLNode]) -> String {
        guard let index = children
            .firstIndex(where: { !($0.textContent.allSatisfy(\.isWhitespace) && $0.name != "input") }),
            children[index].name == "input", children[index].attribute("type")?.lowercased() == "checkbox"
        else { return "" }
        let checked = children[index].attribute("checked") != nil
        children.removeSubrange(0 ... index)
        return checked ? "[x] " : "[ ] "
    }
}

/// A GFM table: the `thead` row or the first row is the header, a `colspan`
/// cell puts its content in the first cell and empty cells after it.
struct TableRenderer {
    let documentURL: URL?

    func table(_ node: HTMLNode) -> String? {
        var rows: [(cells: [String], isHead: Bool)] = []
        func collect(_ node: HTMLNode, isHead: Bool) {
            for child in node.children {
                switch child.name {
                case "tr":
                    rows.append((cells(of: child), isHead))
                case "thead":
                    collect(child, isHead: true)
                case "tbody", "tfoot":
                    collect(child, isHead: false)
                default:
                    break
                }
            }
        }
        collect(node, isHead: false)
        guard !rows.isEmpty else { return nil }
        let headIndex = rows.firstIndex(where: \.isHead) ?? 0
        let ordered = [rows[headIndex].cells] + rows.enumerated().filter { $0.offset != headIndex }.map(\.element.cells)
        let width = ordered.reduce(0) { max($0, $1.count) }
        let padded = ordered.map { $0 + Array(repeating: "", count: width - $0.count) }
        let line: ([String]) -> String = { "| " + $0.joined(separator: " | ") + " |" }
        return ([line(padded[0]), line(Array(repeating: "---", count: width))] + padded.dropFirst().map(line))
            .joined(separator: "\n")
    }

    private func cells(of row: HTMLNode) -> [String] {
        row.children.filter { $0.name == "td" || $0.name == "th" }.flatMap { cell in
            let span = min(max(Int(cell.attribute("colspan") ?? "") ?? 1, 1), 1000)
            let text = InlineRenderer(documentURL: documentURL, singleLine: true, escapesPipes: true)
                .paragraph(cell.children)
            return [text] + Array(repeating: "", count: span - 1)
        }
    }
}
