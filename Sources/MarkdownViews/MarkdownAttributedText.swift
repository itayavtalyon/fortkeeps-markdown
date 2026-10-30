import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension NSAttributedString.Key {
    /// A `MarkdownMarker`: a bullet, a number, or a checkbox the layout fragment draws.
    static let markdownMarker = NSAttributedString.Key("FortkeepsMarkdownMarker")
    /// The quote depth of a rendered block; the fragment draws one bar per level.
    static let markdownQuoteDepth = NSAttributedString.Key("FortkeepsMarkdownQuoteDepth")
    /// A rendered code block; the fragment draws its `pill` background.
    static let markdownCodeBlock = NSAttributedString.Key("FortkeepsMarkdownCodeBlock")
    /// A thematic break; the fragment draws a `line2` rule.
    static let markdownRule = NSAttributedString.Key("FortkeepsMarkdownRule")
    /// A `BoxMark`: the rendered code block or table run a paragraph belongs to.
    static let markdownBox = NSAttributedString.Key("FortkeepsMarkdownBox")
}

/// One box of rendered mode (design log 001 › Boxes).
final class BoxMark: NSObject {
    enum Kind {
        case code
        case table
    }

    let id: Int
    let kind: Kind

    init(id: Int, kind: Kind) {
        self.id = id
        self.kind = kind
    }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? BoxMark)?.id == id
    }

    override var hash: Int {
        id
    }
}

/// What the layout fragment draws for a list item or a task.
final class MarkdownMarker: NSObject {
    enum Kind: Equatable {
        case bullet
        case ordered(Int)
        case checkbox(checked: Bool)
    }

    let kind: Kind
    /// True in the editor: the marker covers its source characters. False in
    /// rendered mode: it draws in the paragraph's indent.
    let covers: Bool

    init(_ kind: Kind, covers: Bool) {
        self.kind = kind
        self.covers = covers
    }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? MarkdownMarker).map { $0.kind == kind && $0.covers == covers } ?? false
    }

    override var hash: Int {
        covers ? 1 : 0
    }
}

/// Builds the attributed strings the views draw (design log 001 ›
/// Rendering, Editor). Offsets are UTF-16.
@MainActor
struct MarkdownAttributedText {
    let theme: MarkdownTheme
    let features: MarkdownFeatures

    /// The indent of one list or quote level.
    nonisolated static let indentStep: CGFloat = 22

    // MARK: editor

