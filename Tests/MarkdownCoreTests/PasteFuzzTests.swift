import Foundation
import MarkdownCore
import Testing

/// Design › Paste: the converter runs under a fuzz test with no crash. The
/// default run fuzzes for one second; `FORTKEEPS_FUZZ_SECONDS` sets a longer
/// run (CI uses 600 on each pull request, `just fuzz` too).
struct PasteFuzzTests {
    /// SplitMix64, so a failing seed can be replayed.
    struct Generator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    static let pieces = [
        "<p>", "</p>", "<div>", "</div>", "<b>", "</b>", "<i>", "<em>", "</em>", "<a href=\"https://e.com/x\">", "</a>",
        "<a href='javascript:x'>", "<ul>", "<ol start=\"7\">", "<li>", "</li>", "</ul>", "</ol>", "<table>", "<tr>",
        "<td colspan=\"3\">",
        "<th>", "</td>", "</tr>", "</table>", "<thead>", "<tbody>", "<pre>", "</pre>", "<code>", "</code>", "<br>",
        "<br/>",
        "<img src=\"https://e.com/a.png\" alt=\"a\">", "<img src=x alt>", "<input type=checkbox checked>",
        "<blockquote>",
        "</blockquote>", "<h1>", "</h1>", "<h7>", "<script>", "</script>", "<style>", "</style>", "<!--", "-->",
        "<!DOCTYPE",
        "<?xml", "&amp;", "&lt;", "&#x1F600;", "&#99999999;", "&unknown;", "&", "<", ">", "\"", "'", "=", "/", "*", "_",
        "`",
        "[", "]", "#", "-", "1.", "|", "~", "\\", " ", "\n", "\t", "\r", "\u{0}", "\u{FEFF}", "שלום", "👍🏽", "\u{301}",
        "text",
        "<del>", "<s>", "<strike>", "</s>", "<span style=\"x\">", "<font>", "<sup>", "<o:p>", "<", "<a", "<p class="
    ]

    static func sample(_ generator: inout Generator) -> String {
        let count = Int.random(in: 0 ... 80, using: &generator)
        return (0 ..< count).map { _ in
            Bool.random(using: &generator)
                ? pieces.randomElement(using: &generator) ?? ""
                : String(UnicodeScalar(UInt8.random(in: 0 ... 127, using: &generator)))
        }.joined()
    }

    @Test
    func `the paste converter survives random HTML`() {
        let seconds = Double(ProcessInfo.processInfo.environment["FORTKEEPS_FUZZ_SECONDS"] ?? "") ?? 1
        let deadline = Date().addingTimeInterval(seconds)
        var generator = Generator(state: 0x5EED)
        var runs = 0
        while Date() < deadline {
            let html = Self.sample(&generator)
            let markdown = PasteConverter.markdown(fromHTML: html, documentURL: URL(fileURLWithPath: "/tmp/d.md"))
            _ = MarkdownDocument(text: markdown, features: MarkdownFeatures(), presentation: MarkdownPresentation())
            runs += 1
        }
        print("fuzz: \(runs) samples in \(seconds) s")

        #expect(runs > 0)
    }

    @Test
    func `deep nesting converts without overflowing the stack`() {
        let html = String(repeating: "<b><i><span>", count: 20000) + "x" + String(
            repeating: "</span></i></b>",
            count: 20000
        )

        #expect(PasteConverter.markdown(fromHTML: html, documentURL: nil).contains("x"))
    }

    @Test
    func `deep block nesting converts without overflowing the stack`() {
        let html = String(repeating: "<blockquote><ul><li><div><table><tr><td>", count: 5000) + "x"

        #expect(PasteConverter.markdown(fromHTML: html, documentURL: nil).contains("x"))
    }

    @Test
    func `an unclosed tag, comment, and attribute at the end convert`() {
        #expect(PasteConverter.markdown(fromHTML: "a<b c=\"d", documentURL: nil) == "a")
        #expect(PasteConverter.markdown(fromHTML: "a<!-- x", documentURL: nil) == "a")
        #expect(PasteConverter.markdown(fromHTML: "a<script>x", documentURL: nil) == "a")
        #expect(PasteConverter.markdown(fromHTML: "a < b <", documentURL: nil) == "a < b <")
        #expect(PasteConverter.markdown(fromHTML: "a</b", documentURL: nil) == "a")
        #expect(PasteConverter.markdown(fromHTML: "a<script>x</script", documentURL: nil) == "a")
    }
}
