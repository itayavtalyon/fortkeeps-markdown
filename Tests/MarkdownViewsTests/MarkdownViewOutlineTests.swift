import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// The Outline (screens §3.4): the host lists the headings, follows the
/// current one as the view scrolls, and shows the one the person picks.
@MainActor
struct MarkdownViewOutlineTests {
    static let text = "# A\n\n" + String(repeating: "line\n\n", count: 80) + "## B\n\n" + String(
        repeating: "more\n\n",
        count: 80
    )

    static func view() -> MarkdownView {
        let view = MarkdownView(text: text, host: nil)
        view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        #if os(macOS)
            view.layoutSubtreeIfNeeded()
        #else
            view.layoutIfNeeded()
        #endif
        return view
    }

    @Test
    func `the view lists the outline, shows a heading, and reports each scroll`() async throws {
        let view = Self.view()
        var scrolls = 0
        view.onScroll = { scrolls += 1 }
        let outline = await view.loadOutline()
        #expect(outline.map(\.title) == ["A", "B"])
        #expect(view.currentOutlineIndex == 0)

        let second = try #require(outline.last)
        view.showOutlineItem(second)

        #expect(view.anchor.selection == second.sourceOffset ..< second.sourceOffset)
        #expect(view.currentOutlineIndex == 1)
        #expect(scrolls > 0)
    }

    /// Plan 01: no editor path parses the whole text after open (log 004 Round 6).
    @Test
    func `after an edit only loading the outline parses, and it keeps the result`() async {
        let view = Self.view()
        _ = await view.loadOutline()

        view.replaceText("# C\n\n" + Self.text)

        #expect(view.currentOutlineIndex == nil)
        #expect(view.controller.cachedDocument == nil)
        let outline = await view.loadOutline()
        #expect(outline.map(\.title) == ["C", "A", "B"])
        #expect(view.controller.cachedDocument?.outline == outline)
        #expect(view.currentOutlineIndex == 0)
    }

    @Test
    func `a document built for a text that has changed since is not kept`() {
        let view = Self.view()
        view.reload(text: "# New\n")
        let old = MarkdownDocument(text: "# Old\n", features: MarkdownFeatures(), presentation: MarkdownPresentation())

        view.controller.keep(old, for: "# Old\n")
        #expect(view.controller.cachedDocument == nil)

        view.controller.keep(old, for: "# New\n")
        #expect(view.controller.cachedDocument?.outline == old.outline)
    }
}