    func editor(_ text: String) -> NSMutableAttributedString {
        let string = NSMutableAttributedString(string: text, attributes: baseAttributes())
        styleEditorLines(MarkdownStyler(features: features).styleText(text, caret: nil), in: string)
        return string
    }

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        [.font: theme.bodyFont(), .foregroundColor: MarkdownTheme.color(.text), .paragraphStyle: theme.paragraphStyle()]
    }

    /// Restyles styled lines whose ranges are in `string`.
    func styleEditorLines(_ lines: [MarkdownStyler.StyledLine], in string: NSMutableAttributedString) {
        style(lines.map { ($0.range, $0.spans) }, in: string)
    }

    /// Restyles lines given by their range in `string` and their spans in the line.
    func style(
        _ lines: [(range: Range<Int>, spans: [MarkdownStyler.StyleSpan])],
        in string: NSMutableAttributedString
    ) {
        guard let first = lines.first, let last = lines.last else { return }
        let whole = NSRange(location: first.range.lowerBound, length: last.range.upperBound - first.range.lowerBound)
        string.setAttributes(baseAttributes(), range: whole)
        for line in lines {
            let start = line.range.lowerBound
            apply(line.spans, offset: start, in: string)
            if let marker = line.spans.first(where: { $0.token == .checkbox(checked: true) }) {
                let wordsStart = start + marker.range.upperBound
                string.addAttribute(
                    .foregroundColor,
                    value: MarkdownTheme.color(.text3),
                    range: NSRange(location: wordsStart, length: line.range.upperBound - wordsStart)
                )
            }
        }
    }

    /// Applies inline and line spans: every other token first, outer before
    /// inner, then syntax, which is `text3` at regular weight.
    func apply(_ spans: [MarkdownStyler.StyleSpan], offset: Int = 0, in string: NSMutableAttributedString) {
        for span in spans.filter({ $0.token != .syntax }) + spans.filter({ $0.token == .syntax }) {
            apply(span.token, NSRange(location: offset + span.range.lowerBound, length: span.range.count), in: string)
        }
    }

    private func apply(_ token: MarkdownStyler.StyleToken, _ range: NSRange, in string: NSMutableAttributedString) {
        switch token {
        case .syntax:
            string.addAttribute(.foregroundColor, value: MarkdownTheme.color(.text3), range: range)
            transformFonts(in: range, of: string) { Self.isMono($0) ? $0 : .systemFont(ofSize: $0.pointSize) }
        case let .heading(level):
            string.addAttribute(.font, value: theme.headingFont(level: level), range: range)
            #if os(iOS)
                string.addAttribute(.accessibilityTextHeadingLevel, value: level, range: range)
            #endif
        case .strong:
            let strong = theme.strongFont()
            transformFonts(in: range, of: string) { font in
                Self.isMono(font) || Self.isPlex(font) ? font : Self.isItalic(font) ? MarkdownTheme
                    .italic(strong) : strong
            }
        case .emphasis:
            transformFonts(in: range, of: string) { MarkdownTheme.italic($0) }
        case .code:
            string.addAttributes([.font: theme.codeFont(), .backgroundColor: MarkdownTheme.color(.pill)], range: range)
        case .link:
            string.addAttribute(.foregroundColor, value: MarkdownTheme.color(.accent), range: range)
            // iOS has no hover, so a link is always underlined there.
            #if os(iOS)
                string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            #endif
        case .quote:
            string.addAttribute(.foregroundColor, value: MarkdownTheme.color(.text2), range: range)
        case .strikethrough:
            string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case let .checkbox(checked):
            string.addAttributes([
                .markdownMarker: MarkdownMarker(.checkbox(checked: checked), covers: true),
                .foregroundColor: PlatformColor.clear
            ], range: range)
        }
    }

    private func transformFonts(
        in range: NSRange,
        of string: NSMutableAttributedString,
        _ transform: (PlatformFont) -> PlatformFont
    ) {
        string.enumerateAttribute(.font, in: range) { value, run, _ in
            let font = value as? PlatformFont ?? theme.bodyFont()
            string.addAttribute(.font, value: transform(font), range: run)
        }
    }

    static func isMono(_ font: PlatformFont) -> Bool {
        font.fontName.hasPrefix("IBMPlexMono")
    }

    static func isPlex(_ font: PlatformFont) -> Bool {
        font.fontName.hasPrefix("IBMPlexSans")
    }

    static func isItalic(_ font: PlatformFont) -> Bool {
        #if os(macOS)
            font.fontDescriptor.symbolicTraits.contains(.italic)
        #else
            font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        #endif
    }

    // MARK: rendered

    /// The rendered text with block styles, inline styles, markers, and one
    /// attachment per image (`attachment(index)`).
    func rendered(
        _ rendered: RenderedText,
        tasks: [MarkdownDocument.Task],
        attachment: (Int) -> NSTextAttachment
    ) -> NSMutableAttributedString {
        let string = NSMutableAttributedString(string: rendered.string, attributes: baseAttributes())
        let units = rendered.utf16Count
        for block in rendered.blocks {
            // A block's paragraph includes the newline after it.
            let end = min(units, block.range.upperBound + 1)
            let paragraph = NSRange(location: block.range.lowerBound, length: end - block.range.lowerBound)
            let range = NSRange(location: block.range.lowerBound, length: block.range.count)
            let depth = CGFloat(block.quoteDepth + block.listDepth)
            string.addAttribute(
                .paragraphStyle,
                value: theme.paragraphStyle(
                    direction: block.direction,
                    indent: depth * Self.indentStep
                ),
                range: paragraph
            )
            styleBlock(block, range: range, paragraph: paragraph, in: string)
            if let marker = block.listMarker {
                let kind: MarkdownMarker.Kind = switch (block.taskIndex, marker) {
                case let (task?, _): .checkbox(checked: tasks[task].checked)
                case (nil, .bullet): .bullet
                case let (nil, .ordered(number)): .ordered(number)
                }
                string.addAttribute(.markdownMarker, value: MarkdownMarker(kind, covers: false), range: paragraph)
            }
            if let task = block.taskIndex, tasks[task].checked {
                string.addAttribute(.foregroundColor, value: MarkdownTheme.color(.text3), range: range)
            }
        }
        markBoxes(rendered.blocks, in: string)
        apply(rendered.spans, in: string)
        for (index, image) in rendered.images.enumerated() {
            string.addAttribute(
                .attachment,
                value: attachment(index),
                range: NSRange(location: image.offset, length: 1)
            )
        }
        return string
    }

    static func isTableRow(_ block: RenderedText.Block) -> Bool {
        if case .tableRow = block.kind {
            true
        } else {
            false
        }
    }

    private func styleBlock(
        _ block: RenderedText.Block,
        range: NSRange,
        paragraph: NSRange,
        in string: NSMutableAttributedString
    ) {
        #if os(iOS)
            // VoiceOver reads these as the block's kind.
            let kinds = [
                block.listDepth > 0 ? "list" : nil,
                Self.isTableRow(block) ? "table" : nil,
                block.quoteDepth > 0 ? "quote" : nil
            ].compactMap(\.self)
            if !kinds.isEmpty {
                string.addAttribute(.accessibilityTextCustom, value: kinds, range: range)
            }
        #endif
        if block.quoteDepth > 0 {
            string.addAttributes([
                .foregroundColor: MarkdownTheme.color(.text2),
                .markdownQuoteDepth: block.quoteDepth
            ], range: paragraph)
        }
        switch block.kind {
        case let .heading(level):
            string.addAttribute(.font, value: theme.headingFont(level: level), range: range)
            #if os(iOS)
                string.addAttribute(.accessibilityTextHeadingLevel, value: level, range: range)
            #endif
        case .codeBlock:
            string.addAttributes([.font: theme.codeFont(), .markdownCodeBlock: true], range: paragraph)
        case .htmlBlock:
            string.addAttributes([.font: theme.codeFont(), .foregroundColor: MarkdownTheme.color(.text3)], range: range)
        case .thematicBreak:
            string.addAttribute(.markdownRule, value: true, range: paragraph)
        case .tableRow(isHeader: true):
            string.addAttribute(.font, value: theme.strongFont(), range: range)
        case .paragraph, .tableRow:
            break
        }
    }
}
