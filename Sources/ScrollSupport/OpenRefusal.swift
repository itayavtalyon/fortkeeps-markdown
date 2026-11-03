import Foundation

/// Why the app does not open a file (design log 001 › Files).
public enum OpenRefusal: Error, Equatable {
    /// Not one of the accepted extensions.
    case wrongExtension
    /// Not valid UTF-8, or a NUL byte.
    case notUTF8

    /// The body of the refusal alert.
    var message: String {
        switch self {
        case .wrongExtension: ScrollStrings.wrongExtension
        case .notUTF8: ScrollStrings.notUTF8
        }
    }
}
