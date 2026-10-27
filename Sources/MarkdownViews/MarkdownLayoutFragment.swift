import Foundation
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Draws what the characters do not: list markers and checkboxes, quote
/// bars, code block backgrounds, and thematic breaks (design log 001 ›
/// Rendering, Tasks, Direction).
final class MarkdownLayoutFragment: NSTextLayoutFragment {
    /// The checkbox is 15 pt.
    static let checkboxSize: CGFloat = 15

    struct MarkerBox {
        let rect: CGRect
        let marker: MarkdownMarker
        /// The marker's first character, in the paragraph.
        let offset: Int
    }

    private var paragraph: NSAttributedString? {
        (textElement as? NSTextParagraph)?.attributedString
    }

    private var isRightToLeft: Bool {
        guard let paragraph, paragraph.length > 0,
              let style = paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        else { return false }
        return style.baseWritingDirection == .rightToLeft
    }

    /// The x of a leading-edge offset, mirrored in an RTL block.
    private func edge(_ offset: CGFloat, width: CGFloat = 0) -> CGFloat {
        isRightToLeft ? layoutFragmentFrame.width - offset - width : offset
    }

    /// The marker rectangles in fragment coordinates.
    var markerBoxes: [MarkerBox] {
        guard let paragraph, let firstLine = textLineFragments.first else { return [] }
        var boxes: [MarkerBox] = []
        paragraph.enumerateAttribute(.markdownMarker, in: NSRange(
            location: 0,
            length: paragraph.length
        )) { value, range, _ in
            guard let marker = value as? MarkdownMarker else { return }
            let size = Self.checkboxSize
            if marker.covers {
                let line = textLineFragments.first { $0.characterRange.contains(range.location) } ?? firstLine
                let start = line.locationForCharacter(at: range.location).x
                let end = line.locationForCharacter(at: NSMaxRange(range)).x
                let bounds = line.typographicBounds
                boxes.append(MarkerBox(
                    rect: CGRect(
                        x: (start + end - size) / 2,
                        y: bounds.maxY - bounds.height / 2 - size / 2 - 2,
                        width: size,
                        height: size
                    ),
                    marker: marker,
                    offset: range.location
                ))
            } else if range.location == 0 {
                let style = paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
                let indent = style?.headIndent ?? MarkdownAttributedText.indentStep
                let bounds = firstLine.typographicBounds
                let x = edge(indent - MarkdownAttributedText.indentStep + 2, width: size)
                boxes.append(MarkerBox(
                    rect: CGRect(x: x, y: bounds.maxY - bounds.height / 2 - size / 2 - 2, width: size, height: size),
                    marker: marker,
                    offset: 0
                ))
            }
        }
        return boxes
    }

    override var renderingSurfaceBounds: CGRect {
        super.renderingSurfaceBounds.union(CGRect(
            x: -layoutFragmentFrame.minX,
            y: 0,
            width: layoutFragmentFrame.width + layoutFragmentFrame.minX,
            height: layoutFragmentFrame.height
        ))
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        drawBackground(at: point, in: context)
        super.draw(at: point, in: context)
        for box in markerBoxes {
            draw(box, at: point, in: context)
        }
    }

    private func drawBackground(at point: CGPoint, in context: CGContext) {
        guard let paragraph, paragraph.length > 0 else { return }
        let frame = CGRect(origin: point, size: layoutFragmentFrame.size)
        if paragraph.attribute(.markdownCodeBlock, at: 0, effectiveRange: nil) != nil {
            context.setFillColor(MarkdownTheme.color(.pill).cgColor)
            context.fill(frame)
        }
        if paragraph.attribute(.markdownRule, at: 0, effectiveRange: nil) != nil {
            context.setFillColor(MarkdownTheme.color(.line2).cgColor)
            context.fill(CGRect(x: frame.minX, y: frame.midY, width: frame.width, height: 1))
        }
        // A quote has a 2 pt `line2` bar on the leading edge, one per level.
        let depth = paragraph.attribute(.markdownQuoteDepth, at: 0, effectiveRange: nil) as? Int ?? 0
        context.setFillColor(MarkdownTheme.color(.line2).cgColor)
        for level in 0 ..< depth {
            let x = edge(CGFloat(level) * MarkdownAttributedText.indentStep + 4, width: 2)
            context.fill(CGRect(x: point.x + x, y: frame.minY, width: 2, height: frame.height))
        }
    }

