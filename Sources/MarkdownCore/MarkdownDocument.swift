import cmark_gfm
import cmark_gfm_extensions
import Foundation

/// One model of the whole text (design log 001 › Document model). Every
/// source offset is a UTF-8 byte offset, excluding a leading BOM.
public struct MarkdownDocument: Sendable {
    public enum BlockKind: Equatable, Sendable {
        case paragraph
        case heading(level: Int)
        case bulletList
        case orderedList
        case quote
        case codeBlock(fenced: Bool)
        case htmlBlock
        case table
        case thematicBreak
    }

    /// A top-level block.
    public struct Block: Equatable, Sendable {
        public let kind: BlockKind
        /// The 0-based line where the block starts.
        public let line: Int
        public let sourceRange: Range<Int>
        public let direction: TextDirection
    }

    public struct Task: Equatable, Sendable {
        public let index: Int
        /// The 0-based line of the task item.
        public let line: Int
        /// The byte between `[` and `]`.
        public let byteOffset: Int
        public let checked: Bool
        /// The item's first block as drawn, trimmed.
        public let text: String
        public let direction: TextDirection
    }

    public let blocks: [Block]
    public let tasks: [Task]
    /// The line-1 ATX H1 text (log 010 MD-09 to MD-12), or nil.
    public let title: String?
    public let rendered: RenderedText

    public init(text: String, features: MarkdownFeatures, presentation: MarkdownPresentation) {
        let source = Self.droppingBOM(text)
        let parsed = ParsedMarkdown(source, features: features)
        var builder = DocumentBuilder(source: source, features: features)
        let titleNode = Self.titleNode(in: parsed.root)
        title = titleNode.map { DocumentBuilder.plainText(of: $0).trimmingCharacters(in: .whitespaces) }
        builder.build(parsed.root, skipping: presentation.titleLine == .hidden ? titleNode : nil)
        blocks = builder.topLevelBlocks
        rendered = builder.rendered
        tasks = builder.tasks(in: rendered)
    }

    /// The text with the task's marker byte flipped: a space becomes `x`, and
    /// `x` or `X` becomes a space. `byteOffset` excludes a leading BOM.
    public static func toggleTask(at byteOffset: Int, in text: String) -> String {
        let utf8 = text.utf8
        let index = utf8.index(utf8.startIndex, offsetBy: byteOffset + (text.hasPrefix(bom) ? bom.utf8.count : 0))
        let marker = text[index]
        precondition([" ", "x", "X"].contains(marker))
        var toggled = text
        toggled.replaceSubrange(index ... index, with: marker == " " ? "x" : " ")
        return toggled
    }

    /// The anchor for the first visible source offset and a source selection.
    public func anchor(firstVisibleSourceOffset offset: Int, selection: Range<Int>) -> MarkdownAnchor {
        let block = blocks.last { $0.sourceRange.lowerBound <= offset }?.sourceRange.lowerBound ?? 0
        return MarkdownAnchor(block: block, offsetInBlock: offset - block, selection: selection)
    }

    /// A source selection with each end on hidden syntax moved to the nearest
    /// content character: the start to the next one, the end to the previous one.
    public func snappedSelection(_ selection: Range<Int>) -> Range<Int> {
        let start = rendered.sourceOffset(atRendered: rendered.renderedOffset(atSource: selection.lowerBound))
        let end = rendered.sourceOffset(
            atRendered: rendered.renderedOffset(atSource: selection.upperBound),
            affinity: .backward
        )
        return start ..< max(start, end)
    }

    /// The heading block whose GFM slug is the fragment, or nil.
    public func headingBlock(forFragment fragment: String) -> RenderedText.Block? {
        let headings = rendered.blocks.filter {
            if case .heading = $0.kind {
                true
            } else {
                false
            }
        }
        let utf16 = Array(rendered.string.utf16)
        let slugs = GFMSlug.slugs(headings.map { String(decoding: utf16[$0.range], as: UTF16.self) })
        return slugs.firstIndex(of: fragment).map { headings[$0] }
    }

    static let bom = "\u{FEFF}"

    private static func droppingBOM(_ text: String) -> String {
        text.hasPrefix(bom) ? String(text.unicodeScalars.dropFirst()) : text
    }

    /// The first block when it is an ATX H1 on line 1 with text.
    private static func titleNode(in root: ParsedMarkdown.Node) -> ParsedMarkdown.Node? {
        guard let first = cmark_node_first_child(root), cmark_node_get_type(first) == CMARK_NODE_HEADING,
              cmark_node_get_heading_level(first) == 1, !first.pointee.as.heading.setext,
              cmark_node_get_start_line(first) == 1, cmark_node_first_child(first) != nil
        else { return nil }
        return first
    }
}
