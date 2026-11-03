#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    import PDFKit
    @testable import ScrollSupport
    import Testing

    /// Export and print (screens §3.16; log 004 Round 6).
    @MainActor
    struct ExportMacTests {
        let base = DocumentWindowTests()
        /// A 1 × 1 PNG.
        static let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA"
            + "60e6kgAAAABJRU5ErkJggg=="

        /// A PNG 8193 pixels wide: one past the side the view draws.
        static func wide() throws -> Data {
            let context = try #require(CGContext(
                data: nil, width: 8193, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            let image = try #require(context.makeImage())
            let data = NSMutableData()
            let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            try #require(CGImageDestinationFinalize(destination))
            return data as Data
        }

        func open(_ text: String) throws -> DocumentWindowController {
            try base.open(base.given("a.md", text)).1
        }

        /// Must-pass (plan 02 › 2f), in the app.
        @Test
        func `exporting as HTML writes one page with no script, the local image as data, and fetches nothing`(
        ) async throws {
            let png = try #require(Data(base64Encoded: Self.png))
            let controller =
                try open("# Trip\n\n<script>alert(1)</script>\n\n![map](map.png) ![far](https://e.com/far.png)\n")
            try png.write(to: base.folder.appending(path: "map.png"))
            base.spy.exportURL = base.folder.appending(path: "out.html")

            await controller.exportHTML()

            let page = try String(contentsOf: base.folder.appending(path: "out.html"), encoding: .utf8)
            #expect(base.spy.exportNames == ["a.html"])
            #expect(!page.lowercased().contains("<script"))
            #expect(page.contains("data:image/png;base64,\(png.base64EncodedString())"))
            #expect(page.contains("<a href=\"https://e.com/far.png\">far</a>"))
            #expect(base.spy.transport.requests.isEmpty)
        }

        @Test
        func `HTML export embeds only what the image rules let the view show`() async throws {
            let png = try #require(Data(base64Encoded: Self.png))
            let outside = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            try png.write(to: outside.appending(path: "private.png"))
            let controller = try open("![a](link.png) ![b](big.png) ![c](wide.png)\n")
            try FileManager.default.createSymbolicLink(
                at: base.folder.appending(path: "link.png"),
                withDestinationURL: outside.appending(path: "private.png")
            )
            try (png + Data(count: 5_000_000)).write(to: base.folder.appending(path: "big.png"))
            try Self.wide().write(to: base.folder.appending(path: "wide.png"))
            base.spy.exportURL = base.folder.appending(path: "out.html")

            await controller.exportHTML()

            let page = try String(contentsOf: base.folder.appending(path: "out.html"), encoding: .utf8)
            #expect(!page.contains("data:image"))
        }

        @Test
        func `exporting as PDF writes the rendered text`() async throws {
            let controller = try open("# Trip\n\n**bold** word\n")
            let url = base.folder.appending(path: "out.pdf")
            base.spy.exportURL = url

            await controller.exportPDF()

            #expect(base.spy.exportNames == ["a.pdf"])
            let text = try #require(PDFDocument(url: url)?.string)
            #expect(text.contains("Trip"))
            #expect(text.contains("bold word"))
            #expect(!text.contains("**"))
        }

        @Test
        func `printing lays out the rendered text with 20 mm margins and no header`() async throws {
            let controller = try open("# Trip\n\n![map](map.png)\n")
            try Data(base64Encoded: Self.png)?.write(to: base.folder.appending(path: "map.png"))

            await controller.printText()

            let operation = try #require(base.spy.printed.first)
            let view = try #require(operation.view as? NSTextView)
            #expect(view.string == "Trip\n\u{FFFC}")
            let attachment = view.textStorage?.attribute(.attachment, at: 5, effectiveRange: nil) as? NSTextAttachment
            #expect(attachment?.image != nil)
            #expect(abs(operation.printInfo.topMargin - 20 / 25.4 * 72) < 0.01)
            #expect(abs(operation.printInfo.leftMargin - 20 / 25.4 * 72) < 0.01)
            #expect(operation.printInfo.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] as? Bool == false)
            #expect(operation.jobTitle == "a.md")
        }

        @Test(.timeLimit(.minutes(1)))
        func `a cancelled panel writes nothing, and a failed export says so`() async throws {
            let controller = try open("# Trip\n")

            controller.exportHTML(nil)
            controller.exportPDF(nil)
            controller.printText(nil)
            while base.spy.exportNames.count < 2 || base.spy.printed.isEmpty {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(base.spy.alerts.isEmpty)
            base.spy.response = .alertFirstButtonReturn
            base.spy.exportURL = base.folder.appending(path: "missing/out.html")
            await controller.exportHTML()
            await controller.exportPDF()

            #expect(base.spy.alerts.count == 2)
            #expect(base.spy.alerts.allSatisfy { $0.hasPrefix("Couldn’t export “a.md”.") })
        }

        @Test
        func `copying as rich text puts the rendered text on the pasteboard`() throws {
            let controller = try open("**bold** word\n")

            controller.copyAsRichText(nil)

            #expect(base.spy.pasteboard.string(forType: .string) == "bold word")
            #expect(base.spy.pasteboard.data(forType: .rtf) != nil)
        }

        @Test
        func `the menu bar has the 2f commands with their keys`() throws {
            let menu = MainMenu.make()
            func item(_ menuTitle: String, _ title: String) throws -> NSMenuItem {
                try #require(menu.item(withTitle: menuTitle)?.submenu?.items.first { $0.title == title })
            }

            let settings = try #require(menu.items.first?.submenu?.items.first { $0.title == "Settings…" })
            #expect(settings.keyEquivalent == ",")
            #expect(try item("File", "Open Folder…").keyEquivalentModifierMask == [.command, .shift])
            #expect(try item("File", "Export as PDF…").action == #selector(DocumentWindowController.exportPDF(_:)))
            #expect(try item("File", "Export as HTML…").action == #selector(DocumentWindowController.exportHTML(_:)))
            #expect(try item("File", "Print…").keyEquivalent == "p")
            #expect(try item("File", "Move to Trash").keyEquivalent == "\u{8}")
            #expect(try item("Edit", "Copy as Rich Text").keyEquivalentModifierMask == [.command, .option])
            #expect(try item("View", "Show Sidebar").keyEquivalentModifierMask == [.command, .control])
            #expect(try item("View", "Outline").keyEquivalent == "o")
        }
    }
#endif
