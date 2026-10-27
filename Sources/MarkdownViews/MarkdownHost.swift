import CoreGraphics
import Foundation

/// The app or Fortkeeps (design log 001 › Host interface). Every method is
/// required; the protocol has no default implementations.
@MainActor
public protocol MarkdownHost: AnyObject, Sendable {
    /// The view needs an image near the viewport. Called on any thread; the
    /// view cancels the task when it discards the block.
    nonisolated func image(for request: ImageRequest) async -> ImageResult
    /// The person follows a link.
    func open(_ link: LinkActivation)
    /// After the view applies a change.
    func textDidChange(_ change: TextChange)
}

public struct ImageRequest: Equatable, Sendable {
    public let destination: String
    public let documentURL: URL?
    public let maxPixelSize: CGSize
}

public enum ImageFailure: Equatable, Sendable {
    case tooLarge
    case timedOut
    case unsupported
    case network
}

/// What the host returns for an image; the view draws the matching card.
public enum ImageResult: Equatable, Sendable {
    case image(Data)
    case needsAccess
    case remoteNotLoaded(host: String)
    /// The host calls `refreshImage(destination:)` when the result changes.
    case loading
    case failed(reason: ImageFailure)
    case refused
}

public struct LinkModifiers: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = LinkModifiers(rawValue: 1 << 0)
    public static let option = LinkModifiers(rawValue: 1 << 1)
    public static let shift = LinkModifiers(rawValue: 1 << 2)
    public static let control = LinkModifiers(rawValue: 1 << 3)
}

public struct LinkActivation: Equatable, Sendable {
    public enum Source: Sendable {
        case markdown
        case html
    }

    public let destination: String
    public let resolvedURL: URL?
    public let documentURL: URL?
    public let modifiers: LinkModifiers
    public let source: Source
}

public struct TextChange: Equatable, Sendable {
    public enum Reason: Sendable {
        /// Typing, paste, a format command, list continuation, Replace All, Resolve Apply.
        case edit
        case checkbox
        case undo
        case redo
        case reload
    }

    public let reason: Reason
    /// The UTF-16 range before the change.
    public let range: NSRange
    public let replacement: String
    /// The full text after the change.
    public let text: String
}

public enum MarkdownMode: Sendable {
    /// The rendered text; no syntax shows; not editable.
    case rendered
    /// The source, styled as typed.
    case editor
    /// The source, styled, not editable.
    case editorLocked
}
