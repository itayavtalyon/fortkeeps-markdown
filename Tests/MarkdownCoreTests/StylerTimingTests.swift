import Foundation
import MarkdownCore
import Testing

/// Design › Editor: the 95th percentile of neighborhood restyles on a 64 KiB
/// text is at most 8 ms in a release build on Apple silicon. `just timing`
/// runs it; the default test run skips it.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FORTKEEPS_TIMING"] == "1"))
struct StylerTimingTests {
    static let block = """
    ## Section *with* emphasis

    Some **bold** text, a [link](https://example.com/page), `code`, and ~~old~~ words.
    > A quote with a [ref](https://e.com) and more text to make it longer.
    - [ ] a task with **strong** text
    - [x] a done task
    1. ordered item with `code`

    | a | b |
    |---|---|
    | c | d |

    ```swift
    let value = compute(*x*, y)
    ```

    """

    @Test
    func `a neighborhood restyle of a 64 KiB text meets the 8 ms budget at the 95th percentile`() {
        let text = String(repeating: Self.block, count: 65536 / Self.block.utf8.count)
        let styler = MarkdownStyler(features: MarkdownFeatures())
        let lines = styler.styleText(text, caret: nil)
        let clock = ContinuousClock()
        let units = Array(text.utf16)
        var durations: [Duration] = []
        for caret in stride(from: 0, to: text.utf16.count, by: 61) {
            let neighborhood = MarkdownStyler.neighborhood(of: caret, in: text)
            let first = lines.firstIndex { $0.range.upperBound >= neighborhood.lowerBound } ?? 0
            durations.append(clock.measure {
                var state = first > 0 ? lines[first - 1].exiting : MarkdownStyler.LineState()
                let region = String(decoding: units[neighborhood], as: UTF16.self)
                for line in region.split(separator: "\n", omittingEmptySubsequences: false) {
                    state = styler.styleLine(String(line), entering: state, caret: nil).exiting
                }
            })
        }
        let p95 = durations.sorted()[durations.count * 95 / 100]
        print("timing: \(text.utf8.count) bytes, \(durations.count) restyles, p95 \(p95), chip \(Self.chip)")

        #expect(p95 <= .milliseconds(8))
    }

    static var chip: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var name = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &name, &size, nil, 0)
        return String(bytes: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? "unknown"
    }
}
