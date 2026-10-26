import MarkdownCore
import Testing

/// Design › Outside changes: the Resolve comparison.
struct LineDiffTests {
    static let mine = "a\nb\nc\nd\ne"
    static let theirs = "a\nB\nc\ne\nf"

    @Test
    func `the line diff gives the expected hunks`() {
        #expect(LineDiff(mine: Self.mine, theirs: Self.theirs).hunks == [
            LineDiff.Hunk(mine: 1 ..< 2, theirs: 1 ..< 2),
            LineDiff.Hunk(mine: 3 ..< 4, theirs: 3 ..< 3),
            LineDiff.Hunk(mine: 5 ..< 5, theirs: 4 ..< 5)
        ])
    }

    @Test
    func `applying every theirs choice gives the second text`() {
        let diff = LineDiff(mine: Self.mine, theirs: Self.theirs)

        #expect(diff.merged(Array(repeating: .theirs, count: diff.hunks.count)) == Self.theirs)
    }

    @Test
    func `applying every mine choice gives the first text`() {
        let diff = LineDiff(mine: Self.mine, theirs: Self.theirs)

        #expect(diff.merged(Array(repeating: .mine, count: diff.hunks.count)) == Self.mine)
    }

    @Test
    func `both keeps mine then theirs`() {
        let diff = LineDiff(mine: "x\nold\ny", theirs: "x\nnew\ny")

        #expect(diff.merged([.both]) == "x\nold\nnew\ny")
    }

    @Test
    func `equal texts have no hunks`() {
        #expect(LineDiff(mine: "a\nb", theirs: "a\nb").hunks.isEmpty)
    }

    @Test
    func `an empty text against another is one hunk`() {
        let diff = LineDiff(mine: "", theirs: "a\nb")

        #expect(diff.hunks == [LineDiff.Hunk(mine: 0 ..< 1, theirs: 0 ..< 2)])
        #expect(diff.merged([.theirs]) == "a\nb")
    }
}
