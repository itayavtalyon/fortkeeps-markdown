import MarkdownCore
import Testing

/// Design › Editor: the style tokens of one line.
struct MarkdownStylerTests {
    static func spans(
        _ line: String,
        caret: Int? = nil,
        entering state: MarkdownStyler.LineState = .init(),
        features: MarkdownFeatures = MarkdownFeatures()
    ) -> [String] {
        let styled = MarkdownStyler(features: features).styleLine(line, entering: state, caret: caret)
        let utf16 = Array(line.utf16)
        return styled.spans.map { span in
            "\(span.token):" + String(decoding: utf16[span.range], as: UTF16.self)
        }
    }

    @Test
    func `a plain paragraph has no syntax token`() {
        #expect(Self.spans("just some words").isEmpty)
    }

    @Test
    func `a heading dims its hashes and styles its text by level`() {
        #expect(Self.spans("## Title") == ["syntax:## ", "heading(level: 2):Title"])
    }

    @Test
    func `strong dims each double asterisk`() {
        #expect(Self.spans("a **b** c") == ["syntax:**", "strong:b", "syntax:**"])
    }

    @Test
    func `emphasis dims each asterisk and each underscore`() {
        #expect(Self.spans("*a* _b_") == ["syntax:*", "emphasis:a", "syntax:*", "syntax:_", "emphasis:b", "syntax:_"])
    }

    @Test
    func `a code span dims its backticks`() {
        #expect(Self.spans("x `y` z") == ["syntax:`", "code:y", "syntax:`"])
    }

    @Test
    func `a quote dims its marker and styles its text`() {
        #expect(Self.spans("> said") == ["syntax:> ", "quote:said"])
    }

    @Test(arguments: ["- ", "* ", "+ ", "1. ", "12) "])
    func `a list marker is dimmed`(marker: String) {
        #expect(Self.spans(marker + "item") == ["syntax:" + marker])
    }

    @Test
    func `a link dims its brackets and destination and styles its text`() {
        #expect(Self.spans("see [site](https://e.com) now") == ["syntax:[", "link:site", "syntax:](https://e.com)"])
    }

    @Test
    func `an image dims its source around the alt text`() {
        #expect(Self.spans("![alt](i.png)") == ["syntax:![", "syntax:](i.png)"])
    }

    @Test
    func `a bare URL is a link with no syntax`() {
        #expect(Self.spans("go https://e.com/x now") == ["link:https://e.com/x"])
    }

    @Test
    func `an angle-bracket autolink dims its brackets`() {
        #expect(Self.spans("<https://e.com>") == ["syntax:<", "link:https://e.com", "syntax:>"])
    }

    @Test
    func `a table row dims its pipes`() {
        #expect(Self.spans("| a | b |") == ["syntax:|", "syntax:|", "syntax:|"])
    }

    @Test
    func `a table delimiter row is dimmed`() {
        #expect(Self.spans("|---|:-:|") == ["syntax:|---|:-:|"])
    }

    @Test
    func `pipes are text when tables are off`() {
        var features = MarkdownFeatures()
        features.tables = false

        #expect(Self.spans("| a |", features: features).isEmpty)
    }

    @Test
    func `strikethrough dims its tildes when strikethrough is on`() {
        #expect(Self.spans("~~old~~") == ["syntax:~~", "strikethrough:old", "syntax:~~"])
    }

    @Test
    func `tildes are text when strikethrough is off`() {
        #expect(Self.spans("~~old~~", features: .fortkeeps).isEmpty)
    }

    @Test
    func `a code fence line is dimmed and opens a fence`() {
        let styled = MarkdownStyler(features: MarkdownFeatures()).styleLine("```swift", entering: .init(), caret: nil)

        #expect(styled.spans.map(\.token) == [.syntax])
        #expect(styled.exiting.isInFence)
    }

    @Test
    func `a line inside a fence is code and a closing fence is dimmed`() {
        let styler = MarkdownStyler(features: MarkdownFeatures())
        let open = styler.styleLine("~~~", entering: .init(), caret: nil).exiting

        let inside = styler.styleLine("let *x* = 1", entering: open, caret: nil)
        let close = styler.styleLine("~~~", entering: inside.exiting, caret: nil)

        #expect(inside.spans.map(\.token) == [.code])
        #expect(close.spans.map(\.token) == [.syntax])
        #expect(!close.exiting.isInFence)
    }

    @Test
    func `a shorter fence does not close a longer one`() {
        let styler = MarkdownStyler(features: MarkdownFeatures())
        let open = styler.styleLine("````", entering: .init(), caret: nil).exiting

        #expect(styler.styleLine("```", entering: open, caret: nil).exiting.isInFence)
    }

    @Test
    func `a task marker is a checkbox while the caret is outside it`() {
        #expect(Self.spans("- [x] done", caret: 10) == ["syntax:- ", "checkbox(checked: true):[x]"])
        #expect(Self.spans("- [ ] todo") == ["syntax:- ", "checkbox(checked: false):[ ]"])
    }

    @Test
    func `the caret inside a task marker shows the raw marker`() {
        #expect(Self.spans("- [x] done", caret: 3) == ["syntax:- ", "syntax:[x]"])
    }

    @Test
    func `a task marker is text when task lists are off`() {
        var features = MarkdownFeatures()
        features.taskLists = false

        #expect(Self.spans("- [x] done", features: features) == ["syntax:- "])
    }

