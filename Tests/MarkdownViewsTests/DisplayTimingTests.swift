import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Design › Editor: a neighborhood restyle through the display, with the
/// neighborhood lookup, the line count, and the attribute writes inside the
/// clock, meets the 8 ms budget at the 95th percentile on a 64 KiB text.
/// `just timing` runs it; the default test run skips it.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FORTKEEPS_TIMING"] == "1"))
struct DisplayTimingTests {
    /// Headings, inline styles, a task, a table, and a fence, as in `StylerTimingTests`.
    static let block = "## Section *with* emphasis\n\nSome **bold** text and a [link](https://e.com/p).\n" +
        "- [ ] a task with `code`\n\n| a | b |\n|---|---|\n| c | d |\n\n```swift\nlet v = f(*x*)\n```\n\n"

    @Test
    func `a display restyle of a 64 KiB text meets the 8 ms budget at the 95th percentile`() {
        let text = String(repeating: Self.block, count: 65536 / Self.block.utf8.count)
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
        let clock = ContinuousClock()
        let units = text.utf16.count
        let durations = (0 ..< 200).map { step in
            let caret = units / 200 * step
            controller.selection = caret ..< caret
            return clock.measure { display.restyle(around: caret) }
        }
        let p95 = durations.sorted()[durations.count * 95 / 100]
        print("timing: display restyle, \(text.utf8.count) bytes, p95 \(p95)")

        #expect(p95 <= .milliseconds(8))
    }
}
