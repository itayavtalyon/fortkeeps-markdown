import Foundation
import ImageIO
import MarkdownViews

/// The decode rules of design log 001 › Images: the app decodes png, jpeg,
/// gif, and webp, at most 8192 pixels a side, read from the header.
enum ImageCheck {
    static let maxPixels = 8192
    static let allowedTypes: Set = ["public.png", "public.jpeg", "com.compuserve.gif", "org.webmproject.webp"]

    /// The failure of image bytes, or nil when the app may draw them.
    static func check(_ data: Data) -> ImageFailure? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?, allowedTypes.contains(type)
        else { return .unsupported }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return .unsupported }
        if max(width, height) > maxPixels {
            return .tooLarge
        }
        // The header reads; the frame must be whole too.
        return CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete ? nil : .unsupported
    }
}
