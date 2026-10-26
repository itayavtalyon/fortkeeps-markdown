@testable import MarkdownCore
import Testing

/// Card rules of log 010 at their boundaries; the conformance cases cover the
/// ordinary values.
struct FortkeepsCardTests {
    @Test(arguments: [(69, FortkeepsCard.FactSize.extraLarge), (70, .large), (149, .large), (150, .medium)])
    func `a fact size changes at 70 and 150 visible characters`(length: Int, size: FortkeepsCard.FactSize) {
        let card = FortkeepsCard(text: String(repeating: "a", count: length) + "\n")

        #expect(card.visibleLength == length)
        #expect(card.factSize == size)
    }

    @Test
    func `a URL line wins over a title`() {
        #expect(FortkeepsCard(text: "# T\nhttps://e.com/x\n").variant == .savedLink)
    }

    @Test
    func `one status field is a fact and two are a status`() {
        #expect(FortkeepsCard(text: "PATH: x\n").variant == .fact)
        #expect(FortkeepsCard(text: "PATH: x\nNEXT: y\n").variant == .status)
    }

    @Test
    func `a status field name has at least two characters`() {
        #expect(FortkeepsCard(text: "A: x\nB: y\n").variant == .fact)
        #expect(FortkeepsCard(text: "AB: x\nBC: y\n").statusFields == ["AB", "BC"])
    }

    @Test
    func `a doc lists no status fields`() {
        let card = FortkeepsCard(text: "# T\n\nAB: x\nCD: y\n")

        #expect(card.variant == .doc)
        #expect(card.statusFields.isEmpty)
    }
}
