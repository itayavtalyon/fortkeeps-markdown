import Foundation

/// The word count of the status bar (design log 001 › Files).
public enum WordCount {
    public static func count(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}

/// Command-+, Command-−, and Command-0 on Mac: 80% to 200% in 10% steps
/// (design log 001 › Windows and chrome).
public enum Zoom {
    public static let actualSize = 1.0
    static let range = 0.8 ... 2.0

    public static func zoomedIn(_ zoom: Double) -> Double {
        min(((zoom * 10).rounded() + 1) / 10, range.upperBound)
    }

    public static func zoomedOut(_ zoom: Double) -> Double {
        max(((zoom * 10).rounded() - 1) / 10, range.lowerBound)
    }
}

public extension MarkdownDocument {
    /// A relative image or a link to a sibling file: the app needs the
    /// folder (design log 001 › Windows and chrome, Folder access).
    func needsFolder(documentURL: URL?) -> Bool {
        rendered.images.contains {
            if case .local = ImageRules.classify($0.destination, documentURL: documentURL) {
                return true
            }
            return false
        } || rendered.links.contains {
            if case .siblingFile = LinkRules.classify($0.destination, documentURL: documentURL) {
                return true
            }
            return false
        }
    }
}
