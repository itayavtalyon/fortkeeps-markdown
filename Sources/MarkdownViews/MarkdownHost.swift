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
    /// The person clicked an image card that has a button, or pressed Return
    /// or Space on it: consent to fetch that image (design log 002 › Host
    /// interface). The host returns `.loading` from `image(for:)` and calls
    /// `refreshImage(destination:)` when the result changes; the view does
    /// not ask `image(for:)` for an activation.
    func activateImage(_ activation: ImageActivation)
    /// The person chose Reload Image on a drawn image: fetch a fresh copy
    /// with the same rules. The host calls `refreshImage(destination:)` with
    /// the new result, or with `.image(_, reloadFailure:)` when it failed.
    func reloadImage(_ request: ImageRequest)
    /// The person chose Load All Images in This Document: consent to fetch
    /// every remote image of this document, this time only.
    func loadAllImages()
}

public struct ImageRequest: Equatable, Sendable {
    public let destination: String
    public let documentURL: URL?
    public let maxPixelSize: CGSize

    public init(destination: String, documentURL: URL?, maxPixelSize: CGSize) {
        self.destination = destination
        self.documentURL = documentURL
        self.maxPixelSize = maxPixelSize
    }
}

/// The card the person activated: `.remoteNotLoaded`, `.failed`, or `.needsAccess`.
public struct ImageActivation: Equatable, Sendable {
    public let destination: String
    public let documentURL: URL?
    public let card: ImageResult

    public init(destination: String, documentURL: URL?, card: ImageResult) {
        self.destination = destination
        self.documentURL = documentURL
        self.card = card
    }
}

public enum ImageFailure: Equatable, Sendable {
    case tooLarge
    case timedOut
    case unsupported
    case network
}

/// What the host returns for an image; the view draws the matching card.
public enum ImageResult: Equatable, Sendable {
    /// The image. After a failed Reload Image, the old image with the reason
    /// the reload failed; the view draws a status line under it.
    case image(Data, reloadFailure: ImageFailure? = nil)
    case needsAccess
    case remoteNotLoaded(host: String)
    /// The host calls `refreshImage(destination:)` when the result changes.
    case loading
    case failed(reason: ImageFailure)
    /// Refused by the rules. The card shows the host's reason line, when
    /// there is one, under its title.
    case refused(reason: String?)
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

public enum MarkdownMode: Sendable {
    /// The rendered text; no syntax shows; not editable.
    case rendered
    /// The source, styled as typed.
    case editor
    /// The source, styled, not editable.
    case editorLocked
}
