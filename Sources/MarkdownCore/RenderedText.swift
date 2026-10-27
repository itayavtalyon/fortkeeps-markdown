/// The characters that `.rendered` mode draws, with a map to the source
/// (design log 001 › Rendering). Rendered positions are UTF-16 offsets into
/// `string`. Source positions are UTF-8 byte offsets, excluding a leading BOM.
public struct RenderedText: Sendable {
    public enum BlockKind: Equatable, Sendable {
        case paragraph
        case heading(level: Int)
        case codeBlock
        case htmlBlock
        case thematicBreak
        case tableRow(isHeader: Bool)
    }

    /// What the view draws before the first block of a list item.
    public enum ListMarker: Equatable, Sendable {
        case bullet
        case ordered(Int)
    }

    /// One line-level block. Blocks are separated by one `\n` in `string`.
    public struct Block: Equatable, Sendable {
        public let kind: BlockKind
        public let range: Range<Int>
        public let sourceRange: Range<Int>
        public let quoteDepth: Int
        public let listDepth: Int
        /// The marker when this block opens a list item.
        public let listMarker: ListMarker?
        /// What copy writes before the block: the list indentation, the
        /// marker, and a task's box.
        let copyPrefix: String
        /// The index in `MarkdownDocument.tasks` when this block opens a task item.
        public let taskIndex: Int?
        public let direction: TextDirection
    }

    public struct Link: Equatable, Sendable {
        public let range: Range<Int>
        public let destination: String
        public let sourceRange: Range<Int>
    }

    /// An image is one U+FFFC in `string`.
    public struct Image: Equatable, Sendable {
        public let offset: Int
        public let destination: String
        public let alt: String
        public let sourceRange: Range<Int>
    }

    /// A stretch where rendered and source characters advance together.
    /// A verbatim run holds the same characters on both sides. Any other run
    /// is one rendered character drawn from source bytes that differ (an
    /// entity, a soft break, an image); those bytes are hidden syntax.
    struct Run: Sendable {
        let rendered: Int
        let renderedLength: Int
        let source: Int
        let sourceLength: Int
        /// The characters of a verbatim run; nil for any other run.
        let text: Substring?

        var renderedEnd: Int {
            rendered + renderedLength
        }

        var sourceEnd: Int {
            source + sourceLength
        }
    }

    public let string: String
    public let utf16Count: Int
    public let blocks: [Block]
    public let links: [Link]
    public let images: [Image]
    /// Inline styles: strong, emphasis, code, link, and strikethrough. An outer
    /// span comes before the spans inside it.
    public let spans: [MarkdownStyler.StyleSpan]
    let runs: [Run]
    /// Indices into `runs`, ordered by source offset.
    private let runsBySource: [Int]

    init(
        string: String,
        blocks: [Block],
        links: [Link],
        images: [Image],
        spans: [MarkdownStyler.StyleSpan],
        runs: [Run]
    ) {
        self.string = string
        utf16Count = string.utf16.count
        self.blocks = blocks
        self.links = links
        self.images = images
        self.spans = spans
        self.runs = runs
        runsBySource = runs.indices.sorted { (runs[$0].source, $0) < (runs[$1].source, $1) }
    }

    public enum Affinity: Sendable {
        /// The start of the character at the position.
        case forward
        /// The end of the character before the position.
        case backward
    }

    /// The source offset of a rendered caret position.
    public func sourceOffset(atRendered offset: Int, affinity: Affinity = .forward) -> Int {
        switch affinity {
        case .forward:
            guard let run = runContaining(rendered: offset) else {
                return runs.first { $0.rendered >= offset }?.source ?? (runs.last?.sourceEnd ?? 0)
            }
            return sourceStart(of: run, at: offset)
        case .backward:
            guard offset > 0, let run = runContaining(rendered: offset - 1) else {
                return runs.last { $0.renderedEnd <= offset }?.sourceEnd ?? 0
            }
            return sourceEnd(of: run, at: offset - 1)
        }
    }

    /// The rendered caret position of a source offset. An offset on hidden
    /// syntax snaps to the nearest content character; a tie snaps forward.
    public func renderedOffset(atSource offset: Int) -> Int {
        if let run = runContaining(source: offset) {
            guard let text = run.text else {
                return offset - run.source < run.sourceEnd - offset ? run.rendered : run.renderedEnd
            }
            return scalar(of: run, text) { $0.sourceRange.contains(offset) }.renderedRange.lowerBound
        }
        let upper = sourcePosition { $0.source > offset }
        let before = upper > 0 ? runs[runsBySource[upper - 1]] : nil
        let atOrAfter = sourcePosition { $0.source >= offset }
        let after = atOrAfter < runsBySource.count ? runs[runsBySource[atOrAfter]] : nil
        switch (before, after) {
        case let (before?, after?):
            return offset - before.sourceEnd < after.source - offset ? before.renderedEnd : after.rendered
        case let (before?, nil): return before.renderedEnd
        case let (nil, after?): return after.rendered
        case (nil, nil): return 0
        }
    }

