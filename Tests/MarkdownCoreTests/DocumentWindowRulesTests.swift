import Foundation
import MarkdownCore
import Testing

/// Design › Files (word count), Windows and chrome (zoom, folder access).
struct DocumentWindowRulesTests {
    @Test(arguments: [("", 0), ("one", 1), ("# Two words\n\n- [ ] and *three*\n", 4), ("שלום עולם", 2)])
    func `the word count counts the words of the text`(text: String, count: Int) {
        #expect(WordCount.count(text) == count)
    }

    @Test
    func `zoom steps 10 percent from 80 to 200`() {
        #expect(Zoom.zoomedIn(1) == 1.1)
        #expect(Zoom.zoomedIn(1.9) == 2)
        #expect(Zoom.zoomedIn(2) == 2)
        #expect(Zoom.zoomedOut(1) == 0.9)
        #expect(Zoom.zoomedOut(0.8) == 0.8)
        #expect(Zoom.actualSize == 1)
    }

    @Test(arguments: [
        ("![a](a.png)", true), ("[b](b.md)", true), ("![a](https://e.com/a.png)", false),
        ("[b](https://e.com)", false), ("[b](b.rtf)", false), ("[h](#top)", false), ("text", false)
    ])
    func `a document needs its folder for a relative image or a sibling link`(text: String, needs: Bool) {
        let document = MarkdownDocument(text: text, features: MarkdownFeatures(), presentation: MarkdownPresentation())

        #expect(document.needsFolder(documentURL: URL(filePath: "/d/a.md")) == needs)
        #expect(!document.needsFolder(documentURL: nil))
    }
}
