import MarkdownCore
import Testing

/// Design › Rendering: the drawn text, copy, and the map to the source.
struct RenderedTextTests {
    @Test
    func `a block source range covers its bytes`() {
        let text = "ab\n\n## cd\n"
        let block = givenDocument(text).blocks[1]

        #expect(Array(text.utf8)[block.sourceRange].elementsEqual("## cd".utf8))
    }

    @Test
    func `the hidden title is not in the rendered text`() {
        #expect(givenDocument("# Title\n\nBody\n", titleLine: .hidden).rendered.string == "Body")
        #expect(givenDocument("# Title\n\nBody\n").rendered.string == "Title\nBody")
    }

    @Test
    func `copy of a heading, a link, a code span, and a fence drops the syntax`() {
        let rendered =
            givenDocument("## Head\n\nSee [the site](https://e.com) and `x = 1`.\n\n```swift\nlet a = 2\n```\n")
                .rendered

        #expect(rendered.copyText(0 ..< rendered.utf16Count) == "Head\nSee the site and x = 1.\nlet a = 2")
    }

    @Test
    func `copy has no direction marks`() {
        let rendered = givenDocument("שלום `code` world\n").rendered

        let copy = rendered.copyText(0 ..< rendered.utf16Count)

        #expect(!copy.unicodeScalars
            .contains { (0x200E ... 0x200F).contains($0.value) || (0x2066 ... 0x2069).contains($0.value) })
    }

    @Test
    func `a drawn image adds no copy characters`() {
        let rendered = givenDocument("a ![alt](i.png) b\n").rendered

        #expect(rendered.copyText(0 ..< rendered.utf16Count) == "a  b")
    }

    @Test
    func `copy separates blocks with one newline, also across an empty block`() {
        let rendered = givenDocument("a\n\n---\n\nb\n\n- c\n- d\n").rendered

        #expect(rendered.copyText(0 ..< rendered.utf16Count) == "a\nb\nc\nd")
    }

    @Test
    func `copy of part of a block takes only the selected characters`() {
        let rendered = givenDocument("hello **world**\n\nnext\n").rendered

        #expect(rendered.copyText(6 ..< 14) == "world\nne")
    }

    @Test
    func `copy skips a block that holds only a drawn image`() {
        let rendered = givenDocument("a\n\n![x](i.png)\n\nb\n").rendered

        #expect(rendered.copyText(0 ..< rendered.utf16Count) == "a\nb")
    }

    @Test
    func `an offset halfway between two blocks snaps forward`() {
        #expect(givenDocument("a\n\nb\n").rendered.renderedOffset(atSource: 2) == 2)
    }

    @Test
    func `a hard break is a line break`() {
        #expect(givenDocument("a  \nb\\\nc\n").rendered.string == "a\nb\nc")
    }

    @Test
    func `a soft break is a space by default and a line break with softBreakAsLine`() {
        var lines = MarkdownFeatures()
        lines.softBreakAsLine = true

        #expect(givenDocument("a\nb\n").rendered.string == "a b")
        #expect(givenDocument("a\nb\n", features: lines).rendered.string == "a\nb")
    }

    @Test
    func `the rendered text records links and images with their destinations`() {
        let rendered = givenDocument("[go](https://e.com) ![pic](p.png)\n").rendered

        #expect(rendered.links.map(\.destination) == ["https://e.com"])
        #expect(rendered.links.map(\.range) == [0 ..< 2])
        #expect(rendered.images.map(\.destination) == ["p.png"])
        #expect(rendered.images.map(\.alt) == ["pic"])
        #expect(rendered.images.map(\.offset) == [3])
    }

    @Test
    func `a source to rendered to source round trip keeps each offset that is not on hidden syntax`() {
        let text = "# Head *em*\n\nא \\*b\\* &amp; [lab](http://u) `c d`\nnext  \nline\n\n"
            + "> - [ ] task ~~s~~\n\n```\ncode\n```\n"
        let rendered = givenDocument(text).rendered

        let visible = (0 ..< text.utf8.count).filter { rendered.isVisible(sourceOffset: $0) }
        let roundTrip = visible.map { rendered.sourceOffset(atRendered: rendered.renderedOffset(atSource: $0)) }

        #expect(visible.count > 30)
        #expect(roundTrip == visible)
    }

    @Test
    func `each visible source character equals its rendered character`() {
        let text = "Hello *wörld* \\_x\\_ שלום `co de`\n"
        let rendered = givenDocument(text).rendered
        let utf16 = Array(rendered.string.utf16)

        let mismatches = (0 ..< text.utf8.count).filter { offset in
            guard rendered.isVisible(sourceOffset: offset) else { return false }
            let index = text.utf8.index(text.utf8.startIndex, offsetBy: offset)
            guard let scalar = text[index...].unicodeScalars.first, text.utf8[index] < 0x80 || text.utf8[index] >= 0xC0
            else { return false }
            let start = rendered.renderedOffset(atSource: offset)
            return String(utf16CodeUnits: Array(utf16[start ..< start + scalar.utf16.count]), count: scalar.utf16.count)
                != String(scalar)
        }

        #expect(mismatches.isEmpty)
    }

    @Test
    func `characters after an entity, an escape, and a NUL stay visible`() {
        let text = "a &amp; \\* \u{0}b cd\n"
        let rendered = givenDocument(text).rendered
        let tail = text.utf8.count - 3

        #expect(rendered.string == "a & * \u{FFFD}b cd")
        #expect([tail, tail + 1].map { rendered.isVisible(sourceOffset: $0) } == [true, true])
        #expect(rendered.renderedOffset(atSource: tail) == rendered.utf16Count - 2)
    }

    @Test
    func `an offset inside an entity snaps to the nearer side of its character`() {
        let rendered = givenDocument("a&amp;b\n").rendered

        #expect(rendered.renderedOffset(atSource: 2) == 1)
        #expect(rendered.renderedOffset(atSource: 5) == 2)
    }

    @Test
    func `a rendered position between blocks maps to the next block forward and the previous block backward`() {
        let rendered = givenDocument("ab\n\ncd\n").rendered

        #expect(rendered.sourceOffset(atRendered: 2) == 4)
        #expect(rendered.sourceOffset(atRendered: 3, affinity: .backward) == 2)
        #expect(rendered.sourceOffset(atRendered: 5) == 6)
        #expect(rendered.sourceOffset(atRendered: 0, affinity: .backward) == 0)
    }

    @Test
    func `an empty document maps every position to zero`() {
        let rendered = givenDocument("").rendered

        #expect(rendered.string.isEmpty)
        #expect(rendered.sourceOffset(atRendered: 0) == 0)
        #expect(rendered.sourceOffset(atRendered: 0, affinity: .backward) == 0)
        #expect(rendered.renderedOffset(atSource: 0) == 0)
    }

    @Test
    func `a multi-line code block maps each line to its source line inside a quote`() {
        let text = "> ```\n> one\n> two\n> ```\n"
        let rendered = givenDocument(text).rendered
        let two = Array(text.utf8).firstIndex(of: UInt8(ascii: "t"))

        #expect(rendered.string == "one\ntwo")
        #expect(two.map { rendered.renderedOffset(atSource: $0) } == 4)
        #expect(rendered.copyText(0 ..< rendered.utf16Count) == "one\ntwo")
    }

    @Test
    func `a code line whose tab cmark expands still renders`() {
        let rendered = givenDocument("- a\n\n\t\tcode\n").rendered

        #expect(rendered.string.hasSuffix("code"))
        #expect(rendered.blocks.map(\.kind) == [.paragraph, .codeBlock])
    }

    @Test
    func `raw HTML with html true renders as its source text`() {
        let rendered = givenDocument("<div>\n<b>x</b>\n</div>\n").rendered

        #expect(rendered.string == "<div>\n<b>x</b>\n</div>")
        #expect(rendered.blocks.map(\.kind) == [.htmlBlock])
    }

    @Test
    func `a code span across a CRLF keeps the next line's characters visible`() {
        let text = "`a\r\nb`\n"
        let rendered = givenDocument(text).rendered

        #expect(rendered.string == "a b")
        #expect(rendered.isVisible(sourceOffset: 4))
        #expect(rendered.renderedOffset(atSource: 4) == 2)
    }

    @Test
    func `an ampersand and semicolon that are not an entity stay visible`() {
        let rendered = givenDocument("a &; b\n").rendered

        #expect(rendered.string == "a &; b")
        #expect((2 ... 3).map { rendered.isVisible(sourceOffset: $0) } == [true, true])
    }

    @Test
    func `a padded code span maps its first character past the padding`() {
        let text = "x ` a ` y\n"
        let rendered = givenDocument(text).rendered

        #expect(rendered.string == "x a y")
        #expect(rendered.renderedOffset(atSource: 4) == 2)
        #expect(rendered.isVisible(sourceOffset: 4))
    }

    @Test
    func `a source offset on hidden syntax snaps to the nearest content character`() {
        let rendered = givenDocument("ab **cd**\n").rendered

        #expect(rendered.renderedOffset(atSource: 3) == 3)
        #expect(rendered.renderedOffset(atSource: 4) == 3)
        #expect(rendered.renderedOffset(atSource: 7) == 5)
        #expect(rendered.renderedOffset(atSource: 8) == 5)
    }
}
