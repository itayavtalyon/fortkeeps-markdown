#if os(macOS)
    import AppKit
    import MarkdownCore
    @testable import MarkdownViews
    import Testing

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
    }
#endif
