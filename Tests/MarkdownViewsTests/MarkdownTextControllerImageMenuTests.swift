import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing

/// Design log 002 › Image cards: Reload Image, Load All Images, and the reload status line.
extension MarkdownTextControllerModeTests {
    @Test
    func `a failed reload is announced once`() {
        let (controller, _) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n",
            mode: .rendered
        )
        var announced: [String] = []
        controller.onAnnouncement = { announced.append($0) }

        controller.setImageResult(.image(Data([1])), for: "https://e.com/a.png")
        controller.setImageResult(.image(Data([1]), reloadFailure: .timedOut), for: "https://e.com/a.png")

        #expect(announced == ["Couldn't reload this image. It took too long to load."])
    }

    @Test
    func `a drawn image offers Reload Image and a card does not`() {
        let (controller, _) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png) ![b](https://e.com/b.png)\n",
            mode: .rendered
        )
        controller.setImageResult(.image(Data([1])), for: "https://e.com/a.png")
        controller.setImageResult(.failed(reason: .network), for: "https://e.com/b.png")

        #expect(controller.imageMenuItems(destination: "https://e.com/a.png") == [.reload("https://e.com/a.png")])
        #expect(controller.imageMenuItems(destination: "https://e.com/b.png").isEmpty)
        #expect(controller.imageMenuItems(destination: nil).isEmpty)
    }

    @Test
    func `load all shows while a remote image is not loaded`() {
        let (controller, _) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n\n![b](https://e.com/b.png)\n\n![c](c.png)\n",
            mode: .rendered
        )
        controller.setImageResult(.image(Data([1])), for: "https://e.com/a.png")

        // b has no result yet: it lies below the viewport.
        #expect(controller.imageMenuItems(destination: nil) == [.loadAll])
        controller.setImageResult(.remoteNotLoaded(host: "e.com"), for: "https://e.com/b.png")
        #expect(controller.imageMenuItems(destination: "https://e.com/a.png") == [
            .reload("https://e.com/a.png"),
            .loadAll
        ])
        controller.setImageResult(.loading, for: "https://e.com/b.png")
        #expect(controller.imageMenuItems(destination: nil).isEmpty)
    }

    @Test
    func `the editor finds the image whose source holds an offset`() {
        let (controller, _) = MarkdownTextControllerTests.givenController("ab ![a](x.png) c\n")

        #expect(controller.imageDestination(atDisplayOffset: 3) == "x.png")
        #expect(controller.imageDestination(atDisplayOffset: 13) == "x.png")
        #expect(controller.imageDestination(atDisplayOffset: 2) == nil)
        #expect(controller.imageDestination(atDisplayOffset: 15) == nil)
    }

    @Test
    func `the image menu items tell the host`() {
        let (controller, host) = MarkdownTextControllerTests.givenController(
            "![a](https://e.com/a.png)\n",
            mode: .rendered
        )

        controller.perform(.reload("https://e.com/a.png"))
        controller.perform(.loadAll)

        #expect(host.reloaded.map(\.destination) == ["https://e.com/a.png"])
        #expect(host.loadAllCount == 1)
    }
}
