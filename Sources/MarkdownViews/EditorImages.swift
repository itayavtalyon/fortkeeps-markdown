import CoreText
import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension NSAttributedString.Key {
    /// The `EditorImageMark`s drawn under an editor line, as an array.
    static let markdownEditorImages = NSAttributedString.Key("FortkeepsMarkdownEditorImages")
}

/// One image under an editor line: its card, or its thumbnail once the
/// result is `.image` (design log 001 › Editor).
final class EditorImageMark: NSObject {
    /// A thumbnail is at most 120 pt tall.
    static let thumbnailHeight: CGFloat = 120
    /// The space between the line and a card, and between two cards.
    static let gap: CGFloat = 6

    let destination: String
    let content: ImageCardContent
    let thumbnail: PlatformImage?
    let size: CGSize

    init(destination: String, content: ImageCardContent, columnWidth: CGFloat) {
        self.destination = destination
        self.content = content
        let width = max(columnWidth, 1)
        let decoded: PlatformImage? = if case let .image(data) = content.kind {
            PlatformImage(data: data)
        } else {
            nil
        }
        if let image = decoded, image.size.width > 0, image.size.height > 0 {
            thumbnail = image
            let scale = min(1, width / image.size.width, Self.thumbnailHeight / image.size.height)
            size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            thumbnail = nil
            size = content.cardSize(columnWidth: width)
        }
    }

    /// The height the marks of one line reserve under it.
    static func height(_ marks: [EditorImageMark]) -> CGFloat {
        marks.reduce(0) { $0 + gap + $1.size.height } + gap
    }

    // MARK: drawing

    /// Draws the thumbnail, or the card with its glyph, title, lines, and button.
    func draw(in rect: CGRect, context: CGContext) {
        if let image = thumbnail?.cgImageForDrawing {
            Self.drawFlipped(image, in: rect, context: context)
            return
        }
        let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(path)
        context.setFillColor(MarkdownTheme.color(.pill).cgColor)
        context.fillPath()
        if let glyph = PlatformImage.symbol("photo")?.cgImageForDrawing {
            Self.drawFlipped(
                glyph,
                in: CGRect(x: rect.minX + 12, y: rect.midY - 8, width: 18, height: 16),
                context: context
            )
        }
        var y = rect.minY + 10
        Self.drawText(content.title, size: 13, role: .text, at: CGPoint(x: rect.minX + 40, y: y), context: context)
        for line in content.lines {
            y += 18
            Self.drawText(line, size: 11, role: .text3, at: CGPoint(x: rect.minX + 40, y: y), context: context)
        }
        if let button = content.button {
            let width = Self.textWidth(button, size: 13)
            Self.drawText(
                button,
                size: 13,
                role: .accent,
                at: CGPoint(x: rect.maxX - 12 - width, y: rect.midY - 8),
                context: context
            )
        }
    }

    private static func drawFlipped(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private static func line(_ text: String, size: CGFloat, role: MarkdownTheme.Role) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .font: PlatformFont.systemFont(ofSize: size), .foregroundColor: MarkdownTheme.color(role)
        ]))
    }

    private static func textWidth(_ text: String, size: CGFloat) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text, size: size, role: .text), nil, nil, nil))
    }

    /// Draws one line of text with its top at `point`, in the flipped context of a fragment.
    private static func drawText(
        _ text: String,
        size: CGFloat,
        role: MarkdownTheme.Role,
        at point: CGPoint,
        context: CGContext
    ) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: point.x, y: point.y + size)
        context.scaleBy(x: 1, y: -1)
        context.textPosition = .zero
        CTLineDraw(line(text, size: size, role: role), context)
        context.restoreGState()
    }
}

extension PlatformImage {
    static func symbol(_ name: String) -> PlatformImage? {
        #if os(macOS)
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        #else
            UIImage(systemName: name)
        #endif
    }

    var cgImageForDrawing: CGImage? {
        #if os(macOS)
            cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
            cgImage
        #endif
    }
}

extension MarkdownDisplay {
    /// The images of a stretch of the source that starts at UTF-16 `offset`,
    /// with their UTF-16 ranges in the whole text.
    func editorImages(in text: String, at offset: Int) -> [(range: Range<Int>, image: RenderedText.Image)] {
        let document = MarkdownDocument(
            text: text,
            features: controller.features,
            presentation: controller.presentation
        )
        let utf8 = text.utf8
        func utf16(_ byte: Int) -> Int {
            let index = utf8.index(utf8.startIndex, offsetBy: min(byte, utf8.count))
            return offset + text.utf16.distance(from: text.utf16.startIndex, to: index)
        }
        return document.rendered.images.map { image in
            (utf16(image.sourceRange.lowerBound) ..< utf16(image.sourceRange.upperBound), image)
        }
    }

    /// Dims each image source, keeps it on one line while the caret is
    /// outside it, and reserves the space for its card or thumbnail under
    /// its line. `lines` are the restyled line ranges.
    func decorateEditorImages(_ images: [(range: Range<Int>, image: RenderedText.Image)], lines: [Range<Int>]) {
        let text = storage.string as NSString
        for line in lines {
            let inLine = images.filter { line.contains($0.range.lowerBound) }
            guard !inLine.isEmpty else { continue }
            let marks = inLine.map { item in
                EditorImageMark(
                    destination: item.image.destination,
                    content: ImageCardContent(
                        result: controller.imageResults[item.image.destination],
                        alt: item.image.alt,
                        fallback: .text,
                        isUntitled: controller.documentURL == nil
                    ),
                    columnWidth: columnWidth
                )
            }
            let lineRange = NSRange(location: line.lowerBound, length: line.count)
            for item in inLine {
                storage.addAttribute(
                    .foregroundColor,
                    value: MarkdownTheme.color(.text3),
                    range: NSRange(location: item.range.lowerBound, length: item.range.count)
                )
            }
            let base = storage.attribute(.paragraphStyle, at: line.lowerBound, effectiveRange: nil) as? NSParagraphStyle
            let style = (base?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            style.paragraphSpacing = EditorImageMark.height(marks)
            let onlyImage = inLine.count == 1 && text.substring(with: lineRange)
                .trimmingCharacters(in: .whitespaces).utf16.count == inLine[0].range.count
            let caretInside = inLine
                .contains { $0.range.lowerBound ... $0.range.upperBound ~= controller.selection.lowerBound }
            // Set both ways, so decorating a line again is the same as once.
            style.lineBreakMode = onlyImage && !caretInside ? .byTruncatingTail : .byWordWrapping
            storage.addAttributes([.paragraphStyle: style, .markdownEditorImages: marks as NSArray], range: lineRange)
        }
    }
}
