import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design › Image cards and Color: the card for each `ImageResult`, its
/// strings and accessibility label, and the Increase Contrast colors.
struct ImageCardContentTests {
    typealias Fallback = MarkdownPresentation.ImageFallback

    // Mac buttons use title case, iOS buttons sentence case.
    #if os(macOS)
        static let load = "Load Image"
        static let retry = "Try Again"
        static let allow = "Allow Access…"
    #else
        static let load = "Load image"
        static let retry = "Try again"
        static let allow = "Allow access"
    #endif

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
    func `a card is 56 points tall for one line and 18 more for each further line`() {
        #expect(Self.card(.loading).cardSize(columnWidth: 600) == CGSize(width: 420, height: 56))
        #expect(Self.card(.failed(reason: .tooLarge)).cardSize(columnWidth: 300) == CGSize(width: 300, height: 74))
    }

    @Test
    func `an image with an empty alt is hidden from VoiceOver`() {
        #expect(!Self.card(.image(Data([1])), alt: "").isAccessibilityElement)
        #expect(Self.card(.loading, alt: "").isAccessibilityElement)
    }

    @Test(arguments: [nil, ImageResult.loading])
    func `no result yet and loading draw the loading card`(result: ImageResult?) {
        let card = Self.card(result)

        #expect(card.title == "Map")
        #expect(card.lines == ["Loading…"])
        #expect(card.showsProgress)
        #expect(!card.activates)
        #expect(card.accessibilityLabel == "Map, Loading…")
    }

    @Test
    func `a remote image that is not loaded draws the remote card with its load button`() {
        let card = Self.card(.remoteNotLoaded(host: "e.com"))

        #expect(card.kind == .card)
        #expect(card.lines == ["Remote image · e.com"])
        #expect(card.button == Self.load)
        #expect(card.accessibilityLabel == "Map, remote image from e.com, not loaded")
        #expect(card.accessibilityHint == "Loads the image from e.com.")
        #expect(card.activates)
    }

    @Test
    func `the folder-access card activates`() {
        let card = Self.card(.needsAccess)

        #expect(card.lines == ["Needs folder access"])
        #expect(card.button == Self.allow)
        #expect(card.accessibilityLabel == "Map, Needs folder access")
    }

    @Test(arguments: [
        (ImageFailure.timedOut, "It took too long to load.", true),
        (.network, "Couldn’t reach it. Check your connection.", true),
        (.tooLarge, "It’s too large to show.", false),
        (.unsupported, "This image format isn’t supported.", false)
    ])
    func `a failed card reads the title, the alt, and the reason`(reason: ImageFailure, text: String, retries: Bool) {
        let card = Self.card(.failed(reason: reason))

        #expect(card.title == "Image can’t be shown")
        #expect(card.lines == ["Map", text])
        #expect(card.button == (retries ? Self.retry : nil))
        #expect(card.accessibilityLabel == "Image can’t be shown, " + text)
    }

    @Test
    func `a failed or refused card leaves out an empty alt`() {
        #expect(Self.card(.failed(reason: .tooLarge), alt: "").lines == ["It’s too large to show."])
        #expect(Self.card(.refused, alt: "").lines.isEmpty)
    }

    @Test
    func `a refused image draws the can't-be-shown card with no button`() {
        let card = Self.card(.refused)

        #expect(card.kind == .card)
        #expect(card.title == "Image can’t be shown")
        #expect(card.lines == ["Map"])
        #expect(card.button == nil)
        #expect(card.accessibilityLabel == "Image can’t be shown, Map")
        #expect(Self.card(.refused, alt: "").accessibilityLabel == "Image can’t be shown")
    }

    @Test
    func `a refused card in an untitled document asks to save`() {
        let card = ImageCardContent(result: .refused, alt: "Map", fallback: .text, isUntitled: true)

        #expect(card.accessibilityHint == "Save the file to show local images.")
        #expect(Self.card(.refused).accessibilityHint == nil)
    }

    @Test
    func `a refused image with the link fallback draws the Image alt link`() {
        let card = Self.card(.refused, fallback: .link)

        #expect(card.kind == .link)
        #expect(card.title == "Image: Map")
        #expect(Self.card(.refused, alt: "", fallback: .link).title == "Image")
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

    /// WCAG relative luminance of an sRGB color.
    static func luminance(_ color: SRGBColor) -> Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = 0.2126 * linear(color.red)
        let green = 0.7152 * linear(color.green)
        let blue = 0.0722 * linear(color.blue)
        return red + green + blue
    }

    static func contrast(_ first: SRGBColor, _ second: SRGBColor) -> Double {
        let (high, low) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (high + 0.05) / (low + 0.05)
    }

    @Test
    func `text3 on pane meets 4.5 to 1 in light and dark`() {
        #expect(Self.contrast(DesignColors.text3.light, DesignColors.pane.light) >= 4.5)
        #expect(Self.contrast(DesignColors.text3.dark, DesignColors.pane.dark) >= 4.5)
    }
}
