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
    /// display: the theme makes a new dynamic color object on every call.
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
