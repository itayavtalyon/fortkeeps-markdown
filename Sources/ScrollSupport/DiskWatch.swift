import Foundation
import MarkdownCore

/// Another app's bytes on disk, as an open document sees them (design log
/// 004 › Outside changes, Round 7). Both apps' documents keep one.
struct DiskWatch {
    enum Change: Equatable {
        /// Text that differs from the document's.
        case text(String)
        /// Bytes that are not UTF-8 text, or that hold a NUL.
        case unreadable
    }

    /// The bytes last read or written; other bytes on disk are another app's.
    var data = Data()

    /// What new bytes on disk mean for a document with `text`, or nil when
    /// they change nothing: the same text, such as another app's CRLF rewrite.
    mutating func change(to newData: Data, text: String) -> Change? {
        data = newData
        guard let disk = try? DocumentFile.text(from: newData) else { return .unreadable }
        return disk == text ? nil : .text(disk)
    }

    /// A move into a Trash is a deletion; any other move is a rename.
    static func isTrash(_ url: URL) -> Bool {
        url.pathComponents.contains(".Trash")
    }
}