    /// True when the offset starts a source character that the view draws as itself.
    public func isVisible(sourceOffset offset: Int) -> Bool {
        guard let run = runContaining(source: offset), let text = run.text else { return false }
        return walk(text, from: run).contains { $0.sourceRange.lowerBound == offset }
    }

    /// The characters the view drew for a rendered range: no syntax, no
    /// direction marks, and one `\n` between blocks. A drawn image adds
    /// nothing; an image in `imagesDrawnAsText` (indices into `images`)
    /// copies `Image: {alt}`. With `listMarkers`, a block whose start is in
    /// the range copies its list indentation, its marker, and a task's box.
    public func copyText(_ range: Range<Int>, imagesDrawnAsText: Set<Int> = [], listMarkers: Bool = true) -> String {
        let utf16 = Array(string.utf16)
        let pieces = blocks.compactMap { block -> String? in
            let start = max(block.range.lowerBound, range.lowerBound)
            let end = min(block.range.upperBound, range.upperBound)
            let startsInRange = range.contains(block.range.lowerBound)
            let prefix = listMarkers && startsInRange ? block.copyPrefix : ""
            guard start < end else {
                // An empty task item still copies its marker and box.
                return startsInRange && !prefix.isEmpty ? String(prefix.reversed().drop { $0 == " " }.reversed()) : nil
            }
            var piece = prefix
            var unit = start
            while unit < end {
                if utf16[unit] == 0xFFFC, let index = images.firstIndex(where: { $0.offset == unit }) {
                    let alt = images[index].alt
                    piece += imagesDrawnAsText.contains(index) ? (alt.isEmpty ? "Image" : "Image: " + alt) : ""
                    unit += 1
                    continue
                }
                let next = (unit + 1 ..< end).first { utf16[$0] == 0xFFFC } ?? end
                piece += String(decoding: utf16[unit ..< next], as: UTF16.self)
                unit = next
            }
            return piece.isEmpty ? nil : piece
        }
        return pieces.joined(separator: "\n")
    }

    // MARK: runs

    private func runContaining(rendered offset: Int) -> Run? {
        var low = 0
        var high = runs.count
        while low < high {
            let mid = (low + high) / 2
            if runs[mid].renderedEnd <= offset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low < runs.count && runs[low].rendered <= offset ? runs[low] : nil
    }

    /// Runs do not overlap in the source, so only zero-length runs can sit
    /// between an offset and the run that holds it.
    private func runContaining(source offset: Int) -> Run? {
        var position = sourcePosition { $0.source > offset } - 1
        while position >= 0 {
            let run = runs[runsBySource[position]]
            if offset < run.sourceEnd {
                return run
            }
            if run.sourceLength > 0 {
                return nil
            }
            position -= 1
        }
        return nil
    }

    /// The first position in `runsBySource` whose run satisfies a predicate
    /// that is false and then true in source order.
    private func sourcePosition(where predicate: (Run) -> Bool) -> Int {
        var low = 0
        var high = runsBySource.count
        while low < high {
            let mid = (low + high) / 2
            if predicate(runs[runsBySource[mid]]) {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low
    }

    private func sourceStart(of run: Run, at rendered: Int) -> Int {
        guard let text = run.text else { return run.source }
        return scalar(of: run, text) { $0.renderedRange.contains(rendered) }.sourceRange.lowerBound
    }

    private func sourceEnd(of run: Run, at rendered: Int) -> Int {
        guard let text = run.text else { return run.sourceEnd }
        return scalar(of: run, text) { $0.renderedRange.contains(rendered) }.sourceRange.upperBound
    }

    private typealias ScalarRanges = (renderedRange: Range<Int>, sourceRange: Range<Int>)

    /// The scalar of a verbatim run that satisfies `holds`. Callers pass an
    /// offset that the run contains, so the scalar exists.
    private func scalar(of run: Run, _ text: Substring, where holds: (ScalarRanges) -> Bool) -> ScalarRanges {
        walk(text, from: run).first(where: holds)! // swiftlint:disable:this force_unwrapping
    }

    /// The rendered and source ranges of each scalar of a verbatim run.
    private func walk(_ text: Substring, from run: Run) -> [ScalarRanges] {
        var rendered = run.rendered
        var source = run.source
        return text.unicodeScalars.map { scalar in
            let ranges = (rendered ..< rendered + scalar.utf16.count, source ..< source + scalar.utf8.count)
            rendered += scalar.utf16.count
            source += scalar.utf8.count
            return ranges
        }
    }
}
