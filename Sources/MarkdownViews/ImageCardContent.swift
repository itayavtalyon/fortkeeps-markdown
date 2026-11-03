import CoreGraphics
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
    /// The line under a kept image after a failed reload.
    let statusLine: String?
    static let statusLineHeight: CGFloat = 18
    /// A card has at most one line under its title.
    func cardSize(columnWidth: CGFloat) -> CGSize {
        CGSize(width: min(columnWidth, 420), height: 56)
    }

    /// A card with a button sends `activateImage(_:)` on a click.
    var activates: Bool {
        button != nil
    }

    /// No result yet draws the loading card. `.refused` with the `.link`
    /// fallback draws the link.
    init(result: ImageResult?, alt: String, fallback: MarkdownPresentation.ImageFallback) {
        let name = alt.isEmpty ? Strings.noAlt : alt
        var title = name
        var lines: [String] = []
        var button: String?
        var label: String?
        var hint: String?
        kind = Self.kind(of: result, fallback: fallback)
        var statusLine: String?
        switch result {
        case let .image(_, reloadFailure)?:
            statusLine = reloadFailure.map(Strings.reloadFailed)
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
            hint = Strings.loadHintLocal
        case let .failed(reason)?:
            title = Strings.cannotShow
            lines = [Strings.reason(reason)]
            button = [.timedOut, .network].contains(reason) ? Strings.retry : nil
            label = Strings.cardLabel(reason: lines.first, alt: alt)
        case let .refused(reason)?:
            if kind == .link {
                title = alt.isEmpty ? Strings.noAlt : Strings.imageLink(alt)
            } else {
                title = Strings.cannotShow
                lines = reason.map { [$0] } ?? []
                label = Strings.cardLabel(reason: reason, alt: alt)
            }
        }
        self.title = title
        self.lines = lines
        self.button = button
        self.statusLine = statusLine
        showsProgress = result == nil || result == .loading
        accessibilityLabel = label ?? ([title] + lines).joined(separator: ", ")
        accessibilityHint = hint
        isAccessibilityElement = kind == .card || kind == .link || !alt.isEmpty
    }

    private static func kind(of result: ImageResult?, fallback: MarkdownPresentation.ImageFallback) -> Kind {
        switch (result, fallback) {
        case let (.image(data, _)?, _): .image(data)
        case (.refused?, .link): .link
        default: .card
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
        String(localized: "img.refused.title", defaultValue: "Image can't be shown", bundle: resourceBundle)
    }

    static var retry: String {
        #if os(macOS)
            String(localized: "img.retry", defaultValue: "Try Again", bundle: resourceBundle)
        #else
            String(localized: "img.retry", defaultValue: "Try again", bundle: resourceBundle)
        #endif
    }

    static func reloadFailed(_ failure: ImageFailure) -> String {
        String(
            localized: "img.reloadFailed",
            defaultValue: "Couldn't reload this image. \(reason(failure))",
            bundle: resourceBundle
        )
    }

    static var loadHintLocal: String {
        String(
            localized: "img.load.hint.local",
            defaultValue: "Shows the image from this file.",
            bundle: resourceBundle
        )
    }

    /// `Image can't be shown. {reason}`, then ` Alt text: {alt}` when there is alt text.
    static func cardLabel(reason: String?, alt: String) -> String {
        let card = String(
            localized: "img.ax.card",
            defaultValue: "\(cannotShow). \(reason ?? "")",
            bundle: resourceBundle
        )
        let altText = String(localized: "img.ax.card.alt", defaultValue: " Alt text: \(alt)", bundle: resourceBundle)
        return card.trimmingCharacters(in: .whitespaces) + (alt.isEmpty ? "" : altText)
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
            String(localized: "img.reason.tooLarge", defaultValue: "It's too large to show.", bundle: resourceBundle)
        case .timedOut:
            String(localized: "img.reason.timedOut", defaultValue: "It took too long to load.", bundle: resourceBundle)
        case .unsupported:
            String(
                localized: "img.reason.unsupported",
                defaultValue: "This image format isn't supported.",
                bundle: resourceBundle
            )
        case .network:
            String(
                localized: "img.reason.network",
                defaultValue: "Couldn't reach it. Check your connection.",
                bundle: resourceBundle
            )
        }
    }
}
