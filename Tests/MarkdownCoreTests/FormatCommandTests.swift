import MarkdownCore
import Testing

/// Design › Format commands: the base behavior of each command (the WAIT-2
/// exact cases are not built).
struct FormatCommandTests {
    /// The text after the command, with `|` marking the selection or caret.
    static func run(_ command: FormatCommand, _ marked: String) -> String {
        let parts = marked.components(separatedBy: "|")
        let text = parts.joined()
        let start = parts[0].utf16.count
        let end = parts.count == 3 ? start + parts[1].utf16.count : start
        let edit = FormatCommands.apply(command, to: text, selection: start ..< end)
        var units = Array(text.utf16)
        units.replaceSubrange(edit.range, with: Array(edit.replacement.utf16))
        units.insert(contentsOf: Array("|".utf16), at: edit.selection.upperBound)
        if !edit.selection.isEmpty {
            units.insert(contentsOf: Array("|".utf16), at: edit.selection.lowerBound)
        }
        return String(decoding: units, as: UTF16.self)
    }

    @Test(arguments: [
        (FormatCommand.bold, "a |word| b", "a **|word|** b"),
        (.bold, "a **|word|** b", "a |word| b"),
        (.bold, "a |**word**| b", "a |word| b"),
        (.bold, "a |b", "a **|**b"),
        (.italic, "a |word| b", "a *|word|* b"),
        (.italic, "a *|word|* b", "a |word| b"),
        (.italic, "a **|word|** b", "a ***|word|*** b"),
        (.code, "a |word| b", "a `|word|` b"),
        (.code, "a `|word|` b", "a |word| b")
    ])
    func `a wrapping command adds its delimiters and a second run removes them`(command: FormatCommand, before: String, after: String) {
        #expect(Self.run(command, before) == after)
    }

    @Test
    func `bold applies to each selected line`() {
        #expect(Self.run(.bold, "|one\n\ntwo|") == "|**one**\n\n**two**|")
    }

    @Test
    func `code on two lines makes a fence`() {
        #expect(Self.run(.code, "x\n|a\nb|\ny") == "x\n|```\na\nb\n```|\ny")
    }

    @Test
    func `code on a fence removes it`() {
        #expect(Self.run(.code, "|```\na\nb\n```|") == "|a\nb|")
    }

    @Test(arguments: [
        (FormatCommand.quote, "|a\nb|", "|> a\n> b|"),
        (.quote, "|> a\n> b|", "|a\nb|"),
        (.checkbox, "|a\nb|", "|- [ ] a\n- [ ] b|"),
        (.checkbox, "|- [ ] a\n- [x] b|", "|a\nb|"),
        (.bulletedList, "|a\nb|", "|- a\n- b|"),
        (.bulletedList, "|- a\n- b|", "|a\nb|"),
        (.quote, "x\n|a", "x\n> |a"),
        (.bulletedList, "a|b", "- a|b")
    ])
    func `a line command adds its prefix to each line and a second run removes it`(command: FormatCommand, before: String, after: String) {
        #expect(Self.run(command, before) == after)
    }

    @Test
    func `a line command adds its prefix to every line when only some have it`() {
        #expect(Self.run(.quote, "|> a\nb|") == "|> > a\n> b|")
    }

    @Test(arguments: [
        (FormatCommand.heading(1), "Ti|tle", "# Ti|tle"),
        (.heading(2), "### Ti|tle", "## Ti|tle"),
        (.heading(2), "## Ti|tle", "Ti|tle"),
        (.heading(3), "|a\nb|", "|### a\n### b|"),
        (.body, "## Ti|tle", "Ti|tle"),
        (.body, "Ti|tle", "Ti|tle")
    ])
    func `a heading command replaces the hash run and toggles off at its own level`(command: FormatCommand, before: String, after: String) {
        #expect(Self.run(command, before) == after)
    }

    // MARK: link

    @Test
    func `link with a selection and a URL on the clipboard inserts the link`() {
        #expect(Self.run(.link(clipboard: "https://e.com/x"), "see |site| now") == "see [site](https://e.com/x)| now")
    }

    @Test(arguments: ["not a url", "http ://x", "ftp://e.com", " https://e.com and more", ""])
    func `link with a selection and no URL on the clipboard puts the caret in the destination`(clipboard: String) {
        #expect(Self.run(.link(clipboard: clipboard), "see |site| now") == "see [site](|) now")
    }

    @Test
    func `link with no selection puts the caret between the brackets`() {
        #expect(Self.run(.link(clipboard: "https://e.com"), "see | now") == "see [|]() now")
    }

    @Test
    func `the clipboard URL may have surrounding whitespace`() {
        #expect(Self.run(.link(clipboard: "  https://e.com/x\n"), "|a|") == "[a](https://e.com/x)|")
    }

    // MARK: active state

    @Test(arguments: [
        (FormatCommand.bold, "a **w|or|d** b", true), (.bold, "a w|or|d b", false), (.italic, "*|x|*", true),
        (.quote, "> a|", true), (.quote, "a|", false), (.heading(2), "## a|", true), (.heading(1), "## a|", false),
        (.bulletedList, "- a|", true), (.checkbox, "- [ ] a|", true), (.code, "`a|b`", true), (.body, "a|", true)
    ])
    func `a command is active when the selection has its format`(command: FormatCommand, marked: String, active: Bool) {
        let parts = marked.components(separatedBy: "|")
        let start = parts[0].utf16.count
        let end = parts.count == 3 ? start + parts[1].utf16.count : start

        #expect(FormatCommands.isActive(command, in: parts.joined(), selection: start ..< end) == active)
    }
}
