import MarkdownCore
import Testing

/// The Outline (screens §3.4): the headings in reading order.
struct OutlineTests {
    @Test
    func `the outline lists each heading with its level, its text, and where it starts`() {
        let outline = givenDocument("# A\n\npara\n\n## B *em*\n\n> ### C\n\nSetext\n===\n").outline

        #expect(outline.map(\.level) == [1, 2, 3, 1])
        #expect(outline.map(\.title) == ["A", "B em", "C", "Setext"])
        #expect(outline.prefix(2).map(\.sourceOffset) == [0, 11])
        // An entity can leave a space cmark does not trim.
        #expect(givenDocument("# Trip&nbsp;\n").outline.map(\.title) == ["Trip"])
    }

    @Test
    func `the current heading is the last one at or before an offset`() {
        let document = givenDocument("intro\n\n# A\n\ntext\n\n## B\n")

        #expect(document.outlineIndex(atSourceOffset: 0) == nil)
        #expect(document.outlineIndex(atSourceOffset: 7) == 0)
        #expect(document.outlineIndex(atSourceOffset: 14) == 0)
        #expect(document.outlineIndex(atSourceOffset: 19) == 1)
    }
}
