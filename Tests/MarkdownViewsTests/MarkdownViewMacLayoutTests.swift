#if os(macOS)
    import AppKit
    import ImageIO
    import MarkdownCore
    @testable import MarkdownViews
    import Testing
    import UniformTypeIdentifiers

    /// Design › Editor and Boxes: editor image cards and thumbnails, and the
    /// rendered boxes, on the Mac view's real layout.
    @MainActor
    struct MarkdownViewMacLayoutTests {
        // MARK: editor images

        /// A PNG of a given pixel size.
        static func png(width: Int, height: Int) throws -> Data {
            let rep = try #require(NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ))
            return try #require(rep.representation(using: .png, properties: [:]))
        }

        static func imageFragment(_ view: MarkdownView, line: Int) throws -> MarkdownLayoutFragment {
            let layout = try #require(view.textView.textLayoutManager)
            layout.ensureLayout(for: layout.documentRange)
            let offset = view.text.split(separator: "\n", omittingEmptySubsequences: false).prefix(line)
                .reduce(0) { $0 + $1.utf16.count + 1 }
            let location = try #require(layout.location(at: offset))
            return try #require(layout.textLayoutFragment(for: location) as? MarkdownLayoutFragment)
        }

        @Test
        func `an editor image draws its card under its one-line source`() throws {
            let view = MarkdownViewMacTests.givenView("intro\n![Map](https://e.com/a.png)\nafter")
            view.controller.setImageResult(.remoteNotLoaded(host: "e.com"), for: "https://e.com/a.png")

            let fragment = try Self.imageFragment(view, line: 1)
            let box = try #require(fragment.editorImageBoxes.first)
            let style = view.textView.textStorage?.attribute(
                .paragraphStyle,
                at: 6,
                effectiveRange: nil
            ) as? NSParagraphStyle

            #expect(box.mark.content.title == "Map")
            #expect(box.mark.content.button == "Load Image")
            #expect(style?.lineBreakMode == .byTruncatingTail)
            #expect(style?.paragraphSpacing ?? 0 >= box.rect.height)
        }

        @Test
        func `an editor image becomes a thumbnail at most 120 points tall`() throws {
            let view = MarkdownViewMacTests.givenView("![Map](a.png)\nafter")
            try view.controller.setImageResult(.image(Self.png(width: 400, height: 300)), for: "a.png")

            let box = try #require(try Self.imageFragment(view, line: 0).editorImageBoxes.first)

            #expect(box.mark.thumbnail != nil)
            #expect(box.rect.height == 120)
            #expect(box.rect.width == 160)
        }

        @Test
        func `an editor thumbnail is decoded once per result`() throws {
            let view = MarkdownViewMacTests.givenView("![Map](a.png)\nafter")
            try view.controller.setImageResult(.image(Self.png(width: 400, height: 300)), for: "a.png")
            let first = try #require(try Self.imageFragment(view, line: 0).editorImageBoxes.first?.mark.thumbnail)

            view.display.restyle(around: 0)
            let restyled = try Self.imageFragment(view, line: 0).editorImageBoxes.first?.mark.thumbnail
            try view.controller.setImageResult(.image(Self.png(width: 200, height: 100)), for: "a.png")
            let replaced = try Self.imageFragment(view, line: 0).editorImageBoxes.first?.mark

            #expect(restyled === first)
            #expect(replaced?.thumbnail !== first)
            #expect(replaced?.size == CGSize(width: 200, height: 100))
        }

        @Test
        func `a click on an editor card activates the image`() throws {
            let host = RecordingHost()
            let view = MarkdownView(text: "![Map](https://e.com/a.png)\n", host: host)
            view.controller.setImageResult(.remoteNotLoaded(host: "e.com"), for: "https://e.com/a.png")
            let fragment = try Self.imageFragment(view, line: 0)
            let box = try #require(fragment.editorImageBoxes.first)
            let center = CGPoint(
                x: box.rect.midX + fragment.layoutFragmentFrame.minX,
                y: box.rect.midY + fragment.layoutFragmentFrame.minY
            )

            #expect(view.textView.clickEditorImage(at: center))
            #expect(host.activated == ["https://e.com/a.png"])
        }

        @Test
        func `a click away from an editor card is left to the text`() {
            let view = MarkdownViewMacTests.givenView("intro\n![Map](https://e.com/a.png)\n")
            view.controller.setImageResult(.remoteNotLoaded(host: "e.com"), for: "https://e.com/a.png")

            #expect(!view.textView.clickEditorImage(at: CGPoint(x: 4, y: 4)))
        }

        @Test
        func `the caret inside an image source lets it wrap`() {
            let view = MarkdownViewMacTests.givenView("![Map](a.png)\nafter")
            view.select(3 ..< 3)
            view.display.restyle(around: 3)

            let style = view.textView.textStorage?.attribute(
                .paragraphStyle,
                at: 0,
                effectiveRange: nil
            ) as? NSParagraphStyle
            #expect(style?.lineBreakMode != .byTruncatingTail)
        }

        // MARK: boxes

        static let longCode = "```\n" + String(repeating: "let value = compute(input) + 1; ", count: 12) + "\n```\n"

        static func lineCount(_ view: MarkdownView, at offset: Int) throws -> Int {
            let layout = try #require(view.textView.textLayoutManager)
            layout.ensureLayout(for: layout.documentRange)
            let location = try #require(layout.location(at: offset))
            return try #require(layout.textLayoutFragment(for: location)).textLineFragments.count
        }

        @Test
        func `a wide code block scrolls sideways in its own box in rendered mode`() throws {
            let view = MarkdownViewMacTests.givenView(
                Self.longCode + "\n" + String(repeating: "prose words ", count: 80),
                mode: .rendered
            )
            view.updateBoxes()

            let box = try #require(view.boxViews.values.first)
            #expect(view.boxViews.count == 1)
            #expect(box.textView.frame.width > box.frame.width)
            #expect(try Self.lineCount(view, at: 0) == 1)
            #expect(try Self.lineCount(view, at: view.controller.displayString.utf16.count - 5) > 1)

            box.scroll(by: 40)
            #expect(box.scrollOffset == 40)
            box.scroll(by: -100)
            #expect(box.scrollOffset == 0)
        }

        @Test
        func `the main selection shows in a box view`() throws {
            let view = MarkdownViewMacTests.givenView("intro\n\n" + Self.longCode, mode: .rendered)
            view.updateBoxes()
            let box = try #require(view.boxViews.values.first)

            view.textView.setSelectedRange(NSRange(location: 2, length: 13))
            let inside = box.textView.selectedRange()
            view.textView.setSelectedRange(NSRange(location: 1, length: 0))

            #expect(inside == NSRange(location: 0, length: 9))
            #expect(box.textView.selectedRange() == NSRange(location: 0, length: 0))
        }

        @Test
        func `a code block that fits gets no box view`() {
            let view = MarkdownViewMacTests.givenView("```\nshort\n```\n", mode: .rendered)
            view.updateBoxes()

            #expect(view.boxViews.isEmpty)
        }

        @Test
        func `the editor wraps a wide code line`() throws {
            let view = MarkdownViewMacTests.givenView(Self.longCode)

            #expect(try Self.lineCount(view, at: 5) > 1)
            #expect(view.boxViews.isEmpty)
        }

        @Test
        func `an image size comes from its header`() throws {
            let data = try MarkdownViewMacLayoutTests.png(width: 400, height: 300)

            #expect(ImageAttachment.headerSize(data) == CGSize(width: 400, height: 300))
            #expect(ImageAttachment.headerSize(Data([1, 2, 3])) == .zero)
        }

        @Test
        func `an image size from its header follows a quarter-turn orientation`() throws {
            let png = try Self.png(width: 400, height: 300)
            let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let jpeg = NSMutableData()
            let destination = try #require(CGImageDestinationCreateWithData(
                jpeg,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ))
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
            try #require(CGImageDestinationFinalize(destination))

            #expect(ImageAttachment.headerSize(jpeg as Data) == CGSize(width: 300, height: 400))
        }

        // MARK: tables

        /// Two tables with one blank line between them: rendered rows at offsets 0, 4, 8, and 19.
        static let twoTables = "| a | b |\n|---|---|\n| 1 | 2 |\n\n| cccccccc | d |\n|---|---|\n| 3 | 4 |\n"

        static func tabStops(_ view: MarkdownView, at offset: Int) -> [CGFloat] {
            let style = view.textView.textStorage?.attribute(
                .paragraphStyle,
                at: offset,
                effectiveRange: nil
            ) as? NSParagraphStyle
            return style?.tabStops.map(\.location) ?? []
        }

        static func boxID(_ view: MarkdownView, at offset: Int) -> Int? {
            (view.textView.textStorage?.attribute(.markdownBox, at: offset, effectiveRange: nil) as? BoxMark)?.id
        }

        @Test
        func `a table's body rows take its header row's column stops`() {
            let view = MarkdownViewMacTests.givenView(Self.twoTables, mode: .rendered)

            #expect(Self.tabStops(view, at: 0).count == 1)
            #expect(Self.tabStops(view, at: 4) == Self.tabStops(view, at: 0))
            #expect(Self.tabStops(view, at: 19) == Self.tabStops(view, at: 8))
            #expect(Self.tabStops(view, at: 8) != Self.tabStops(view, at: 0))
        }

        @Test
        func `two adjacent tables are two boxes`() {
            let view = MarkdownViewMacTests.givenView(Self.twoTables, mode: .rendered)

            #expect(Self.boxID(view, at: 4) == Self.boxID(view, at: 0))
            #expect(Self.boxID(view, at: 19) == Self.boxID(view, at: 8))
            #expect(Self.boxID(view, at: 8) != Self.boxID(view, at: 0))
        }
    }
#endif
