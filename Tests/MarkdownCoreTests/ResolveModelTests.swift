import MarkdownCore
import Testing

/// Screens §3.11 and design log 004 › Outside changes: the compare view's
/// state, for Fortkeeps Scroll and Fortkeeps.
struct ResolveModelTests {
    static let mine = "# Trip\n\nDay one\nmine\n\nend\nkeep\nmine 2\n"
    static let theirs = "# Trip\n\nDay one\ntheirs\n\nend\nkeep\ntheirs 2\n"

    @Test
    func `the rows are the unchanged runs and the changes, in order`() {
        let model = ResolveModel(mine: Self.mine, theirs: Self.theirs)

        #expect(model.rows == [
            .unchanged("# Trip\n\nDay one", lines: 3),
            .change(0),
            .unchanged("\nend\nkeep", lines: 3),
            .change(1),
            .unchanged("", lines: 1)
        ])
        #expect(model.changeCount == 2)
        #expect(model.mine(0) == "mine")
        #expect(model.theirs(1) == "theirs 2")
    }

    @Test
    func `apply waits for every change, then gives the merged text`() {
        var model = ResolveModel(mine: Self.mine, theirs: Self.theirs)
        #expect(model.resolvedCount == 0)
        #expect(model.merged == nil)

        model.choose(.theirs)
        #expect(model.choice(0) == .theirs)
        #expect(model.current == 1)
        #expect(model.merged == nil)
        model.choose(.both)

        #expect(model.resolvedCount == 2)
        #expect(model.merged == "# Trip\n\nDay one\ntheirs\n\nend\nkeep\nmine 2\ntheirs 2\n")
    }

    @Test
    func `a choice for another change keeps the current one, and a new choice replaces the old`() {
        var model = ResolveModel(mine: Self.mine, theirs: Self.theirs)

        model.choose(.mine, change: 1)
        model.choose(.both, change: 1)

        #expect(model.current == 0)
        #expect(model.choice(1) == .both)
        #expect(model.resolvedCount == 1)
    }

    @Test
    func `the current change moves by key, stops at the ends, and stays after the last choice`() {
        var model = ResolveModel(mine: Self.mine, theirs: Self.theirs)

        model.move(-1)
        #expect(model.current == 0)
        model.move(1)
        model.move(1)
        #expect(model.current == 1)
        model.choose(.mine)
        #expect(model.current == 1)
    }

    @Test
    func `the same two texts have nothing to resolve`() {
        var model = ResolveModel(mine: "a\n", theirs: "a\n")

        model.move(1)

        #expect(model.rows == [.unchanged("a\n", lines: 2)])
        #expect(model.current == 0)
        #expect(model.merged == "a\n")
    }

    @Test
    func `a change at the start or the end has no empty run beside it`() {
        let model = ResolveModel(mine: "mine\nkeep\nmine 2", theirs: "theirs\nkeep\ntheirs 2")

        #expect(model.rows == [.change(0), .unchanged("keep", lines: 1), .change(1)])
    }

    @Test
    func `a choice for the current change, named, moves on`() {
        var model = ResolveModel(mine: Self.mine, theirs: Self.theirs)

        model.choose(.mine, change: 0)

        #expect(model.current == 1)
    }

    @Test
    func `undo takes back the last choice and its move`() {
        var model = ResolveModel(mine: Self.mine, theirs: Self.theirs)
        #expect(!model.canUndoChoice)
        model.undoChoice()
        #expect(model.current == 0)

        model.choose(.mine)
        model.choose(.theirs, change: 0)

        model.undoChoice()
        #expect(model.choice(0) == .mine)
        #expect(model.current == 1)
        model.undoChoice()
        #expect(model.choice(0) == nil)
        #expect(model.current == 0)
        #expect(!model.canUndoChoice)
    }
}
