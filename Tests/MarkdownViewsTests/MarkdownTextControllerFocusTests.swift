import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design › Accessibility: the focusable elements and the keys each answers,
/// driven through the controller with a recording host.
@MainActor
struct MarkdownTextControllerFocusTests {
    static func givenController(
        _ text: String,
        fallback: MarkdownPresentation.ImageFallback = .text
    ) -> (MarkdownTextController, RecordingHost) {
        var presentation = MarkdownPresentation()
        presentation.imageFallback = fallback
        let host = RecordingHost()
        let controller = MarkdownTextController(
            text: text,
            features: MarkdownFeatures(),
            presentation: presentation,
            mode: .rendered,
            maxUTF8Bytes: nil,
            documentURL: nil
        )
        controller.host = host
        return (controller, host)
    }

    @Test
    func `space does not open a link and return does not toggle a checkbox`() {
        let (controller, host) = Self.givenController("[a](https://a.com)\n\n- [ ] task\n")
        let targets = controller.focusTargets()

        #expect(!controller.activate(targets[0], key: .space))
        #expect(!controller.activate(targets[1], key: .returnKey))
        #expect(host.opened.isEmpty)
        #expect(controller.text == "[a](https://a.com)\n\n- [ ] task\n")
    }

    @Test
    func `return on a refused image with the link fallback opens its destination`() {
        let (controller, host) = Self.givenController("![m](x.png)\n", fallback: .link)
        controller.setImageResult(.refused, for: "x.png")

        #expect(controller.activate(controller.focusTargets()[0], key: .returnKey))
        #expect(host.opened.map(\.destination) == ["x.png"])
        #expect(host.activated.isEmpty)
    }

    @Test
    func `a card without a button does nothing`() {
        let (controller, host) = Self.givenController("![m](x.png)\n")
        controller.setImageResult(.loading, for: "x.png")

        #expect(!controller.activate(controller.focusTargets()[0], key: .returnKey))
        #expect(host.activated.isEmpty)
    }

    @Test
    func `a table's rows are one box`() {
        let (controller, _) = Self.givenController("| h |\n| - |\n| a |\n| b |\n")

        #expect(controller.focusTargets().count == 1)
    }
}
