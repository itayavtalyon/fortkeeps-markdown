/// A saveable reading position (design log 001 › Modes). Every value is a
/// UTF-8 byte offset in the source, excluding a leading BOM.
public struct MarkdownAnchor: Codable, Equatable, Sendable {
    /// Where the first visible top-level block starts.
    public var block: Int
    /// The first visible offset, counted from `block`.
    public var offsetInBlock: Int
    public var selection: Range<Int>

    public init(block: Int, offsetInBlock: Int, selection: Range<Int>) {
        self.block = block
        self.offsetInBlock = offsetInBlock
        self.selection = selection
    }

    public static let documentStart = MarkdownAnchor(block: 0, offsetInBlock: 0, selection: 0 ..< 0)
}
