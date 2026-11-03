import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Where the list markers and checkboxes sit (design log 001 › Rendering,
/// Tasks): before the text in its indent, on the middle of the capitals.
@MainActor
struct MarkerLayoutTests {
    /// The first fragment's box, the x where its text starts, and the y of
    /// the middle of the capitals, all in fragment coordinates.
    struct Layout {
        let box: CGRect
        let textStart: CGFloat
        let capMiddle: CGFloat
    }

    static func layout(_ text: String) throws -> Layout {
        let fragment = try firstFragment(text, mode: .rendered)
        let box = try #require(fragment.markerBoxes.first).rect
        let line = try #require(fragment.textLineFragments.first)
        let first = line.characterRange.location
        let font = try #require(
            fragment.textElement.flatMap { ($0 as? NSTextParagraph)?.attributedString }?
                .attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont
        )
        let baseline = line.typographicBounds.minY + line.glyphOrigin.y
        // Right-to-left text ends its first line at the right edge.
        let isRightToLeft = text.unicodeScalars.contains { (0x0590 ... 0x08FF).contains($0.value) }
        let start = isRightToLeft ? line.typographicBounds.maxX
            : line.typographicBounds.minX + line.locationForCharacter(at: first).x
        return Layout(box: box, textStart: start, capMiddle: baseline - font.capHeight / 2)
    }

    static func firstFragment(_ text: String, mode: MarkdownMode) throws -> MarkdownLayoutFragment {
        let view = MarkdownView(text: text, mode: mode, host: nil)
        view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        #if os(macOS)
            view.layoutSubtreeIfNeeded()
        #else
            view.layoutIfNeeded()
        #endif
        let layout = try #require(view.textView.textLayoutManager)
        layout.ensureLayout(for: layout.documentRange)
        return try #require(
            layout.textLayoutFragment(for: layout.documentRange.location) as? MarkdownLayoutFragment
        )
    }

    @Test(arguments: ["- [ ] Buy milk\n", "- [x] Done\n", "- Bullet\n", "3. Third\n"])
    func `a marker sits before its text, on the middle of the capitals`(text: String) throws {
        let layout = try Self.layout(text)
        let (box, start, capMiddle) = (layout.box, layout.textStart, layout.capMiddle)

        #expect(box.maxX <= start - 3)
        #expect(box.minX >= start - MarkdownAttributedText.indentStep)
        #expect(abs(box.midY - capMiddle) < 1)
    }

    @Test
    func `in right-to-left text the checkbox sits to the right of the text`() throws {
        let layout = try Self.layout("- [ ] לקנות חלב\n")
        let (box, start) = (layout.box, layout.textStart)

        #expect(box.minX >= start + 3)
        #expect(box.maxX <= start + MarkdownAttributedText.indentStep)
    }

    @Test(arguments: ["- [ ] Buy milk\n", "- [ ] לקנות חלב\n"])
    func `in the editor the checkbox covers its brackets`(text: String) throws {
        let fragment = try Self.firstFragment(text, mode: .editor)
        let box = try #require(fragment.markerBoxes.first).rect
        let line = try #require(fragment.textLineFragments.first)
        let left = line.typographicBounds.minX
        let ends = [2, 5].map { left + line.locationForCharacter(at: $0).x }

        #expect(abs(box.midX - (ends[0] + ends[1]) / 2) < 1)
    }

    @Test(arguments: [("> Quote\n", 1), (">> Deeper\n", 2)])
    func `a quote's bars sit in its indent, before the text`(text: String, depth: Int) throws {
        let fragment = try Self.firstFragment(text, mode: .rendered)
        let line = try #require(fragment.textLineFragments.first)
        let start = line.typographicBounds.minX + line.locationForCharacter(at: line.characterRange.location).x
        let bars = fragment.quoteBars

        #expect(bars.count == depth)
        let indent = CGFloat(depth) * MarkdownAttributedText.indentStep
        #expect(bars.allSatisfy { $0.maxX <= start - 3 && $0.minX >= start - indent })
    }

    @Test
    func `in right-to-left text a quote's bar sits to the right of the text`() throws {
        let fragment = try Self.firstFragment("> ציטוט\n", mode: .rendered)
        let start = try #require(fragment.textLineFragments.first).typographicBounds.maxX
        let bar = try #require(fragment.quoteBars.first)

        #expect(bar.minX >= start + 3)
        #expect(bar.maxX <= start + MarkdownAttributedText.indentStep)
    }
}
