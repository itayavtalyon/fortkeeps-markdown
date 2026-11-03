import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Copy as Rich Text (log 001 › Windows and chrome; screens §3.16): the
/// selection, or the whole text with nothing selected, as RTF and HTML.
@MainActor
struct MarkdownViewRichTextTests {
    static func controller(_ text: String, mode: MarkdownMode = .editor) -> MarkdownTextController {
        MarkdownTextController(
            text: text, features: MarkdownFeatures(), presentation: MarkdownPresentation(),
            mode: mode, maxUTF8Bytes: nil, documentURL: nil
        )
    }

    @Test
    func `nothing selected copies the whole text, rendered and as HTML`() {
        let rich = Self.controller("# Trip\n\n**bold** word\n").richText()

        #expect(rich.rendered.string == "Trip\nbold word")
        #expect(rich.html == "<h1>Trip</h1>\n<p><strong>bold</strong> word</p>\n")
    }

    @Test
    func `a selection copies its own Markdown`() {
        let controller = Self.controller("\u{FEFF}# Trip\n\n**bold** word\n")
        controller.selection = 9 ..< 22

        let rich = controller.richText()

        #expect(rich.rendered.string == "bold word")
        #expect(rich.html == "<p><strong>bold</strong> word</p>\n")
    }

    @Test
    func `a rendered selection copies the Markdown under it`() {
        let controller = Self.controller("# Trip\n\n**bold** word\n", mode: .rendered)
        controller.selection = 5 ..< 14

        #expect(controller.richText().html == "<p><strong>bold</strong> word</p>\n")
    }

    /// A 1 × 1 PNG.
    static let png =
        Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA"
                + "60e6kgAAAABJRU5ErkJggg=="
        )

    /// Export as PDF and Print (screens §3.16): the whole text, rendered,
    /// with each image the host gives now; the host fetches nothing for it.
    @Test
    func `the printed text is the whole text, rendered, with the images the host has`() async throws {
        let view = MarkdownView(text: "# Trip\n\n![map](map.png) ![far](https://e.com/x.png)\n", host: nil)
        view.select(2 ..< 3)
        let png = try #require(Self.png)
        var asked: [String] = []

        let printed = await view.printableText(width: 400) { request in
            asked.append(request.destination)
            return request.destination == "map.png" ? .image(png) : .remoteNotLoaded(host: "e.com")
        }

        #expect(asked == ["map.png", "https://e.com/x.png"])
        #expect(printed.string == "Trip\n\u{FFFC} \u{FFFC}")
        var attachments: [NSTextAttachment] = []
        printed.enumerateAttribute(.attachment, in: NSRange(location: 0, length: printed.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                attachments.append(attachment)
            }
        }
        #expect(attachments.map { $0.image != nil } == [true, false])
        #expect(attachments.map(\.bounds.size) == [CGSize(width: 1, height: 1), .zero])
    }

    #if os(macOS)
        @Test
        func `a printed image wider than the page is scaled to fit`() async throws {
            let png = try MarkdownViewMacLayoutTests.png(width: 800, height: 100)
            let view = MarkdownView(text: "![wide](wide.png)\n", host: nil)

            let printed = await view.printableText(width: 400) { _ in .image(png) }

            let attachment = try #require(printed.attribute(
                .attachment,
                at: 0,
                effectiveRange: nil
            ) as? NSTextAttachment)
            #expect(attachment.bounds.size == CGSize(width: 400, height: 50))
        }

        @Test
        func `the Mac view puts RTF, HTML, and the plain text on the pasteboard`() throws {
            let view = MarkdownView(text: "**bold** word\n", host: nil)
            let pasteboard = NSPasteboard(name: NSPasteboard.Name("rich-\(UUID().uuidString)"))

            view.copyAsRichText(to: pasteboard)

            let rtf = try #require(pasteboard.data(forType: .rtf))
            let read = try NSAttributedString(
                data: rtf,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            #expect(read.string == "bold word")
            #expect(pasteboard.string(forType: .html) == "<p><strong>bold</strong> word</p>\n")
            #expect(pasteboard.string(forType: .string) == "bold word")
            pasteboard.releaseGlobally()
        }

    #else
        @Test
        func `the iOS view puts RTF, HTML, and the plain text on the pasteboard`() {
            let view = MarkdownView(text: "**bold** word\n", host: nil)
            let pasteboard = UIPasteboard.withUniqueName()

            view.copyAsRichText(to: pasteboard)

            #expect(pasteboard.data(forPasteboardType: "public.rtf") != nil)
            let html = pasteboard.data(forPasteboardType: "public.html")
            #expect(html.flatMap { String(bytes: $0, encoding: .utf8) } == "<p><strong>bold</strong> word</p>\n")
            #expect(pasteboard.string == "bold word")
            UIPasteboard.remove(withName: pasteboard.name)
        }
    #endif
}
