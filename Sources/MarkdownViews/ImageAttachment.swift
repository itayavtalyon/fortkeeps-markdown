import Foundation
import ImageIO
import MarkdownCore
#if os(macOS)
    import AppKit

    typealias PlatformView = NSView
#else
    import UIKit

    typealias PlatformView = UIView
#endif

/// One image in rendered mode: the U+FFFC of `RenderedText.Image` carries
/// it, and its view draws the image, a card, or the `Image: {alt}` link.
final class ImageAttachment: NSTextAttachment {
    let index: Int
    let destination: String
    let content: ImageCardContent
    let animating: Bool
    /// A drawn image is at most 80% of the viewport height.
    let maxHeight: CGFloat
    let linkFont: PlatformFont
    weak var owner: MarkdownView?

    @MainActor
    init(
        index: Int,
        destination: String,
        content: ImageCardContent,
        animating: Bool,
        maxHeight: CGFloat,
        owner: MarkdownView?
    ) {
        self.index = index
        self.destination = destination
        self.content = content
        self.animating = animating
        self.maxHeight = maxHeight
        linkFont = MarkdownTheme(surface: .rendered).bodyFont()
        self.owner = owner
        super.init(data: nil, ofType: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// An image fits the column and 80% of the viewport, and is not upscaled.
    func size(lineWidth: CGFloat) -> CGSize {
        let width = max(lineWidth - 10, 1)
        switch content.kind {
        case let .image(data):
            let natural = Self.headerSize(data)
            guard natural.width > 0, natural.height > 0 else { return CGSize(width: 1, height: 1) }
            let scale = min(1, width / natural.width, maxHeight > 0 ? maxHeight / natural.height : 1)
            return CGSize(width: natural.width * scale, height: natural.height * scale)
        case .card:
            return content.cardSize(columnWidth: width)
        case .link:
            let size = NSAttributedString(string: content.title, attributes: [.font: linkFont]).size()
            return CGSize(width: ceil(size.width) + 4, height: ceil(size.height))
        }
    }

    /// The size in points from the image header, read without decoding the image.
    static func headerSize(_ data: Data) -> CGSize {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return .zero }
        // A header at 144 dpi describes a 2x image: half the pixels in points.
        let dpi = properties[kCGImagePropertyDPIWidth] as? CGFloat ?? 72
        let scale = dpi > 0 ? 72 / dpi : 1
        // EXIF orientations 5 to 8 turn the image a quarter, as the decoder draws it.
        let turned = (properties[kCGImagePropertyOrientation] as? Int ?? 1) >= 5
        return CGSize(width: (turned ? height : width) * scale, height: (turned ? width : height) * scale)
    }

    override func viewProvider(
        for parentView: PlatformView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        let provider = ImageAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }

    override func attachmentBounds(
        for _: [NSAttributedString.Key: Any],
        location _: any NSTextLocation,
        textContainer _: NSTextContainer?,
        proposedLineFragment: CGRect,
        position _: CGPoint
    ) -> CGRect {
        let size = size(lineWidth: proposedLineFragment.width)
        // A link sits on the baseline like text; a card or image sits on it too.
        return CGRect(x: 0, y: content.kind == .link ? linkFont.descender : 0, width: size.width, height: size.height)
    }
}

final class ImageAttachmentViewProvider: NSTextAttachmentViewProvider {
    /// TextKit calls this on the main thread.
    override func loadView() {
        nonisolated(unsafe) let provider = self
        MainActor.assumeIsolated {
            guard let attachment = provider.textAttachment as? ImageAttachment else { return }
            provider.view = ImageCardView(attachment: attachment)
        }
    }
}
