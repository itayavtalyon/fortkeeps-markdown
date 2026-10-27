import Foundation
import MarkdownCore

/// What the view draws for one image: the image, a card for each other
/// `ImageResult`, or the `Image: {alt}` link (design log 001 › Images).
struct ImageCardContent: Equatable {
    enum Kind: Equatable {
        case image(Data)
        case card
        case link
    }

    let kind: Kind
    let title: String
    let detail: String?
    let button: String?
    let showsProgress: Bool
    /// The failure reason, shown as a tooltip and read as the hint.
    let help: String?
    let accessibilityLabel: String
    /// An image with an empty alt is hidden from VoiceOver.
    let isAccessibilityElement: Bool
    /// Clicking the card asks the host again.
    var asksAgain: Bool {
        button != nil
    }

    /// No result yet draws the loading card. `.refused` with the `.link`
    /// fallback draws the `Image: {alt}` link.
    init(result: ImageResult?, alt: String, fallback: MarkdownPresentation.ImageFallback) {
        let name = alt.isEmpty ? Strings.noAlt : alt
        var detail: String?
        var button: String?
        var help: String?
        var label = name
        kind = switch (result, fallback) {
        case let (.image(data)?, _): .image(data)
        case (.refused?, .link): .link
        default: .card
        }
        switch result {
        case .image?:
            break
        case .needsAccess?:
            detail = Strings.needsAccess
            button = Strings.allowAccess
        case let .remoteNotLoaded(host)?:
            detail = Strings.remote(host)
            button = Strings.load
            label = Strings.remoteLabel(name, host)
        case .loading?, nil:
            detail = Strings.loading
        case let .failed(reason)?:
            detail = Strings.failed
            button = Strings.retry
            help = Strings.reason(reason)
        case .refused?:
            detail = fallback == .link ? nil : Strings.refused
        }
        self.detail = detail
        self.button = button
        self.help = help
        showsProgress = result == nil || result == .loading
        title = kind == .link ? Strings.imageLink(name) : name
        accessibilityLabel = kind == .link ? title : label
        isAccessibilityElement = if case .image = kind {
            !alt.isEmpty
        } else {
            true
        }
    }
}

/// The image strings (DRAFT until Story Weaver finalizes them, WAIT-3).
enum Strings {
    static var noAlt: String {
        String(localized: "img.noalt", defaultValue: "Image", bundle: resourceBundle)
    }

    static var needsAccess: String {
        String(localized: "access.ph", defaultValue: "Needs folder access", bundle: resourceBundle)
    }

    static var allowAccess: String {
        #if os(macOS)
            String(localized: "access.button", defaultValue: "Allow Access…", bundle: resourceBundle)
        #else
            String(localized: "access.button", defaultValue: "Allow access", bundle: resourceBundle)
        #endif
    }

    static func remote(_ host: String) -> String {
        String(localized: "img.remote.sub", defaultValue: "Remote image · \(host)", bundle: resourceBundle)
    }

    static func remoteLabel(_ alt: String, _ host: String) -> String {
        String(
            localized: "img.ax.placeholder",
            defaultValue: "\(alt), remote image from \(host), not loaded",
            bundle: resourceBundle
        )
    }

    static var load: String {
        #if os(macOS)
            String(localized: "img.load", defaultValue: "Load Image", bundle: resourceBundle)
        #else
            String(localized: "img.load", defaultValue: "Load image", bundle: resourceBundle)
        #endif
    }

    static var loading: String {
        String(localized: "img.loading", defaultValue: "Loading…", bundle: resourceBundle)
    }

    static var failed: String {
        String(localized: "img.failed", defaultValue: "Couldn’t load this image.", bundle: resourceBundle)
    }

    static var retry: String {
        #if os(macOS)
            String(localized: "img.retry", defaultValue: "Try Again", bundle: resourceBundle)
        #else
            String(localized: "img.retry", defaultValue: "Try again", bundle: resourceBundle)
        #endif
    }

    static var refused: String {
        String(localized: "img.refused", defaultValue: "This image can’t be shown.", bundle: resourceBundle)
    }

    static var play: String {
        String(localized: "img.play", defaultValue: "Play animation", bundle: resourceBundle)
    }

    static func imageLink(_ alt: String) -> String {
        String(localized: "img.link", defaultValue: "Image: \(alt)", bundle: resourceBundle)
    }

    static func reason(_ reason: ImageFailure) -> String {
        switch reason {
        case .tooLarge: String(localized: "img.reason.tooLarge", defaultValue: "Too large", bundle: resourceBundle)
        case .timedOut: String(localized: "img.reason.timedOut", defaultValue: "Timed out", bundle: resourceBundle)
        case .unsupported:
            String(localized: "img.reason.unsupported", defaultValue: "Unsupported format", bundle: resourceBundle)
        case .network: String(localized: "img.reason.network", defaultValue: "Network error", bundle: resourceBundle)
        }
    }
}
