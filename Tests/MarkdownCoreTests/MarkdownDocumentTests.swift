import Foundation
import MarkdownCore
import Testing

/// Design › Document model, Tasks, Direction, and Modes (anchor).
struct MarkdownDocumentTests {
    static let bom = "\u{FEFF}"

    static func byte(_ text: String, at offset: Int) -> Character {
        Character(Unicode.Scalar(Array(text.utf8)[offset]))
    }

    @Test
    func `blocks list the top-level blocks with kind, line, and heading level`() {
        let blocks = givenDocument("# T\n\npara\n\n- a\n\n1. b\n\n> q\n\n```\nc\n```\n\n---\n\n| x |\n|---|\n").blocks

        #expect(blocks.map(\.kind) == [
            .heading(level: 1), .paragraph, .bulletList, .orderedList, .quote, .codeBlock(fenced: true), .thematicBreak,
            .table
        ])
        #expect(blocks.map(\.line) == [0, 2, 4, 6, 8, 10, 14, 16])
    }

    @Test
    func `a task offset points at the byte between the brackets`() {
        let text = "x\n\n- [ ] a\n- [x] b\n"
        let tasks = givenDocument(text).tasks

        #expect(tasks.map(\.byteOffset) == [6, 14])
        #expect(tasks.map { Self.byte(text, at: $0.byteOffset) } == [" ", "x"])
    }

    @Test
    func `a task offset excludes a leading BOM`() {
        let tasks = givenDocument(Self.bom + "x\n\n- [ ] a\n").tasks

        #expect(tasks.map(\.byteOffset) == [6])
    }

    @Test
    func `a task records its line, checked state, and text`() {
        let task = givenDocument("> - [X] **done** it\n").tasks.first

        #expect(task?.line == 0)
        #expect(task?.checked == true)
        #expect(task?.text == "done it")
    }

    @Test
    func `a task offset inside a nested quote and list is exact`() {
        let text = "- a\n  > 1. [ ] b\n"
        let task = givenDocument(text).tasks.first

        #expect(task.map { Self.byte(text, at: $0.byteOffset - 1) } == "[")
        #expect(task.map { Self.byte(text, at: $0.byteOffset + 1) } == "]")
    }

    @Test(arguments: [("- [ ] a\n", "- [x] a\n"), ("- [x] a\n", "- [ ] a\n"), ("- [X] a\n", "- [ ] a\n")])
    func `toggleTask flips the marker byte`(text: String, toggled: String) {
        #expect(MarkdownDocument.toggleTask(at: 3, in: text) == toggled)
    }

    @Test
    func `toggleTask twice restores the text`() {
        let text = Self.bom + "שלום\n\n- [ ] משימה\n"
        let offset = givenDocument(text).tasks[0].byteOffset

        let once = MarkdownDocument.toggleTask(at: offset, in: text)

        #expect(once != text)
        #expect(MarkdownDocument.toggleTask(at: offset, in: once) == text)
    }

    @Test
    func `with the title hidden a tick on line 5 flips the correct byte`() {
        let text = "# Title\n\nIntro\n\n- [ ] one\n- [ ] two\n"
        let task = givenDocument(text, features: .fortkeeps, titleLine: .hidden).tasks[1]

        #expect(task.line == 5)
        #expect(MarkdownDocument
            .toggleTask(at: task.byteOffset, in: text) == "# Title\n\nIntro\n\n- [ ] one\n- [x] two\n")
    }

    @Test
    func `a Hebrew block is RTL and a Latin block is LTR`() {
        let blocks = givenDocument("שלום עולם\n\nhello\n\n123\n").blocks

        #expect(blocks.map(\.direction) == [.rtl, .ltr, .auto])
    }

    @Test
    func `direction ignores code spans and link destinations`() {
        let blocks = givenDocument("`code` שלום\n\n[שלום](https://example.com) x\n").blocks

        #expect(blocks.map(\.direction) == [.rtl, .rtl])
    }

    @Test
    func `a code block inside a Hebrew quote stays LTR`() {
        let rendered = givenDocument("> שלום\n>\n> ```\n> code\n> ```\n").rendered

        #expect(rendered.blocks.map(\.direction) == [.rtl, .ltr])
    }

    @Test
    func `an Arabic block is RTL`() {
        #expect(givenDocument("مرحبا\n").blocks.map(\.direction) == [.rtl])
    }

    @Test
    func `a task after lone CR line endings has the right offset`() {
        let text = "a\r\r- [x] b\r"
        let task = givenDocument(text).tasks.first

        #expect(task?.line == 2)
        #expect(task.map { Self.byte(text, at: $0.byteOffset) } == "x")
    }

    @Test
    func `a task inside a quoted former HTML block has the right offset`() {
        let text = "> <div>\n> - [x] t\n"
        let task = givenDocument(text, features: .fortkeeps).tasks.first

        #expect(task.map { Self.byte(text, at: $0.byteOffset) } == "x")
    }

    @Test
    func `a CJK block is LTR`() {
        #expect(givenDocument("漢字\n").blocks.map(\.direction) == [.ltr])
    }

    @Test
    func `a Hebrew task list puts the checkbox on the trailing edge`() {
        let document = givenDocument("- [ ] משימה\n- [ ] עוד\n")

        #expect(document.tasks.map(\.direction) == [.rtl, .rtl])
        #expect(document.tasks.map(\.direction.markerEdge) == [.trailing, .trailing])
    }

    @Test
    func `a block with no strong letter follows its parent`() {
        let rendered = givenDocument("> שלום\n>\n> 123\n").rendered

        #expect(rendered.blocks.map(\.direction) == [.rtl, .rtl])
    }

    @Test(arguments: [
        ("# Title\nbody\n", "Title"),
        ("#\tTabbed  #  \n", "Tabbed"),
        ("# Title ##\n", "Title"),
        ("#\n", nil),
        ("Title\n===\n", nil),
        ("text\n\n# Later\n", nil),
        ("#NoSpace\n", nil),
        ("\n# Late\n", nil),
        ("## Sub\n", nil)
    ] as [(String, String?)])
    func `title follows the line-1 ATX rule`(text: String, title: String?) {
        #expect(givenDocument(text).title == title)
    }

    @Test
    func `an image drawn as text copies that text`() {
        let rendered = givenDocument("a ![alt](i.png) b\n").rendered

        #expect(rendered.copyText(0 ..< rendered.utf16Count, imagesDrawnAsText: [0]) == "a Image: alt b")
    }

    @Test
    func `a table row copies its cells separated by tabs`() {
        let rendered = givenDocument("| a | b |\n|---|---|\n| c | d |\n").rendered

        #expect(rendered.copyText(0 ..< rendered.utf16Count) == "a\tb\nc\td")
    }

    @Test
    func `an empty task item still has a block for its checkbox`() {
        let document = givenDocument("- [ ] \n- [x] b\n")

        #expect(document.tasks.map(\.text) == ["", "b"])
        #expect(document.rendered.blocks.map(\.taskIndex) == [0, 1])
    }

    @Test
    func `a task text shows an image as its alt text`() {
        #expect(givenDocument("- [ ] see ![chart](c.png)\n").tasks.first?.text == "see Image: chart")
    }

    /// swift-cmark 0.9.0 shifts an inline on these lines; the image starts at its `![`.
    @Test(arguments: [
        ("- [ ] t\n![m](x.png)\nx", 8 ..< 19), ("- t\n![m](x.png)", 4 ..< 15), ("> q\n![m](x.png)", 4 ..< 15),
        ("para\n   ![m](x.png)\n", 8 ..< 19), ("para\n![m](x.png)", 5 ..< 16)
    ])
    func `an image on a lazy or indented continuation line keeps its source range`(text: String, range: Range<Int>) {
        #expect(givenDocument(text).rendered.images.map(\.sourceRange) == [range])
    }

    @Test
    func `a task text reads an image with no alt as Image, as copy does`() {
        #expect(givenDocument("- [ ] see ![](c.png) now\n").tasks.first?.text == "see Image now")
    }

    @Test
    func `a task text shows each image as its own alt text and keeps a typed U+FFFC`() {
        #expect(givenDocument("- [ ] ![a](1.png) \u{FFFC} ![b](2.png)\n").tasks.first?
            .text == "Image: a \u{FFFC} Image: b")
    }

    @Test
    func `an anchor before the first block names the document start`() {
        #expect(givenDocument("\n\npara\n").anchor(firstVisibleSourceOffset: 0, selection: 0 ..< 0) == .documentStart)
    }

    @Test
    func `a selection on hidden syntax snaps to content characters`() {
        let document = givenDocument("ab **cd** ef\n")

        #expect(document.snappedSelection(3 ..< 9) == 5 ..< 7)
    }

    @Test
    func `an offset inside a re-parsed HTML block maps to the document byte`() {
        let text = "> <div>\n> *em* x\n"
        let rendered = givenDocument(text, features: .fortkeeps).rendered
        let emOffset = Array(text.utf8).firstIndex(of: UInt8(ascii: "e"))

        #expect(rendered.string == "<div>\nem x")
        #expect(emOffset.map { rendered.renderedOffset(atSource: $0) } == 6)
        #expect(rendered.sourceOffset(atRendered: 0) == 2)
    }

    @Test
    func `an anchor encodes and decodes to the same value`() throws {
        let anchor = MarkdownAnchor(block: 12, offsetInBlock: 3, selection: 15 ..< 20)

        let data = try JSONEncoder().encode(anchor)

        #expect(try JSONDecoder().decode(MarkdownAnchor.self, from: data) == anchor)
    }

    @Test
    func `anchor names the top-level block that holds the first visible offset`() {
        let document = givenDocument("one\n\n> two\n> more\n")

        let anchor = document.anchor(firstVisibleSourceOffset: 10, selection: 7 ..< 9)

        #expect(anchor == MarkdownAnchor(block: 5, offsetInBlock: 5, selection: 7 ..< 9))
    }

    @Test
    func `the document start anchor is all zeros`() {
        #expect(MarkdownAnchor.documentStart == MarkdownAnchor(block: 0, offsetInBlock: 0, selection: 0 ..< 0))
    }
}
