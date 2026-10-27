import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design › Images, Accessibility, Color: the card for each `ImageResult`,
/// and the Increase Contrast colors.
struct ImageCardContentTests {
    typealias Fallback = MarkdownPresentation.ImageFallback

    static func card(_ result: ImageResult?, alt: String = "Map", fallback: Fallback = .text) -> ImageCardContent {
        ImageCardContent(result: result, alt: alt, fallback: fallback)
    }

    @Test
    func `an image result draws the image with its alt as the label`() {
        let card = Self.card(.image(Data([1])))

        #expect(card.kind == .image(Data([1])))
        #expect(card.accessibilityLabel == "Map")
        #expect(card.isAccessibilityElement)
    }

    @Test
    func `an image with an empty alt is hidden from VoiceOver`() {
        #expect(!Self.card(.image(Data([1])), alt: "").isAccessibilityElement)
        #expect(Self.card(.loading, alt: "").isAccessibilityElement)
    }

    @Test
    func `a remote image that is not loaded draws the remote card with Load Image`() {
        let card = Self.card(.remoteNotLoaded(host: "e.com"))

        #expect(card.kind == .card)
        #expect(card.detail == "Remote image · e.com")
        #expect(card.button == "Load Image")
        #expect(card.accessibilityLabel == "Map, remote image from e.com, not loaded")
        #expect(card.asksAgain)
    }

    @Test(arguments: [nil, ImageResult.loading])
    func `no result yet and loading draw the loading card`(result: ImageResult?) {
        let card = Self.card(result)

        #expect(card.detail == "Loading…")
        #expect(card.showsProgress)
        #expect(!card.asksAgain)
    }

    @Test
    func `a failed image draws Try Again with the reason`() {
        let card = Self.card(.failed(reason: .tooLarge))

        #expect(card.detail == "Couldn’t load this image.")
        #expect(card.button == "Try Again")
        #expect(card.help == "Too large")
    }

    @Test
    func `the folder-access placeholder asks again`() {
        let card = Self.card(.needsAccess)

        #expect(card.detail == "Needs folder access")
        #expect(card.asksAgain)
    }

    @Test
    func `a refused image draws the can't-be-shown card with no button`() {
        let card = Self.card(.refused)

        #expect(card.kind == .card)
        #expect(card.detail == "This image can’t be shown.")
        #expect(card.button == nil)
        #expect(card.title == "Map")
    }

    @Test
    func `a refused image with the link fallback draws the Image alt link`() {
        let card = Self.card(.refused, fallback: .link)

        #expect(card.kind == .link)
        #expect(card.title == "Image: Map")
    }

    @Test
    func `an empty alt is named Image`() {
        #expect(Self.card(.loading, alt: "").title == "Image")
    }

    // MARK: color

    @Test
    @MainActor
    func `increase Contrast maps text3 to text2 and line2 to text3`() {
        #expect(MarkdownTheme.token(.text3, increaseContrast: true) == DesignColors.text2)
        #expect(MarkdownTheme.token(.line2, increaseContrast: true) == DesignColors.text3)
        #expect(MarkdownTheme.token(.text3, increaseContrast: false) == DesignColors.text3)
        #expect(MarkdownTheme.token(.line2, increaseContrast: false) == DesignColors.line2)
        #expect(MarkdownTheme.token(.accent, increaseContrast: true) == DesignColors.accent)
    }
}
