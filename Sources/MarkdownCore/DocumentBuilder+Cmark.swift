import cmark_gfm

/// Source positions and cmark node access.
extension DocumentBuilder {
    /// The byte range of a node, from its 1-based line and column positions.
    func span(of node: Node) -> Range<Int> {
        let start = offset(line: node.pointee.start_line, column: node.pointee.start_column)
        let end = offset(line: node.pointee.end_line, column: node.pointee.end_column + 1)
        return start ..< max(start, end)
    }

    /// A node with no position (a soft break) sits at the end of the last run.
    private func offset(line: Int32, column: Int32) -> Int {
        guard line > 0 else { return sourceEnd }
        let start = lineStarts[min(Int(line) - 1, lineStarts.count - 1)]
        return min(max(start + Int(column) - 1, 0), bytes.count)
    }

    /// The byte between `[` and `]` of a task item: after the list marker and
    /// its spaces, where the fork's tasklist extension finds it.
    func markerOffset(of item: Node) -> Int {
        var position = offset(line: item.pointee.start_line, column: item.pointee.start_column)
        if [UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "+")].contains(bytes[position]) {
            position += 1
        } else {
            while Character(Unicode.Scalar(bytes[position])).isNumber {
                position += 1
            }
            position += 1
        }
        while [UInt8(ascii: " "), UInt8(ascii: "\t")].contains(bytes[position]) {
            position += 1
        }
        precondition(bytes[position] == UInt8(ascii: "["))
        return position + 1
    }

    static func children(of node: Node) -> [Node] {
        var children: [Node] = []
        var child = cmark_node_first_child(node)
        while let current = child {
            children.append(current)
            child = cmark_node_next(current)
        }
        return children
    }

    static func typeName(_ node: Node) -> String {
        String(cString: cmark_node_get_type_string(node))
    }

    static func url(_ node: Node) -> String {
        // A link or an image always carries a URL, empty or not.
        String(cString: cmark_node_get_url(node)!) // swiftlint:disable:this force_unwrapping
    }

    /// The line-level kind of a node, or nil for a container.
    static func leafKind(of node: Node) -> RenderedText.BlockKind? {
        switch typeName(node) {
        case "paragraph": .paragraph
        case "heading": .heading(level: Int(cmark_node_get_heading_level(node)))
        case "code_block": .codeBlock
        case "html_block": .htmlBlock
        case "thematic_break": .thematicBreak
        case "table_header": .tableRow(isHeader: true)
        case "table_row": .tableRow(isHeader: false)
        default: nil
        }
    }

    static func kind(of node: Node) -> MarkdownDocument.BlockKind {
        switch typeName(node) {
        case "heading": .heading(level: Int(cmark_node_get_heading_level(node)))
        case "list": cmark_node_get_list_type(node) == CMARK_ORDERED_LIST ? .orderedList : .bulletList
        case "block_quote": .quote
        case "code_block": .codeBlock(fenced: node.pointee.as.code.fenced != 0)
        case "html_block": .htmlBlock
        case "table": .table
        case "thematic_break": .thematicBreak
        default: .paragraph
        }
    }
}
