/// The Resolve comparison: a line diff of two texts (design log 001 ›
/// Outside changes).
public struct LineDiff: Sendable {
    /// A changed region, in line indices of each text.
    public struct Hunk: Equatable, Sendable {
        public let mine: Range<Int>
        public let theirs: Range<Int>

        public init(mine: Range<Int>, theirs: Range<Int>) {
            self.mine = mine
            self.theirs = theirs
        }
    }

    public enum Choice: Sendable {
        case mine
        case theirs
        /// Mine, then theirs.
        case both
    }

    let mineLines: [Substring]
    let theirsLines: [Substring]
    public let hunks: [Hunk]

    public init(mine: String, theirs: String) {
        mineLines = mine.split(separator: "\n", omittingEmptySubsequences: false)
        theirsLines = theirs.split(separator: "\n", omittingEmptySubsequences: false)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in theirsLines.difference(from: mineLines) {
            switch change {
            case let .remove(offset, _, _): removed.insert(offset)
            case let .insert(offset, _, _): inserted.insert(offset)
            }
        }
        var hunks: [Hunk] = []
        var mineIndex = 0
        var theirsIndex = 0
        while mineIndex < mineLines.count || theirsIndex < theirsLines.count {
            guard removed.contains(mineIndex) || inserted.contains(theirsIndex) else {
                mineIndex += 1
                theirsIndex += 1
                continue
            }
            let start = (mineIndex, theirsIndex)
            while removed.contains(mineIndex) || inserted.contains(theirsIndex) {
                if removed.contains(mineIndex) {
                    mineIndex += 1
                }
                if inserted.contains(theirsIndex) {
                    theirsIndex += 1
                }
            }
            hunks.append(Hunk(mine: start.0 ..< mineIndex, theirs: start.1 ..< theirsIndex))
        }
        self.hunks = hunks
    }

    /// The merged text, with one choice per hunk.
    public func merged(_ choices: [Choice]) -> String {
        precondition(choices.count == hunks.count)
        var lines: [Substring] = []
        var mineIndex = 0
        for (hunk, choice) in zip(hunks, choices) {
            lines += mineLines[mineIndex ..< hunk.mine.lowerBound]
            switch choice {
            case .mine: lines += mineLines[hunk.mine]
            case .theirs: lines += theirsLines[hunk.theirs]
            case .both: lines += mineLines[hunk.mine] + theirsLines[hunk.theirs]
            }
            mineIndex = hunk.mine.upperBound
        }
        lines += mineLines[mineIndex...]
        return lines.joined(separator: "\n")
    }
}
