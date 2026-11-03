/// The compare view's state (screens §3.11, design log 004 › Outside
/// changes): the unchanged runs and the changes of a `LineDiff`, a choice per
/// change, and the change the keys act on. Fortkeeps Scroll and Fortkeeps
/// both host it.
public struct ResolveModel: Sendable {
    public enum Row: Equatable, Sendable {
        /// Lines both texts share, joined, and how many there are.
        case unchanged(String, lines: Int)
        /// A change, by its index.
        case change(Int)
    }

    public let diff: LineDiff
    public let rows: [Row]
    private var choices: [LineDiff.Choice?]
    /// The change the keys act on.
    public private(set) var current = 0
    /// Each choice's change, the choice it replaced, and the current change before it, for ⌘Z.
    private var history: [Step] = []

    private struct Step {
        let change: Int
        let choice: LineDiff.Choice?
        let current: Int
    }

    public init(mine: String, theirs: String) {
        diff = LineDiff(mine: mine, theirs: theirs)
        var rows: [Row] = []
        var line = 0
        for (index, hunk) in diff.hunks.enumerated() {
            if hunk.mine.lowerBound > line {
                rows.append(Self.unchanged(diff.mineLines[line ..< hunk.mine.lowerBound]))
            }
            rows.append(.change(index))
            line = hunk.mine.upperBound
        }
        if line < diff.mineLines.count {
            rows.append(Self.unchanged(diff.mineLines[line...]))
        }
        self.rows = rows
        choices = Array(repeating: nil, count: diff.hunks.count)
    }

    private static func unchanged(_ lines: ArraySlice<Substring>) -> Row {
        .unchanged(lines.joined(separator: "\n"), lines: lines.count)
    }

    public var changeCount: Int {
        choices.count
    }

    public var resolvedCount: Int {
        choices.count { $0 != nil }
    }

    public func choice(_ change: Int) -> LineDiff.Choice? {
        choices[change]
    }

    public func mine(_ change: Int) -> String {
        diff.mineLines[diff.hunks[change].mine].joined(separator: "\n")
    }

    public func theirs(_ change: Int) -> String {
        diff.theirsLines[diff.hunks[change].theirs].joined(separator: "\n")
    }

    /// The merged text once every change has a choice; Apply waits for it.
    public var merged: String? {
        let chosen = choices.compactMap(\.self)
        return chosen.count == choices.count ? diff.merged(chosen) : nil
    }

    /// A choice for a change, the current one by default. A choice for the
    /// current change moves on to the next change, if there is one.
    public mutating func choose(_ choice: LineDiff.Choice, change: Int? = nil) {
        history.append(Step(change: change ?? current, choice: choices[change ?? current], current: current))
        choices[change ?? current] = choice
        if change == nil || change == current {
            move(1)
        }
    }

    public var canUndoChoice: Bool {
        !history.isEmpty
    }

    /// ⌘Z: takes back the last choice and its move. False when there is none.
    @discardableResult
    public mutating func undoChoice() -> Bool {
        guard let last = history.popLast() else { return false }
        choices[last.change] = last.choice
        current = last.current
        return true
    }

    /// Option-Down and Option-Up: the next or the previous change.
    public mutating func move(_ offset: Int) {
        current = max(0, min(current + offset, changeCount - 1))
    }
}
