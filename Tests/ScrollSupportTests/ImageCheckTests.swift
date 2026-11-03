import CoreGraphics
import Foundation
import ImageIO
import MarkdownViews
@testable import ScrollSupport
import Testing

/// Design › Images: png, jpeg, gif, and webp only, at most 8192 pixels a side.
struct ImageCheckTests {
    /// An image of the given type and pixel size, encoded by ImageIO.
    static func givenImage(_ type: String, width: Int = 4, height: Int = 4) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// A 1x1 lossy WebP: ImageIO reads WebP but may not write it.
    static let webp = Data(base64Encoded: "UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=")

    @Test(arguments: ["public.png", "public.jpeg", "com.compuserve.gif"])
    func `png, jpeg, and gif pass`(type: String) throws {
        let data = try Self.givenImage(type)
        #expect(ImageCheck.check(data) == nil)
    }

    @Test
    func `webp passes`() throws {
        #expect(try ImageCheck.check(#require(Self.webp)) == nil)
    }

    @Test
    func `an SVG is unsupported`() {
        let svg = Data(
            #"<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4"/></svg>"#
                .utf8
        )
        #expect(ImageCheck.check(svg) == .unsupported)
    }

    @Test(arguments: ["public.tiff", "com.microsoft.bmp", "public.heic"])
    func `another format ImageIO reads is unsupported`(type: String) throws {
        let data = try Self.givenImage(type)
        #expect(ImageCheck.check(data) == .unsupported)
    }

    @Test(arguments: [Data(), Data("hello".utf8), Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])])
    func `bytes that do not decode are unsupported`(data: Data) {
        #expect(ImageCheck.check(data) == .unsupported)
    }

    @Test
    func `a png cut short after its header is unsupported`() throws {
        let png = try Self.givenImage("public.png", width: 64, height: 64)
        #expect(ImageCheck.check(png.prefix(40)) == .unsupported)
    }

    @Test(arguments: [(8193, 1), (1, 8193)])
    func `an image wider or taller than 8192 pixels is too large`(width: Int, height: Int) throws {
        let png = try Self.givenImage("public.png", width: width, height: height)
        #expect(ImageCheck.check(png) == .tooLarge)
    }

    @Test
    func `an image of exactly 8192 pixels a side passes`() throws {
        let png = try Self.givenImage("public.png", width: 8192, height: 1)
        #expect(ImageCheck.check(png) == nil)
    }
}
