import Foundation
import MarkdownCore

/// What the view draws for one image: the image, a card of the Image cards
/// table, or the `.link` fallback link (design log 001 › Image cards).
struct ImageCardContent: Equatable {
    enum Kind: Equatable {
        case image(Data)
        case card
        case link
    }

    let kind: Kind
    let title: String
    /// The lines under the title.
    let lines: [String]
    let button: String?
    let showsProgress: Bool
    let accessibilityLabel: String
    let accessibilityHint: String?
    /// An image with an empty alt is hidden from VoiceOver.
    let isAccessibilityElement: Bool
    /// A card with a button sends `imageActivated(_:)` on a click.
    var activates: Bool {
        button != nil
    }

    /// No result yet draws the loading card. `.refused` with the `.link`
    /// fallback draws the link. `isUntitled` gives a refused card its hint.
    init(result: ImageResult?, alt: String, fallback: MarkdownPresentation.ImageFallback, isUntitled: Bool = false) {
        let name = alt.isEmpty ? Strings.noAlt : alt
        // The failed and refused cards leave out an empty alt.
        let altLine = alt.isEmpty ? [String]() : [alt]
        var title = name
        var lines: [String] = []
        var button: String?
        var label: String?
        var hint: String?
        kind = switch (result, fallback) {
        case let (.image(data)?, _): .image(data)
        case (.refused?, .link): .link
        default: .card
        }
        switch result {
        case .image?:
            break
        case .loading?, nil:
            lines = [Strings.loading]
        case let .remoteNotLoaded(host)?:
            lines = [Strings.remote(host)]
            button = Strings.load
            label = Strings.remoteLabel(name, host)
            hint = Strings.loadHint(host)
        case .needsAccess?:
            lines = [Strings.needsAccess]
            button = Strings.allowAccess
        case let .failed(reason)?:
            title = Strings.cannotShow
            lines = altLine + [Strings.reason(reason)]
            button = [.timedOut, .network].contains(reason) ? Strings.retry : nil
            label = title + ", " + Strings.reason(reason)
        case .refused?:
            title = kind == .link ? (alt.isEmpty ? Strings.noAlt : Strings.imageLink(alt)) : Strings.cannotShow
            lines = kind == .link ? [] : altLine
            label = ([title] + lines).joined(separator: ", ")
            hint = kind == .card && isUntitled ? Strings.saveToShow : nil
        }
        self.title = title
        self.lines = lines
        self.button = button
        showsProgress = result == nil || result == .loading
        accessibilityLabel = label ?? ([title] + lines.prefix(1)).joined(separator: ", ")
        accessibilityHint = hint
        isAccessibilityElement = if case .image = kind {
            !alt.isEmpty
        } else {
            true
        }
    }
}

/// The image strings (design log 001 › Image cards). The remote, loading,
/// and folder-access strings are DRAFT until Story Weaver finalizes them (WAIT-3).
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

    static func loadHint(_ host: String) -> String {
        String(localized: "img.load.hint", defaultValue: "Loads the image from \(host).", bundle: resourceBundle)
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

    static var cannotShow: String {
        String(localized: "img.cannotShow", defaultValue: "Image can’t be shown", bundle: resourceBundle)
    }

    static var retry: String {
        #if os(macOS)
            String(localized: "img.retry", defaultValue: "Try Again", bundle: resourceBundle)
        #else
            String(localized: "img.retry", defaultValue: "Try again", bundle: resourceBundle)
        #endif
    }

    static var saveToShow: String {
        String(
            localized: "img.untitled.hint",
            defaultValue: "Save the file to show local images.",
            bundle: resourceBundle
        )
    }

    static var play: String {
        String(localized: "img.play", defaultValue: "Play animation", bundle: resourceBundle)
    }

    static func imageLink(_ alt: String) -> String {
        String(localized: "img.link", defaultValue: "Image: \(alt)", bundle: resourceBundle)
    }

    static func reason(_ reason: ImageFailure) -> String {
        switch reason {
        case .tooLarge:
            String(localized: "img.reason.tooLarge", defaultValue: "It’s too large to show.", bundle: resourceBundle)
        case .timedOut:
            String(localized: "img.reason.timedOut", defaultValue: "It took too long to load.", bundle: resourceBundle)
        case .unsupported:
            String(
                localized: "img.reason.unsupported",
                defaultValue: "This image format isn’t supported.",
                bundle: resourceBundle
            )
        case .network:
            String(
                localized: "img.reason.network",
                defaultValue: "Couldn’t reach it. Check your connection.",
                bundle: resourceBundle
            )
        }
    }
}
