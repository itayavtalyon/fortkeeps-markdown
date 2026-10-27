import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Rendered boxes and table columns.
extension MarkdownAttributedText {
    /// A code block is one box; a run of table rows is one box. Box lines
    /// do not wrap (design log 001 › Boxes).
    func markBoxes(_ blocks: [RenderedText.Block], in string: NSMutableAttributedString) {
        var id = 0
        for (index, block) in blocks.enumerated() {
            let kind: BoxMark.Kind
            switch block.kind {
            case .codeBlock: kind = .code
            case .tableRow: kind = .table
            default: continue
            }
            if kind == .code || index == 0 || !Self.isTableRow(blocks[index - 1]) {
                id += 1
            }
            let end = min(string.length, block.range.upperBound + 1)
            let paragraph = NSRange(location: block.range.lowerBound, length: end - block.range.lowerBound)
            string.enumerateAttribute(.paragraphStyle, in: paragraph) { value, run, _ in
                let style = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ??
                    NSMutableParagraphStyle()
                style.lineBreakMode = .byClipping
                string.addAttribute(.paragraphStyle, value: style, range: run)
            }
            string.addAttribute(.markdownBox, value: BoxMark(id: id, kind: kind), range: paragraph)
        }
    }

    /// One tab stop per column: the widest cell plus 6 pt by 10 pt padding.
    func tabulate(_ rows: ArraySlice<RenderedText.Block>, in string: NSMutableAttributedString) {
        var widths: [CGFloat] = []
        for row in rows {
            let text = string.attributedSubstring(from: NSRange(
                location: row.range.lowerBound,
                length: row.range.count
            ))
            var start = 0
            for (column, cell) in text.string.split(separator: "\t", omittingEmptySubsequences: false).enumerated() {
                let length = cell.utf16.count
                let width = text.attributedSubstring(from: NSRange(location: start, length: length)).size().width + 20
                start += length + 1
                if column < widths.count {
                    widths[column] = max(widths[column], width)
                } else {
                    widths.append(width)
                }
            }
        }
        for row in rows {
            let range = NSRange(location: row.range.lowerBound, length: row.range.count)
            let base = (string.attribute(
                .paragraphStyle,
                at: row.range.lowerBound,
                effectiveRange: nil
            ) as? NSParagraphStyle)
            let style = (base?.mutableCopy() as? NSMutableParagraphStyle) ?? theme.paragraphStyle()
            var position = style.headIndent
            style.tabStops = widths.dropLast().map { width in
                position += width
                return NSTextTab(textAlignment: .natural, location: position)
            }
            style.paragraphSpacingBefore = 6
            string.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }
}
