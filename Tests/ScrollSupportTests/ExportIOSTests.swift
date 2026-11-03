#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    import PDFKit
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// The ⋯ › Export submenu (screens §3.16, §3.20; log 004 Round 6), and Share.
    extension DocumentViewControllerTests {
        /// A 1 × 1 PNG.
        static let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA"
            + "60e6kgAAAABJRU5ErkJggg=="

        /// The export sheet is up, and does not open what it saves.
        func expectExportSheet() throws {
            let picker = try #require(presented.last as? UIDocumentPickerViewController)
            #expect(picker.delegate == nil)
        }

        @Test
        func `the Export submenu holds the PDF, the HTML, Print, and the rich-text copy`() async throws {
            let controller = try await screen()

            let export = try #require(controller.navigationItem.rightBarButtonItem?.menu?.children[2] as? UIMenu)

            #expect(export.children.map(\.title) == ["Export PDF", "Export HTML", "Print", "Copy as rich text"])
        }

        @Test
        func `the Find item shows the find navigator`() async throws {
            let controller = try await screen()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            window.addSubview(controller.view)
            window.makeKeyAndVisible()

            perform("Find", controller)

            let interaction = try #require(controller.markdownView.textView.findInteraction)
            while !interaction.isFindNavigatorVisible {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        /// Must-pass (plan 02 › 2f), on iOS.
        @Test
        func `exporting HTML gives one page with no script, the local image as data, and fetches nothing`(
        ) async throws {
            let png = try #require(Data(base64Encoded: Self.png))
            let controller =
                try await screen(
                    "# Trip\n\n<script>alert(1)</script>\n\n![map](map.png) ![far](https://e.com/far.png)\n"
                )
            try png.write(to: folder.appending(path: "map.png"))

            let url = try #require(controller.exportHTML())

            try expectExportSheet()
            #expect(url.lastPathComponent == "a.html")
            let page = try String(contentsOf: url, encoding: .utf8)
            #expect(!page.lowercased().contains("<script"))
            #expect(page.contains("data:image/png;base64,\(png.base64EncodedString())"))
            #expect(page.contains("<a href=\"https://e.com/far.png\">far</a>"))
            #expect(transport.requests.isEmpty)
        }

        @Test
        func `exporting a PDF gives the rendered text on pages of the local paper size`() async throws {
            let controller = try await screen("# Trip\n\n**bold** word\n\n![map](map.png)\n")
            try Data(base64Encoded: Self.png)?.write(to: folder.appending(path: "map.png"))

            let url = try #require(await controller.exportPDF())

            try expectExportSheet()
            #expect(url.lastPathComponent == "a.pdf")
            let pdf = try #require(PDFDocument(url: url))
            let text = try #require(pdf.string)
            #expect(text.contains("Trip"))
            #expect(text.contains("bold word"))
            #expect(!text.contains("**"))
            // US Letter where the region measures in inches, else A4.
            let paper = Locale.current.measurementSystem == .us
                ? CGSize(width: 612, height: 792) : CGSize(width: 595, height: 842)
            #expect(pdf.page(at: 0)?.bounds(for: .mediaBox).size == paper)
        }

        @Test
        func `printing hands the rendered text to the print sheet under the file name`() async throws {
            let controller = try await screen("# Trip\n")

            await controller.printText()

            let printer = try #require(printed.first)
            #expect(printer.printInfo?.jobName == "a.md")
            let margin = DocumentViewController.pageMargin
            #expect(printer.printFormatter?.perPageContentInsets
                == UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin))
        }

        @Test
        func `the menu items run their commands`() async throws {
            let controller = try await screen("**bold**\n")

            perform("Export HTML", controller)
            perform("Export PDF", controller)
            perform("Print", controller)
            perform("Copy as rich text", controller)

            #expect(environment.pasteboard.contains(pasteboardTypes: ["public.rtf"]))
            while printed.isEmpty || presented.count < 2 {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test
        func `the Share button gives the system share sheet the file itself`() async throws {
            let controller = try await screen()

            let share = try #require(controller.navigationItem.rightBarButtonItems?[1])
            share.primaryAction?.performWithSender(nil, target: nil)

            #expect(presented.last is UIActivityViewController)
        }
    }
#endif
