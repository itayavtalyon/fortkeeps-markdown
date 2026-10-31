import Foundation

/// The open and save rules of design log 001 › Files.
public enum DocumentFile {
    public enum Refusal: Error, Equatable {
        /// Not valid UTF-8, or a NUL byte.
        case notUTF8
    }

    public enum SaveAction: Equatable {
        /// The document stays as it is: clean after a reload.
        case stayClean
        /// The document is dirty; the system schedules the save.
        case autosave
        /// The document saves now, with any pending edits.
        case saveNow
    }

    /// What a change does to the document (design log 001 › Files).
    public static func saveAction(for change: TextChange) -> SaveAction {
        switch change.reason {
        case .reload: .stayClean
        case .checkbox: .saveNow
        case .edit, .undo, .redo: change.groupReason == .checkbox ? .saveNow : .autosave
        }
    }

    /// The accepted file extensions, compared without case.
    public static let acceptedExtensions: Set = ["md", "markdown", "txt", "mdown", "mkd"]

    /// The extension test, without case.
    public static func accepts(_ url: URL) -> Bool {
        acceptedExtensions.contains(url.pathExtension.lowercased())
    }

    /// The buffer of a file's bytes: its text, normalized.
    public static func text(from data: Data) throws(Refusal) -> String {
        guard !data.contains(0), let text = String(validating: data, as: UTF8.self) else { throw .notUTF8 }
        return normalized(text)
    }

    /// The bytes every save writes: the text, normalized.
    public static func data(for text: String) -> Data {
        Data(normalized(text).utf8)
    }

    /// CRLF and a lone CR become LF, and a text with a character after its
    /// BOM ends with a newline. An empty text stays empty.
    public static func normalized(_ text: String) -> String {
        let carriageReturn = UInt8(ascii: "\r"), lineFeed = UInt8(ascii: "\n")
        let bomLength = text.hasPrefix(MarkdownDocument.bom) ? MarkdownDocument.bom.utf8.count : 0
        return String(unsafeUninitializedCapacity: text.utf8.count + 1) { buffer in
            var count = 0
            var afterCarriageReturn = false
            for byte in text.utf8 {
                if byte == lineFeed, afterCarriageReturn {
                    afterCarriageReturn = false
                    continue
                }
                afterCarriageReturn = byte == carriageReturn
                buffer[count] = afterCarriageReturn ? lineFeed : byte
                count += 1
            }
            if count > bomLength, buffer[count - 1] != lineFeed {
                buffer[count] = lineFeed
                count += 1
            }
            return count
        }
    }
}
