import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Design › Editor: the neighborhood restyle, and the line count it starts from.
@MainActor
struct MarkdownDisplayTests {
    /// The font and the light-appearance colors of every UTF-16 unit of the
    /// display, so a test compares what draws, not color objects.
    static func attributes(_ display: MarkdownDisplay) -> [String] {
        (0 ..< display.storage.length).map { offset in
            let attributes = display.storage.attributes(at: offset, effectiveRange: nil)
            #if os(macOS)
                let light = { (color: Any?) in MarkdownViewMacTests.lightComponents(color) }
            #else
                let light = { (color: Any?) in MarkdownViewIOSTests.lightComponents(color) }
            #endif
            return "\(attributes[.font] ?? "") \(light(attributes[.foregroundColor])) " +
                "\(light(attributes[.backgroundColor])) \(attributes[.paragraphStyle] ?? "")"
        }
    }

    /// 11 is on the line after the opening fence, so the neighborhood starts at
    /// the fence; 21 is on the closing fence, three lines inside it.
    @Test(arguments: [11, 21])
    func `a neighborhood restyle near a fence matches the full style`(caret: Int) {
        let text = "intro\n```\na\nb\nc\n*d*\n```\nafter *e*"
        let controller = MarkdownTextController(
            text: text,
            features: MarkdownFeatures(),
            presentation: MarkdownPresentation(),
            mode: .editor,
            maxUTF8Bytes: nil,
            documentURL: nil
        )
        let display = MarkdownDisplay(controller: controller, storage: NSTextStorage())
        controller.selection = caret ..< caret
        display.rebuild()
        let full = Self.attributes(display)

        display.restyle(around: caret)

        #expect(Self.attributes(display) == full)
    }

    @Test
    func `a restyle writes to the storage only when a style changed`() {
        let display = Self.givenDisplay("a *b* `c`\n- [ ] task\n")
        var edits = 0
        let observer = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification, object: display.storage, queue: nil
        ) { _ in edits += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        display.restyle(around: 3)
        let unchanged = edits
        Self.type("# ", at: 0 ..< 0, in: display)

        #expect(unchanged == 0)
        #expect(edits == 2)
        #expect(MarkdownTheme.color(.text3) === MarkdownTheme.color(.text3))
    }

    static func givenDisplay(_ text: String) -> MarkdownDisplay {
        let controller = MarkdownTextController(
            text: text,
            features: MarkdownFeatures(),
            presentation: MarkdownPresentation(),
            mode: .editor,
            maxUTF8Bytes: nil,
            documentURL: nil
        )
        let display = MarkdownDisplay(controller: controller, storage: NSTextStorage())
        display.rebuild()
        return display
    }

    /// Applies an edit as a text view does: the caret ends after the inserted
    /// text, then the display restyles around the edit.
    static func type(_ replacement: String, at range: Range<Int>, in display: MarkdownDisplay) {
        display.storage.replaceCharacters(in: NSRange(range), with: replacement)
        let caret = range.lowerBound + replacement.utf16.count
        display.controller.selection = caret ..< caret
        display.controller.textViewDidReplace(range, with: replacement, event: .typed(replacement), at: 0)
        display.restyle(around: range.lowerBound)
    }

    /// As a text view's selection change does: restyles the old caret line and the new one.
    static func moveCaret(to caret: Int, in display: MarkdownDisplay) {
        let previous = display.controller.selection.lowerBound
        display.controller.selection = caret ..< caret
        display.restyle(around: previous)
        display.restyle(around: caret)
    }

    /// The attributes after the edit equal those of a display built from the new text.
    static func expectFullStyle(_ display: MarkdownDisplay, sourceLocation: SourceLocation = #_sourceLocation) {
        let fresh = givenDisplay(display.controller.text)
        fresh.controller.selection = display.controller.selection
        fresh.rebuild()
        #expect(attributes(display) == attributes(fresh), sourceLocation: sourceLocation)
    }

