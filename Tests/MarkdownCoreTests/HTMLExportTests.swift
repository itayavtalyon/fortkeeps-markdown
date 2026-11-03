import Foundation
@testable import MarkdownCore
import Testing

/// Export as HTML (design log 001 › Windows and chrome; log 004 Round 6): one
/// self-contained file with no scripts that fetches nothing.
struct HTMLExportTests {
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
    static let document = URL(fileURLWithPath: "/notes/trip/a.md")

    static func page(_ markdown: String, files: [String: Data] = [:], read: inout [URL]) -> String {
        var reads: [URL] = []
        let page = HTMLExport.page(
            markdown: markdown,
            title: "a.md",
            documentURL: document,
            features: MarkdownFeatures()
        ) {
            reads.append($0)
            return files[$0.path]
        }
        read = reads
        return page
    }

    @Test
    func `the export has no script, embeds a local image as data, and fetches nothing`() {
        var read: [URL] = []
        let page = Self.page(
            "<script>alert(1)</script>\n\nA <b onclick=\"x()\">bold</b> word.\n\n![map](map.png)\n\n![far](https://example.com/far.png)\n",
            files: ["/notes/trip/map.png": Self.png],
            read: &read
        )

        #expect(!page.lowercased().contains("<script"))
        #expect(!page.contains("<b onclick"))
        #expect(page.contains("<pre><code>&lt;script&gt;alert(1)&lt;/script&gt;\n</code></pre>"))
        #expect(page.contains("<code>&lt;b onclick=&quot;x()&quot;&gt;</code>bold<code>&lt;/b&gt;</code>"))
        #expect(page.contains("<img src=\"data:image/png;base64,\(Self.png.base64EncodedString())\" alt=\"map\" />"))
        #expect(page.contains("<a href=\"https://example.com/far.png\">far</a>"))
        #expect(!page.contains("src=\"http"))
        #expect(page.contains("default-src 'none'"))
        #expect(read == [URL(fileURLWithPath: "/notes/trip/map.png")])
    }

    @Test
    func `an image it cannot read or show is a link`() {
        var read: [URL] = []
        let page = Self.page(
            "![gone](gone.png) ![text](notes.txt) ![](https://example.com/x.png)\n",
            files: ["/notes/trip/notes.txt": Data("plain".utf8)],
            read: &read
        )

        #expect(page.contains("<a href=\"gone.png\">gone</a>"))
        #expect(page.contains("<a href=\"notes.txt\">text</a>"))
        #expect(page.contains("<a href=\"https://example.com/x.png\">https://example.com/x.png</a>"))
    }

    @Test
    func `a remote image inside a link is a link too, with its title`() {
        var read: [URL] = []
        let page = Self.page("[![far](https://example.com/far.png \"Far\")](https://example.com)\n", read: &read)

        #expect(page.contains("<a href=\"https://example.com/far.png\" title=\"Far\">far</a>"))
        #expect(!page.contains("src=\"http"))
    }

    @Test
    func `each image type it embeds has its own media type`() {
        let types: [(Data, String)] = [
            (Data([0xFF, 0xD8, 0xFF, 0xE0]), "image/jpeg"),
            (Data("GIF89a".utf8), "image/gif"),
            (Data("RIFF\u{0}\u{0}\u{0}\u{0}WEBPVP8 ".utf8), "image/webp")
        ]
        for (bytes, type) in types {
            var read: [URL] = []
            let page = Self.page("![x](x.img)\n", files: ["/notes/trip/x.img": bytes], read: &read)
            #expect(page.contains("data:\(type);base64,"))
        }
        // Near misses: a PNG signature cut short, and a RIFF file that is a sound.
        for bytes in [Data([0x89, 0x50, 0x00, 0x00, 0x0D, 0x0A]), Data("RIFF\u{0}\u{0}\u{0}\u{0}WAVEfmt ".utf8)] {
            #expect(HTMLExport.mediaType(of: bytes) == nil)
        }
    }

    @Test
    func `a script destination of a link or an image is dropped`() {
        var read: [URL] = []

        let page = Self.page("[x](javascript:alert(1)) ![y](javascript:alert(2))\n", files: [:], read: &read)

        #expect(!page.contains("javascript:"))
    }

    @Test
    func `the page is a whole document with its title, the text, and the tables and tasks`() {
        var read: [URL] = []
        let page = Self.page("# Trip <one>\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] done\n", read: &read)

        #expect(page.hasPrefix("<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"))
        #expect(page.contains("<title>a.md</title>"))
        #expect(page.contains("<h1>Trip <code>&lt;one&gt;</code></h1>"))
        #expect(page.contains("<table>"))
        #expect(page.contains("<input type=\"checkbox\" checked=\"\" disabled=\"\" /> done"))
        #expect(page.hasSuffix("</body>\n</html>\n"))
    }

    @Test
    func `the title is escaped`() {
        let page = HTMLExport
            .page(markdown: "", title: "<a&b>", documentURL: nil, features: MarkdownFeatures()) { _ in nil }

        #expect(page.contains("<title>&lt;a&amp;b&gt;</title>"))
    }

    @Test
    func `the body alone is the rich-text HTML of a selection`() {
        let body = HTMLExport
            .body(markdown: "**bold** <i>x</i>\n", documentURL: nil, features: MarkdownFeatures()) { _ in nil }

        #expect(body == "<p><strong>bold</strong> <code>&lt;i&gt;</code>x<code>&lt;/i&gt;</code></p>\n")
    }
}