    @Test
    func `nested quote and list prefixes are all dimmed`() {
        #expect(Self.spans("> - [ ] **t**") == [
            "syntax:> ", "syntax:- ", "checkbox(checked: false):[ ]", "quote:**t**", "syntax:**", "strong:t",
            "syntax:**"
        ])
    }

    @Test
    func `positions are UTF-16 offsets in the line`() {
        #expect(Self.spans("שלום **עולם** 👍🏽 `x`") == [
            "syntax:**",
            "strong:עולם",
            "syntax:**",
            "syntax:`",
            "code:x",
            "syntax:`"
        ])
    }

    @Test
    func `an empty link text dims the whole link`() {
        #expect(Self.spans("[](https://e.com)") == ["syntax:[", "syntax:](https://e.com)"])
    }

    @Test
    func `a padded code span styles its padding as code`() {
        #expect(Self.spans("`` `a` ``") == ["syntax:``", "code: `a` ", "syntax:``"])
    }

    @Test
    func `indented block markers are still recognized`() {
        #expect(Self.spans("  > q") == ["syntax:> ", "quote:q"])
        #expect(Self.spans("   # h") == ["syntax:# ", "heading(level: 1):h"])
    }

    @Test
    func `a backtick in a fence's info string makes the line text`() {
        #expect(!MarkdownStyler(features: MarkdownFeatures()).styleLine("``` a`b", entering: .init(), caret: nil)
            .exiting.isInFence)
    }

    @Test
    func `a delimiter row ignores trailing blanks`() {
        #expect(Self.spans("|---|  ") == ["syntax:|---|"])
    }

    @Test
    func `styleText passes the caret to its line`() {
        let lines = MarkdownStyler(features: MarkdownFeatures()).styleText("a\n- [ ] b", caret: 4)

        #expect(lines[1].spans.map(\.token) == [.syntax, .syntax])
    }

    @Test(arguments: ["~~~", "``` x"])
    func `a line that is not a matching closing fence stays code`(line: String) {
        let styler = MarkdownStyler(features: MarkdownFeatures())
        let open = styler.styleLine("```", entering: .init(), caret: nil).exiting

        #expect(styler.styleLine(line, entering: open, caret: nil).spans.map(\.token) == [.code])
    }

    @Test
    func `an uppercase X marks a checked task`() {
        #expect(Self.spans("- [X] a") == ["syntax:- ", "checkbox(checked: true):[X]"])
    }

    @Test(arguments: ["####### x", "#x", "---", "a | b"])
    func `a line that only looks like block syntax has no span`(line: String) {
        #expect(Self.spans(line).isEmpty)
    }

    @Test
    func `an escaped pipe in a table row is text`() {
        #expect(Self.spans(#"| a \| b |"#) == ["syntax:|", "syntax:|"])
    }

    @Test
    func `a hash after a list marker is not a heading`() {
        #expect(Self.spans("- # x") == ["syntax:- "])
    }

    // MARK: neighborhood

    @Test
    func `the neighborhood is the caret line and the line on each side`() {
        let text = "one\ntwo\nthree\nfour\nfive"

        #expect(MarkdownStyler.neighborhood(of: 9, in: text) == 4 ..< 18)
    }

    @Test
    func `an offset just after a line feed is on the next line`() {
        let text = "one\ntwo\nthree\nfour\nfive"

        #expect(MarkdownStyler.neighborhood(of: 4, in: text) == 0 ..< 13)
        #expect(MarkdownStyler.neighborhood(of: 3, in: text) == 0 ..< 7)
    }

    @Test
    func `the neighborhood counts UTF-16 units and stops past the end`() {
        #expect(MarkdownStyler.neighborhood(of: 3, in: "😀\nb\nc\nd") == 0 ..< 6)
        #expect(MarkdownStyler.neighborhood(of: 99, in: "a\nb\n") == 2 ..< 4)
        #expect(MarkdownStyler.neighborhood(of: 0, in: "") == 0 ..< 0)
    }

    @Test
    func `the neighborhood stops at the text edges`() {
        #expect(MarkdownStyler.neighborhood(of: 0, in: "a\nb\nc") == 0 ..< 3)
        #expect(MarkdownStyler.neighborhood(of: 5, in: "a\nb\nc") == 2 ..< 5)
    }

    @Test
    func `styleText styles each line with the fence state of the lines before it`() {
        let lines = MarkdownStyler(features: MarkdownFeatures()).styleText("```\n*a*\n```\n*b*", caret: nil)

        #expect(lines.map(\.range) == [0 ..< 3, 4 ..< 7, 8 ..< 11, 12 ..< 15])
        #expect(lines.map { $0.spans.map(\.token) } == [[.syntax], [.code], [.syntax], [.syntax, .emphasis, .syntax]])
    }

    @Test
    func `styleText starts from the state it enters`() {
        let styler = MarkdownStyler(features: MarkdownFeatures())
        let open = styler.styleLine("```", entering: .init(), caret: nil).exiting

        let lines = styler.styleText("*a*\n```", entering: open, caret: nil)

        #expect(lines.map { $0.spans.map(\.token) } == [[.code], [.syntax]])
        #expect(lines.last?.exiting.isInFence == false)
    }
}