    @Test
    func `a fence typed above reaches the lines below the neighborhood at once`() {
        let display = Self.givenDisplay("intro\n\n*a*\n*b*\n*c*\n*d*\nend")

        Self.type("```\n", at: 0 ..< 0, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `removing a fence frees the lines below it at once`() {
        let display = Self.givenDisplay("```\n*a*\n*b*\n*c*\n*d*\n```\nend")

        Self.type("", at: 0 ..< 4, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `pasted lines with a fence style every line after them`() {
        let display = Self.givenDisplay("top\n*a*\n*b*\n```\n*c*\n```\n*d*")

        Self.type("one\n```\ntwo\nthree", at: 3 ..< 3, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `deleting lines keeps the stored states in step with the text`() {
        let display = Self.givenDisplay("a\nb\nc\nd\n```\n*x*\n```\n*y*")

        Self.type("", at: 2 ..< 6, in: display)
        Self.type("```\n", at: 0 ..< 0, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `a second edit below a new fence enters the fence`() {
        let display = Self.givenDisplay("a\nb\nc\n*d*\n*e*\n*f*\n*g*")

        Self.type("```\n", at: 4 ..< 4, in: display)
        Self.type("x", at: 13 ..< 13, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `an edit two lines below a fence on the first line enters the fence`() {
        let display = Self.givenDisplay("```\na\n*b*\n*c*")

        Self.type("x", at: 6 ..< 6, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `lines typed in the middle of a line restyle the tail they move down`() {
        let display = Self.givenDisplay("a\nb\nc # head\nd")

        Self.type("\nx\n", at: 6 ..< 6, in: display)

        Self.expectFullStyle(display)
    }

    @Test
    func `a restyle past the neighborhood draws the caret on the line that holds it`() {
        let display = Self.givenDisplay("```\na\nb\nc\n- [ ] t\n```")
        let caret = 15
        display.storage.replaceCharacters(in: NSRange(location: 0, length: 4), with: "")
        display.controller.textViewDidReplace(0 ..< 4, with: "", event: .typed(""), at: 0)
        display.controller.selection = caret - 4 ..< caret - 4

        display.restyle(around: 0)

        Self.expectFullStyle(display)
    }

    @Test
    func `an image source inside a fence opened above the restyle gets no card`() {
        let display = Self.givenDisplay("```\na\nb\n![m](x.png)\nc\n```")

        Self.type("x", at: 8 ..< 8, in: display)

        Self.expectFullStyle(display)
    }

    /// SplitMix64: the same edits on every run.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    /// A differential over many edits of fence-heavy text: after each edit the
    /// display equals a display built from the new text. Edits are whole lines
    /// and a character typed at a line end; the editor finds images in the
    /// restyled lines only, so an inline that spans lines into them (a code
    /// span) is outside what this compares.
    @Test
    func `random line edits of fenced text leave the same styles as a full build`() {
        var random = SeededGenerator(state: 2026)
        let lines = ["```", "~~~", "*a*", "- [ ] t", "![m](x.png)", "", "text", "> q"]
        let display = Self.givenDisplay("intro\n```\n*a*\n```\n- [ ] t\n![m](x.png)\nend")
        for step in 0 ..< 300 {
            let text = display.controller.text
            let starts = [0] + text.utf16.indices.filter { text.utf16[$0] == 0x0A }
                .map { text.utf16.distance(from: text.utf16.startIndex, to: $0) + 1 }
            let line = Int.random(in: 0 ..< starts.count, using: &random)
            let end = line + 1 < starts.count ? starts[line + 1] - 1 : text.utf16.count
            Self.moveCaret(to: starts[line], in: display)
            switch Int.random(in: 0 ..< 3, using: &random) {
            case 0: Self.type(
                    (lines.randomElement(using: &random) ?? "") + "\n",
                    at: starts[line] ..< starts[line],
                    in: display
                )
            case 1 where starts.count > 1: Self.type(
                    "",
                    at: starts[line] ..< min(end + 1, text.utf16.count),
                    in: display
                )
            default: Self.type("x", at: end ..< end, in: display)
            }
            Self.moveCaret(to: Int.random(in: 0 ... display.controller.text.utf16.count, using: &random), in: display)
            let fresh = Self.givenDisplay(display.controller.text)
            fresh.controller.selection = display.controller.selection
            fresh.rebuild()
            guard Self.attributes(display) == Self.attributes(fresh) else {
                Issue.record("step \(step): \(display.controller.text.debugDescription)")
                return
            }
        }
    }

    @Test
    func `an image result in the editor redraws its line without a full parse`() {
        let display = Self.givenDisplay("intro\n![Map](https://e.com/a.png)\nafter")
        Self.type("x", at: 0 ..< 0, in: display)

        display.controller.setImageResult(.remoteNotLoaded(host: "e.com"), for: "https://e.com/a.png")
        display.refreshImages(destination: "https://e.com/a.png")

        let marks = display.storage.attribute(.markdownEditorImages, at: 7, effectiveRange: nil) as? [EditorImageMark]
        #expect(marks?.first?.content.button != nil)
        #expect(display.controller.cachedDocument == nil)
    }

    @Test
    func `newlines counts the line feeds before an index`() {
        let text = "a\nbé\n😀\nc"
        let index = text.utf16.index(text.utf16.startIndex, offsetBy: 8)

        #expect(MarkdownDisplay.newlines(in: text, before: index) == 3)
        #expect(MarkdownDisplay.newlines(in: text, before: text.utf16.index(text.utf16.startIndex, offsetBy: 7)) == 2)
        #expect(MarkdownDisplay.newlines(in: text, before: text.startIndex) == 0)
    }

    @Test
    func `newlines counts a bridged string the same way`() {
        let text = NSString(string: "a\nbé\n😀\nc") as String
        let index = text.utf16.index(text.utf16.startIndex, offsetBy: 8)

        #expect(text.utf8.withContiguousStorageIfAvailable { _ in true } == nil)
        #expect(MarkdownDisplay.newlines(in: text, before: index) == 3)
    }
}
