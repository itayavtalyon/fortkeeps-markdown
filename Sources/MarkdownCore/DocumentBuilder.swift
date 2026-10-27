import cmark_gfm
import cmark_gfm_extensions
import Foundation

/// Walks a cmark tree once and builds the rendered text, its source map, the
/// blocks, and the tasks of a `MarkdownDocument`.
struct DocumentBuilder {
    typealias Node = ParsedMarkdown.Node

    struct Leaf {
        let kind: RenderedText.BlockKind
        let range: Range<Int>
        let sourceRange: Range<Int>
        let quoteDepth: Int
        let listDepth: Int
        let listMarker: RenderedText.ListMarker?
        let taskIndex: Int?
        let ownDirection: TextDirection?
    }

    struct PendingTask {
        let line: Int
        let byteOffset: Int
        let checked: Bool
    }

    let bytes: [UInt8]
    let lineStarts: [Int]
    let features: MarkdownFeatures

    var string = ""
    var length = 0
    var runs: [RenderedText.Run] = []
    var links: [RenderedText.Link] = []
    var images: [RenderedText.Image] = []
    /// Inline styles in rendered offsets: strong, emphasis, code, link, strikethrough.
    var styleSpans: [MarkdownStyler.StyleSpan] = []
    var topLevelBlocks: [MarkdownDocument.Block] = []
    var renderedBlocks: [RenderedText.Block] = []
    var tasks: [MarkdownDocument.Task] = []

    var leaves: [Leaf] = []
    /// Each leaf's characters without code spans, for the top-level direction.
    var leafTexts: [String] = []
    var leafDirections: [TextDirection] = []
    var pendingTasks: [PendingTask] = []
    var openTask: Int?
    /// The marker of the list item whose first leaf is next.
    var openMarker: RenderedText.ListMarker?
    /// The leaf that opens each task, by task index.
    var taskLeaves: [Int] = []
    var quoteDepth = 0
    var listDepth = 0
    var sourceEnd = 0
    /// The current leaf's characters without code spans, for its direction.
    var directionText = ""
    /// Where the current top-level block's source ends. swift-cmark 0.9.0
    /// gives an inline that spans lines (a code span) an end on its first
    /// line, so inlines are aligned up to the end of their top-level block.
    var alignmentEnd = 0

    init(source: String, features: MarkdownFeatures) {
        bytes = Array(source.utf8)
        self.features = features
        var starts = [0]
        for (index, byte) in bytes.enumerated() {
            let next = index + 1 < bytes.count ? bytes[index + 1] : 0
            if byte == UInt8(ascii: "\n") || (byte == UInt8(ascii: "\r") && next != UInt8(ascii: "\n")) {
                starts.append(index + 1)
            }
        }
        lineStarts = starts
    }

    mutating func build(_ root: Node, skipping skipped: Node?) {
        for block in Self.children(of: root) where block != skipped {
            let firstLeaf = leaves.count
            alignmentEnd = span(of: block).upperBound
            walkBlock(block)
            let text = leafTexts[firstLeaf...].joined(separator: " ")
            let direction = Self.typeName(block) == "code_block" ? .ltr : TextDirection.firstStrong(in: text) ?? .auto
            leafDirections += leaves[firstLeaf...].map { $0.ownDirection ?? direction }
            topLevelBlocks.append(MarkdownDocument.Block(
                kind: Self.kind(of: block),
                line: Int(block.pointee.start_line) - 1,
                sourceRange: span(of: block),
                direction: direction
            ))
        }
        renderedBlocks = zip(leaves, leafDirections).map { leaf, direction in
            RenderedText.Block(
                kind: leaf.kind,
                range: leaf.range,
                sourceRange: leaf.sourceRange,
                quoteDepth: leaf.quoteDepth,
                listDepth: leaf.listDepth,
                listMarker: leaf.listMarker,
                taskIndex: leaf.taskIndex,
                direction: direction
            )
        }
        let utf16 = Array(string.utf16)
        tasks = pendingTasks.enumerated().map { index, pending in
            let leaf = taskLeaves[index]
            return MarkdownDocument.Task(
                index: index,
                line: pending.line,
                byteOffset: pending.byteOffset,
                checked: pending.checked,
                text: visibleText(leaves[leaf].range, in: utf16).trimmingCharacters(in: .whitespacesAndNewlines),
                direction: leafDirections[leaf]
            )
        }
    }

    /// Text, code, and HTML characters of a node's inlines; a break is a space.
    static func plainText(of node: Node) -> String {
        children(of: node).map { child in
            switch Self.typeName(child) {
            case "text", "code", "html_inline": Self.literal(child)
            case "softbreak", "linebreak": " "
            default: plainText(of: child)
            }
        }.joined()
    }

    // MARK: blocks

    mutating func walkBlock(_ node: Node) {
        if let kind = Self.leafKind(of: node) {
            leaf(kind, node)
            return
        }
        switch Self.typeName(node) {
        case "block_quote":
            quoteDepth += 1
            Self.children(of: node).forEach { walkBlock($0) }
            quoteDepth -= 1
        case "list":
            listDepth += 1
            let start = Int(cmark_node_get_list_start(node))
            let ordered = cmark_node_get_list_type(node) == CMARK_ORDERED_LIST
            for (index, item) in Self.children(of: node).enumerated() {
                openMarker = ordered ? .ordered(start + index) : .bullet
                walkBlock(item)
            }
            listDepth -= 1
        case "tasklist":
            openTask = pendingTasks.count
            pendingTasks.append(PendingTask(
                line: Int(node.pointee.start_line) - 1,
                byteOffset: markerOffset(of: node),
                checked: cmark_gfm_extensions_get_tasklist_item_checked(node)
            ))
            Self.children(of: node).forEach { walkBlock($0) }
            // An item with no content still needs a block for its checkbox.
            if openTask != nil {
                leaf(.paragraph, node)
            }
        default:
            Self.children(of: node).forEach { walkBlock($0) }
        }
    }

    /// Appends one line-level block. Blocks are separated by one `\n`.
    mutating func leaf(_ kind: RenderedText.BlockKind, _ node: Node) {
        if !leaves.isEmpty {
            append("\n")
        }
        let start = length
        directionText = ""
        sourceEnd = span(of: node).lowerBound
        switch kind {
        case .paragraph, .heading:
            walkInlines(node)
        case .codeBlock:
            appendLines(
                Self.literal(node),
                firstLine: Int(node.pointee.start_line) + (node.pointee.as.code.fenced != 0 ? 1 : 0)
            )
        case .htmlBlock:
            appendLines(Self.literal(node), firstLine: Int(node.pointee.start_line))
        case .tableRow:
            for (index, cell) in Self.children(of: node).enumerated() {
                if index > 0 {
                    appendHidden("\t", at: span(of: cell).lowerBound)
                }
                walkInlines(cell)
            }
        case .thematicBreak:
            break
        }
        if openTask != nil {
            taskLeaves.append(leaves.count)
        }
        leaves.append(Leaf(
            kind: kind,
            range: start ..< length,
            sourceRange: span(of: node),
            quoteDepth: quoteDepth,
            listDepth: listDepth,
            listMarker: openMarker,
            taskIndex: openTask,
            ownDirection: kind == .codeBlock ? .ltr : TextDirection.firstStrong(in: directionText)
        ))
        leafTexts.append(directionText)
        openTask = nil
        openMarker = nil
    }
}
