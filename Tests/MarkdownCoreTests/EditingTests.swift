import MarkdownCore
import Testing

/// Design › Editor (list continuation, byte limit) and Undo (groups).
struct EditingTests {
    static func pressReturn(_ text: String, at caret: Int) -> String? {
        ListContinuation.returnEdit(in: text, selection: caret ..< caret).map { edit in
            var units = Array(text.utf16)
            units.replaceSubrange(edit.range, with: Array(edit.replacement.utf16))
            return String(decoding: units, as: UTF16.self)
        }
    }

    // MARK: list continuation

    @Test
    func `Return in a task item continues with an unchecked task`() {
        #expect(Self.pressReturn("- [x] a", at: 7) == "- [x] a\n- [ ] ")
    }

    @Test(arguments: [
        ("- a", "- a\n- "),
        ("* a", "* a\n* "),
        ("+ a", "+ a\n+ "),
        ("9. a", "9. a\n10. "),
        ("3) a", "3) a\n4) ")
    ])
    func `Return in a list item continues the list with the same marker`(line: String, result: String) {
        #expect(Self.pressReturn(line, at: line.utf16.count) == result)
    }

    @Test
    func `Return keeps the quote prefix and the indentation`() {
        #expect(Self.pressReturn("> x\n>   - a", at: 11) == "> x\n>   - a\n>   - ")
    }

    @Test
    func `Return in the middle of an item moves the rest to the new item`() {
        #expect(Self.pressReturn("- ab", at: 3) == "- a\n- b")
    }

    @Test
    func `Return puts the caret after the new marker`() {
        #expect(ListContinuation.returnEdit(in: "- a", selection: 3 ..< 3)?.selection == 6 ..< 6)
    }

    @Test(arguments: [("- a\n- ", 6, "- a\n"), ("- [ ] ", 6, ""), ("> 1. ", 5, "> ")])
    func `Return on an empty item ends the list`(text: String, caret: Int, result: String) {
        #expect(Self.pressReturn(text, at: caret) == result)
    }

    @Test(arguments: [("plain", 5), ("- a", 1), ("# h", 3)])
    func `Return outside a list item content is a plain newline`(text: String, caret: Int) {
        #expect(ListContinuation.returnEdit(in: text, selection: caret ..< caret) == nil)
    }

    @Test
    func `Return replaces a selection inside the item`() {
        #expect(ListContinuation.returnEdit(in: "- abc", selection: 3 ..< 4)
            == TextEdit(range: 3 ..< 4, replacement: "\n- ", selection: 6 ..< 6))
    }

    // MARK: undo groups

    /// Applies each typed string and returns the text after one undo.
    static func textAfterOneUndo(_ typing: [(String, Double)]) -> String {
        var grouping = UndoGrouping()
        var groups: [String] = []
        for (text, time) in typing {
            if grouping.register(.typed(text), at: time) == .continueGroup, !groups.isEmpty {
                groups[groups.count - 1] += text
            } else {
                groups.append(text)
            }
        }
        return groups.dropLast().joined()
    }

    @Test
    func `hello world typed with a 1 s pause then one undo removes world only`() {
        let first: [(String, Double)] = Array("hello ").enumerated().map { (String($1), Double($0) / 10) }
        let second: [(String, Double)] = Array("world").enumerated().map { (String($1), 1.6 + Double($0) / 10) }
        let typing = first + second

        #expect(Self.textAfterOneUndo(typing) == "hello ")
    }

    @Test
    func `a pause inside a word does not end the group`() {
        #expect(Self.textAfterOneUndo([("he", 0), ("llo", 2)]).isEmpty)
    }

    @Test
    func `whitespace without a pause does not end the group`() {
        #expect(Self.textAfterOneUndo([("hello", 0), (" ", 0.2), ("world", 0.4)]).isEmpty)
    }

    @Test(arguments: [
        UndoGrouping.Event.paste, .listContinuation, .formatCommand, .checkbox, .replaceAll, .resolveApply,
        .compositionCommitted, .returnKey
    ])
    func `an edit of its own kind is one undo group and ends the typing run`(event: UndoGrouping.Event) {
        var grouping = UndoGrouping()
        _ = grouping.register(.typed("a"), at: 0)

        #expect(grouping.register(event, at: 0.1) == .ownGroup)
        #expect(grouping.register(.typed("b"), at: 0.2) == .newGroup)
    }

    @Test
    func `a caret jump ends the typing run`() {
        var grouping = UndoGrouping()
        _ = grouping.register(.typed("a"), at: 0)

        #expect(grouping.register(.caretJump, at: 0.1) == .closeGroup)
        #expect(grouping.register(.typed("b"), at: 0.2) == .newGroup)
    }

    // MARK: byte limit

    @Test
    func `an insertion that fits is kept whole`() {
        #expect(ByteLimit.fitting("abc", replacing: 0 ..< 0, in: "xy", limit: 5) == "abc")
        #expect(ByteLimit.fitting("abc", replacing: 0 ..< 0, in: "xy", limit: nil) == "abc")
    }

    @Test
    func `a 70 KB paste into 60 KB with a 65,536 limit keeps the longest whole-grapheme prefix`() {
        let text = String(repeating: "a", count: 60000)
        let paste = String(repeating: "x👍🏽🇮🇱é", count: 70000 / 16)

        let kept = ByteLimit.fitting(paste, replacing: 60000 ..< 60000, in: text, limit: 65536)

        #expect(text.utf8.count + kept.utf8.count <= 65536)
        #expect(text.utf8.count + kept.utf8.count > 65536 - 8)
        #expect(paste.hasPrefix(kept))
        #expect(kept == String(paste.prefix(kept.count)))
    }

    @Test
    func `a replaced range frees its bytes for the insertion`() {
        #expect(ByteLimit.fitting("abcd", replacing: 0 ..< 2, in: "xyz", limit: 5) == "abcd")
    }

    @Test
    func `a text already at the limit takes nothing`() {
        #expect(ByteLimit.fitting("a", replacing: 3 ..< 3, in: "xyz", limit: 3).isEmpty)
        #expect(ByteLimit.fitting("a", replacing: 3 ..< 3, in: "xyzw", limit: 3).isEmpty)
    }

    @Test
    func `the cut never splits a grapheme`() {
        #expect(ByteLimit.fitting("a👍🏽", replacing: 0 ..< 0, in: "", limit: 6) == "a")
    }
}
