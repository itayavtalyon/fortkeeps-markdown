import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design › Modes, Copy, Images: mode switches, copy, and image requests,
/// driven through the controller with a recording host.
@MainActor
struct MarkdownTextControllerModeTests {
    // MARK: modes

    @Test
    func `a switch from editor to rendered to editor keeps the caret offset and undo restores the edit`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("# Title\n\nSome **bold** text\n")
        controller.textViewDidReplace(9 ..< 9, with: "X", event: .typed("X"), at: 0)
        controller.selection = 18 ..< 18

        controller.setMode(.rendered)
        let renderedSelection = controller.selection
        controller.setMode(.editor)

        #expect(renderedSelection == 13 ..< 13)
        #expect(controller.selection == 18 ..< 18)
        controller.undoManager.undo()
        #expect(controller.text == "# Title\n\nSome **bold** text\n")
    }

    @Test
    func `a switch keeps a selection on the same characters`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("a **bold** b")
        controller.selection = 4 ..< 8

        controller.setMode(.rendered)
        #expect(controller.selection == 2 ..< 6)
        controller.setMode(.editor)
        #expect(controller.selection == 4 ..< 8)
    }

    @Test
    func `a switch keeps the first visible block`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("one\n\ntwo\n\nthree\n")

        let rendered = controller.setMode(.rendered, firstVisibleOffset: 5)
        let editor = controller.setMode(.editor, firstVisibleOffset: rendered)

        #expect(rendered == 4)
        #expect(editor == 5)
    }

    @Test
    func `the display string is the source in the editor and the rendered text in rendered mode`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("# T\n\n**b**\n")

        #expect(controller.displayString == "# T\n\n**b**\n")
        controller.setMode(.rendered)
        #expect(controller.displayString == "T\nb")
    }

    @Test
    func `the editor spellchecks and rendered mode does not`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("a")

        #expect(controller.checksSpelling)
        controller.setMode(.rendered)
        #expect(!controller.checksSpelling)
    }

    // MARK: copy

    @Test
    func `copy in rendered mode separates blocks with one newline`() {
        let (controller, _) = MarkdownTextControllerTests.givenController(
            "# Head\n\npara\n\n- a\n- b\n",
            mode: .rendered
        )

        #expect(controller.copyText(0 ..< controller.displayString.utf16.count) == "Head\npara\n- a\n- b")
    }

    @Test(arguments: [MarkdownMode.editor, .editorLocked])
    func `copy in the editor takes the source characters`(mode: MarkdownMode) {
        let (controller, _) = MarkdownTextControllerTests.givenController("# Head\n\n**b**\n", mode: mode)

        #expect(controller.copyText(0 ..< 14) == "# Head\n\n**b**\n")
    }

    @Test
    func `a refused image copies Image alt only with the link fallback`() {
        var presentation = MarkdownPresentation()
        let text = "a ![m](x.png) b"
        let plain = MarkdownTextController(
            text: text,
            features: MarkdownFeatures(),
            presentation: presentation,
            mode: .rendered,
            maxUTF8Bytes: nil,
            documentURL: nil
        )
        presentation.imageFallback = .link
        let linked = MarkdownTextController(
            text: text,
            features: MarkdownFeatures(),
            presentation: presentation,
            mode: .rendered,
            maxUTF8Bytes: nil,
            documentURL: nil
        )
        plain.setImageResult(.refused, for: "x.png")
        linked.setImageResult(.refused, for: "x.png")

        #expect(plain.copyText(0 ..< 5) == "a  b")
        #expect(linked.copyText(0 ..< 5) == "a Image: m b")
    }

    @Test
    func `in rendered mode a checkbox belongs to the block it opens`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("- [ ] a\n- [ ] b\n\nc\n", mode: .rendered)

        #expect(controller.taskIndex(atDisplayOffset: 2) == 1)
        #expect(controller.taskIndex(atDisplayOffset: 4) == nil)
    }

    // MARK: images

    @Test
    func `an image one viewport below the visible range is requested`() async {
        let (controller, host) = MarkdownTextControllerTests.givenController("x\n\n![a](a.png)\n", mode: .rendered)

        controller.viewportChanged(0 ..< 1)
        await settle { !host.requested.isEmpty }

        #expect(host.requested == ["a.png"])
    }

    @Test
    func `an image near the viewport is requested and a discarded one is cancelled`() async {
        let text = "![a](https://e.com/a.png)\n\n" + String(repeating: "line\n\n", count: 400) + "![b](https://e.com/b.png)\n"
        let (controller, host) = MarkdownTextControllerTests.givenController(text, mode: .rendered)

        controller.viewportChanged(0 ..< 50)
        await settle { host.requested.contains("https://e.com/a.png") }
        let far = controller.displayString.utf16.count - 50
        controller.viewportChanged(far ..< far + 50)
        await settle { host.cancelled.contains("https://e.com/a.png") && host.requested.contains("https://e.com/b.png")
        }

        #expect(host.requested == ["https://e.com/a.png", "https://e.com/b.png"])
        #expect(host.cancelled == ["https://e.com/a.png"])
        await settle { controller.imageResult(for: 0) != nil }
        #expect(controller.imageResult(for: 0) == nil)
    }

    @Test
    func `a result is cached per destination and not requested again`() async {
        let (controller, host) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n",
            mode: .rendered
        )
        host.results["https://e.com/a.png"] = .remoteNotLoaded(host: "e.com")

        controller.viewportChanged(0 ..< 1)
        await settle { controller.imageResult(for: 0) != nil }
        controller.viewportChanged(0 ..< 1)
        await settle { false }

        #expect(controller.imageResult(for: 0) == .remoteNotLoaded(host: "e.com"))
        #expect(host.requested == ["https://e.com/a.png"])
    }

    @Test
    func `an activation tells the host once, draws loading, and does not ask for the image`() async {
        let (controller, host) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n",
            mode: .rendered
        )
        host.results["https://e.com/a.png"] = .remoteNotLoaded(host: "e.com")
        controller.viewportChanged(0 ..< 1)
        await settle { controller.imageResult(for: 0) != nil }

        controller.activateImage(destination: "https://e.com/a.png")
        await settle { false }

        #expect(host.activated == ["https://e.com/a.png"])
        #expect(host.requested == ["https://e.com/a.png"])
        #expect(controller.imageResult(for: 0) == .loading)
        controller.refreshImage(destination: "https://e.com/a.png")
        await settle { host.requested.count == 2 }
        #expect(host.requested.count == 2)
    }

    @Test
    func `refreshImage asks the host again`() async {
        let (controller, host) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n",
            mode: .rendered
        )
        host.results["https://e.com/a.png"] = .remoteNotLoaded(host: "e.com")
        controller.viewportChanged(0 ..< 1)
        await settle { controller.imageResult(for: 0) != nil }
        host.results["https://e.com/a.png"] = .image(Data([1]))

        controller.refreshImage(destination: "https://e.com/a.png")
        #expect(controller.imageResult(for: 0) == nil)
        await settle { controller.imageResult(for: 0) == .image(Data([1])) }

        #expect(controller.imageResult(for: 0) == .image(Data([1])))
    }

    @Test
    func `refreshImage tells the view to redraw before the host answers`() async {
        let (controller, host) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n",
            mode: .rendered
        )
        host.results["https://e.com/a.png"] = .remoteNotLoaded(host: "e.com")
        controller.viewportChanged(0 ..< 1)
        await settle { controller.imageResult(for: 0) != nil }
        var changed: [String] = []
        controller.onImageChange = { changed.append($0) }

        controller.refreshImage(destination: "https://e.com/a.png")

        #expect(changed == ["https://e.com/a.png"])
    }

    @Test
    func `the image request carries the destination and the document`() async {
        let (controller, host) = MarkdownTextControllerTests.givenController("![a](pics/a.png)\n", mode: .rendered)
        host.results["pics/a.png"] = .refused

        controller.viewportChanged(0 ..< 1)
        await settle { controller.imageResult(for: 0) != nil }

        #expect(controller.lastImageRequest?.destination == "pics/a.png")
        #expect(controller.lastImageRequest?.documentURL == MarkdownTextControllerTests.documentURL)
    }

    @Test
    func `with Reduce Motion on a gif reports not animating`() {
        let gif = Data("GIF89a".utf8)
        let (controller, _) = MarkdownTextControllerTests.givenController("![a](a.gif)\n", mode: .rendered)
        controller.setImageResult(.image(gif), for: "a.gif")

        controller.reduceMotion = false
        #expect(controller.isAnimating(imageIndex: 0))
        controller.reduceMotion = true
        #expect(!controller.isAnimating(imageIndex: 0))
    }

    @Test
    func `a still image never reports animating`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("![a](a.png)\n", mode: .rendered)
        controller.setImageResult(.image(Data([0x89, 0x50, 0x4E, 0x47])), for: "a.png")

        #expect(!controller.isAnimating(imageIndex: 0))
    }

    // MARK: shortcuts

    @Test
    func `a shortcut matches its key typed with Shift`() {
        #expect(FormatAction.matching(key: "C", modifiers: [.command, .shift]) == .code)
    }
}
