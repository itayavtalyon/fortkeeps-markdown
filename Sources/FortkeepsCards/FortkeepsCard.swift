import Foundation
import MarkdownCore

/// The Fortkeeps card fields of a memory body (remember-mac log 010 and its
/// reference generator `design/markdown-conformance/tools/generate.py`), with
/// the Fortkeeps feature value. Field names match the conformance `.expect.json`.
public struct FortkeepsCard: Codable, Equatable, Sendable {
    public enum Variant: String, Codable, Sendable {
        case savedLink
        case doc
        case status
        case fact
    }

    public enum FactSize: String, Codable, Sendable {
        case extraLarge = "XL"
        case large = "LG"
        case medium = "MD"
    }

    public enum LinkForm: String, Codable, Sendable {
        /// The URL is the last non-empty line, after at most three plain lines.
        case capture
        /// The first non-empty line is only a URL or a Markdown link.
        case leading
    }

    public struct Link: Codable, Equatable, Sendable {
        public let form: LinkForm
        public let url: String
        public let title: String
        public let excerpt: String?
    }

    public struct Summary: Codable, Equatable, Sendable {
        public let items: Int
        public let done: Int
        public let sections: Int
    }

    public struct Task: Codable, Equatable, Sendable {
        public let index: Int
        public let line: Int
        public let byteOffset: Int
        public let checked: Bool
        public let text: String
    }

    public struct Block: Codable, Equatable, Sendable {
        public let type: String
        public let line: Int
        public let dir: TextDirection
    }

    public let title: String?
    public let variant: Variant
    public let factSize: FactSize?
    public let visibleLength: Int
    public let link: Link?
    public let summary: Summary?
    public let tasks: [Task]
    public let statusFields: [String]
    public let blocks: [Block]

    public init(text: String) {
        let document = MarkdownDocument(text: text, features: .fortkeeps, presentation: MarkdownPresentation())
        title = document.title
        tasks = document.tasks.map {
            Task(index: $0.index, line: $0.line, byteOffset: $0.byteOffset, checked: $0.checked, text: $0.text)
        }
        let sections = document.rendered.blocks.count { $0.kind == .heading(level: 2) }
        summary = tasks.isEmpty && sections <= 1
            ? nil : Summary(items: tasks.count, done: tasks.count(where: \.checked), sections: sections)
        blocks = document.blocks.map { Block(type: Self.typeName($0), line: $0.line, dir: $0.direction) }
        visibleLength = Self.visibleText(document).count
        link = SavedLink.parse(text)
        let fields = Self.lines(text).filter { $0.prefixMatch(of: /[A-Z][A-Z0-9_]{1,23}:\s+\S/) != nil }
        let hasTable = document.blocks.contains { $0.kind == .table }
        variant = link != nil ? .savedLink : title != nil ? .doc : fields.count >= 2 || hasTable ? .status : .fact
        factSize = variant != .fact ? nil : visibleLength < 70 ? .extraLarge : visibleLength < 150 ? .large : .medium
        statusFields = variant == .status ? fields.map { String($0.prefix { $0 != ":" }) } : []
    }

    /// The drawn text of the whole body, title included, with images as
    /// `Image: {alt}`, every whitespace run as one space, and trimmed.
    static func visibleText(_ document: MarkdownDocument) -> String {
        let rendered = document.rendered
        let text = rendered.copyText(0 ..< rendered.utf16Count, imagesDrawnAsText: Set(rendered.images.indices))
        return text.split(whereSeparator: { $0.unicodeScalars.allSatisfy(\.properties.isWhitespace) })
            .joined(separator: " ")
    }

    /// Python `str.splitlines()`: every Unicode line boundary.
    private static func lines(_ text: String) -> [Substring] {
        text.split(omittingEmptySubsequences: false) { $0.isNewline }
    }

    private static func typeName(_ block: MarkdownDocument.Block) -> String {
        switch block.kind {
        case .paragraph: "paragraph"
        case let .heading(level): "h\(level)"
        case .bulletList: "bullet_list"
        case .orderedList: "ordered_list"
        case .quote: "blockquote"
        case let .codeBlock(fenced): fenced ? "fence" : "code_block"
        case .htmlBlock: "html_block"
        case .table: "table"
        case .thematicBreak: "hr"
        }
    }
}
