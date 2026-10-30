import MarkdownCore
import Testing

/// Design › Features and View settings.
struct MarkdownFeaturesTests {
    @Test
    func `a new MarkdownFeatures matches the Design default column`() {
        let features = MarkdownFeatures()

        #expect(features.strikethrough)
        #expect(features.autolink)
        #expect(features.html)
        #expect(features.tables)
        #expect(features.taskLists)
        #expect(features.pasteHtml)
        #expect(!features.softBreakAsLine)
    }

    @Test
    func `the Fortkeeps value matches the Design Fortkeeps row`() {
        let features = MarkdownFeatures.fortkeeps

        #expect(!features.strikethrough)
        #expect(!features.autolink)
        #expect(!features.html)
        #expect(features.tables)
        #expect(features.taskLists)
        #expect(!features.pasteHtml)
        #expect(features.softBreakAsLine)
    }

    @Test
    func `a new MarkdownPresentation shows the title line in the body and images as text`() {
        let presentation = MarkdownPresentation()

        #expect(presentation.titleLine == .inBody)
        #expect(presentation.imageFallback == .text)
    }
}
