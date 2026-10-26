/// The base direction of a block (design log 001 › Direction).
public enum TextDirection: String, Codable, Sendable {
    case ltr
    case rtl
    /// No strong letter in the block or in its parents.
    case auto

    /// An edge of the LTR chrome.
    public enum Edge: Sendable {
        case leading
        case trailing
    }

    /// Where the bullet, the checkbox, and the quote bar sit.
    public var markerEdge: Edge {
        self == .rtl ? .trailing : .leading
    }

    /// The direction of the first strong letter: Hebrew and Arabic give RTL,
    /// any other letter gives LTR. Nil when the text has no letter.
    static func firstStrong(in text: some StringProtocol) -> TextDirection? {
        for scalar in text.unicodeScalars {
            if rtlRanges.contains(where: { $0.contains(scalar.value) }) {
                return .rtl
            }
            if letterCategories.contains(scalar.properties.generalCategory) {
                return .ltr
            }
        }
        return nil
    }

    private static let rtlRanges: [ClosedRange<UInt32>] = [0x0590 ... 0x08FF, 0xFB1D ... 0xFDFF, 0xFE70 ... 0xFEFF]
    private static let letterCategories: Set<Unicode.GeneralCategory> = [
        .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter
    ]
}