    private func draw(_ box: MarkerBox, at point: CGPoint, in context: CGContext) {
        let rect = box.rect.offsetBy(dx: point.x, dy: point.y)
        switch box.marker.kind {
        case let .checkbox(checked):
            let path = CGPath(
                roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                cornerWidth: 3,
                cornerHeight: 3,
                transform: nil
            )
            context.addPath(path)
            if checked {
                context.setFillColor(MarkdownTheme.color(.accent).cgColor)
                context.fillPath()
                context.setStrokeColor(MarkdownTheme.color(.pane).cgColor)
                context.setLineWidth(1.6)
                context.move(to: CGPoint(x: rect.minX + 3.5, y: rect.midY))
                context.addLine(to: CGPoint(x: rect.minX + 6.5, y: rect.maxY - 3.5))
                context.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3.5))
                context.strokePath()
            } else {
                context.setStrokeColor(MarkdownTheme.color(.text3).cgColor)
                context.setLineWidth(1)
                context.strokePath()
            }
        case .bullet:
            context.setFillColor(MarkdownTheme.color(.text3).cgColor)
            context.fillEllipse(in: CGRect(x: rect.midX - 2.5, y: rect.midY - 2.5, width: 5, height: 5))
        case let .ordered(number):
            let font = (paragraph?.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont) ??
                .systemFont(ofSize: 13)
            let label = NSAttributedString(string: "\(number).", attributes: [
                .font: font, .foregroundColor: MarkdownTheme.color(.text3)
            ])
            let line = CTLineCreateWithAttributedString(label)
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: rect.midY + font.pointSize / 3)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = CGPoint(x: isRightToLeft ? rect.minX : rect.maxX - width, y: 0)
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }
}

/// Hands TextKit 2 a `MarkdownLayoutFragment` for every paragraph.
final class MarkdownLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
    func textLayoutManager(
        _: NSTextLayoutManager,
        textLayoutFragmentFor _: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        MarkdownLayoutFragment(textElement: textElement, range: textElement.elementRange)
    }
}

extension NSTextLayoutManager {
    var contentStorage: NSTextContentStorage? {
        textContentManager as? NSTextContentStorage
    }

    /// The UTF-16 offset of a location in the document.
    func offset(of location: NSTextLocation) -> Int {
        offset(from: documentRange.location, to: location)
    }

    func location(at offset: Int) -> NSTextLocation? {
        location(documentRange.location, offsetBy: offset)
    }

    /// The marker under a point in container coordinates, with its
    /// character offset in the document.
    func marker(at point: CGPoint) -> (marker: MarkdownMarker, offset: Int)? {
        guard let fragment = textLayoutFragment(for: point) as? MarkdownLayoutFragment else { return nil }
        let local = CGPoint(
            x: point.x - fragment.layoutFragmentFrame.minX,
            y: point.y - fragment.layoutFragmentFrame.minY
        )
        // A 44 pt hit size on iOS; the drawn size on Mac.
        #if os(macOS)
            let slop: CGFloat = 2
        #else
            let slop = (44 - MarkdownLayoutFragment.checkboxSize) / 2
        #endif
        guard let box = fragment.markerBoxes.first(where: { $0.rect.insetBy(dx: -slop, dy: -slop).contains(local) })
        else { return nil }
        return (box.marker, offset(of: fragment.rangeInElement.location) + box.offset)
    }

    /// The frame of an offset's layout fragment, laid out first.
    func fragmentFrame(at offset: Int) -> CGRect? {
        guard let location = location(at: offset) else { return nil }
        ensureLayout(for: NSTextRange(location: documentRange.location, end: location) ?? documentRange)
        return textLayoutFragment(for: location)?.layoutFragmentFrame
    }

    /// The first character of the fragment at a y in container coordinates.
    func firstOffset(atY y: CGFloat) -> Int {
        guard let fragment = textLayoutFragment(for: CGPoint(x: 0, y: max(0, y))) else { return 0 }
        return offset(of: fragment.rangeInElement.location)
    }
}
