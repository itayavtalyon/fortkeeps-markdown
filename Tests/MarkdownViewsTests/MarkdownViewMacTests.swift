#if os(macOS)
    import AppKit
    import MarkdownCore
    @testable import MarkdownViews
    import Testing

    /// Design › Modes, Editor, Format commands, Copy: the Mac view.
    @MainActor
    struct MarkdownViewMacTests {
        static func givenView(
            _ text: String,
            mode: MarkdownMode = .editor,
            features: MarkdownFeatures = MarkdownFeatures()
        ) -> MarkdownView {
            let view = MarkdownView(text: text, features: features, mode: mode, host: nil)
            view.layoutSubtreeIfNeeded()
            return view
        }

        /// A dynamic color as drawn in the light appearance.
        static func lightComponents(_ color: Any?) -> [CGFloat] {
            var resolved: NSColor?
            // swiftlint:disable:next force_unwrapping
            NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
                resolved = (color as? NSColor)?.usingColorSpace(.sRGB)
            }
            return resolved.map { [$0.redComponent, $0.greenComponent, $0.blueComponent] } ?? []
        }

        static func components(_ color: SRGBColor) -> [CGFloat] {
            [CGFloat(color.red) / 255, CGFloat(color.green) / 255, CGFloat(color.blue) / 255]
        }

        static let keyCodes: [String: UInt16] = [
            "b": 11, "i": 34, "k": 40, "c": 8, "'": 39, "\r": 36, "1": 18, "2": 19, "3": 20, "0": 29, "8": 28
        ]

        static func keyEvent(_ shortcut: FormatShortcut) throws -> NSEvent {
            var flags: NSEvent.ModifierFlags = []
            if shortcut.modifiers.contains(.command) {
                flags.insert(.command)
            }
            if shortcut.modifiers.contains(.shift) {
                flags.insert(.shift)
            }
            if shortcut.modifiers.contains(.option) {
                flags.insert(.option)
            }
            return try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                characters: shortcut.key, charactersIgnoringModifiers: shortcut.key, isARepeat: false,
                keyCode: keyCodes[shortcut.key] ?? 0
            ))
        }

        // MARK: format bar

        @Test(arguments: FormatAction.allCases)
        func `each format bar button gives the same text as its shortcut`(action: FormatAction) throws {
            let text = "one\n## two words\nthree"
            let byButton = Self.givenView(text)
            let byShortcut = Self.givenView(text)
            byButton.select(7 ..< 10)
            byShortcut.select(7 ..< 10)

            byButton.formatBar.press(action)
            #expect(try byShortcut.performKeyEquivalent(with: Self.keyEvent(action.shortcut)))

            #expect(byButton.text != text)
            #expect(byButton.text == byShortcut.text)
            #expect(byButton.textView.string == byButton.text)
        }

        @Test
        func `the format bar shows the eight buttons in the design order`() {
            #expect(FormatBarButton.allCases.map(\.title)
                == ["Bold", "Italic", "Heading", "Bulleted List", "Checkbox", "Link", "Code", "Quote"])
        }

        @Test
        func `a shortcut in the locked editor changes nothing`() throws {
            let view = Self.givenView("one", mode: .editorLocked)
            view.select(0 ..< 3)

            #expect(try view.performKeyEquivalent(with: Self.keyEvent(FormatAction.bold.shortcut)))
            #expect(view.text == "one")
        }

        // MARK: editor

        @Test(arguments: [true, false])
        func `tildes are dimmed only when strikethrough is on`(strikethrough: Bool) {
            var features = MarkdownFeatures()
            features.strikethrough = strikethrough
            let view = Self.givenView("a ~~b~~", features: features)
            let color = view.textView.textStorage?.attribute(.foregroundColor, at: 2, effectiveRange: nil)

            let dimmed = Self.lightComponents(color) == Self.components(DesignColors.text3.light)
            #expect(dimmed == strikethrough)
        }

        @Test
        func `the editor spellchecks and rendered mode does not`() {
            let view = Self.givenView("text")
            #expect(view.textView.isContinuousSpellCheckingEnabled)

            view.mode = .rendered
            #expect(!view.textView.isContinuousSpellCheckingEnabled)
        }

        @Test
        func `smart quotes and smart dashes are off`() {
            let view = Self.givenView("text")

            #expect(!view.textView.isAutomaticQuoteSubstitutionEnabled)
            #expect(!view.textView.isAutomaticDashSubstitutionEnabled)
        }

        @Test
        func `a typed edit reaches the model and Undo removes it`() {
            let view = Self.givenView("ab")
            view.select(2 ..< 2)

            view.textView.insertText("c", replacementRange: NSRange(location: 2, length: 0))
            #expect(view.text == "abc")

            view.controller.undoManager.undo()
            #expect(view.text == "ab")
            #expect(view.textView.string == "ab")
        }

        @Test
        func `typing in the locked editor changes nothing`() {
            let view = Self.givenView("ab", mode: .editorLocked)

            view.textView.insertText("c", replacementRange: NSRange(location: 2, length: 0))

            #expect(view.text == "ab")
        }

        @Test
        func `an insertion past the byte limit keeps the prefix that fits`() {
            let view = MarkdownView(text: "ab", maxUTF8Bytes: 4, host: nil)
            view.select(2 ..< 2)

            view.textView.insertText("cdef", replacementRange: NSRange(location: 2, length: 0))

            #expect(view.text == "abcd")
            #expect(view.textView.string == "abcd")
        }

        // MARK: modes

        @Test
        func `a switch to rendered and back keeps the caret, the first visible line, and Undo`() throws {
            let text = (0 ..< 300).map { "Line \($0) with **bold** text" }.joined(separator: "\n\n")
            let view = Self.givenView(text)
            let lineStart = try #require(text.range(of: "Line 150 ")).lowerBound.utf16Offset(in: text)
            view.select(lineStart + 2 ..< lineStart + 2)
            view.textView.insertText("x", replacementRange: NSRange(location: lineStart + 2, length: 0))
            view.scroll(toOffset: lineStart)
            // Each "Line n" is one paragraph, two newlines apart.
            let lines = { (offset: Int) in view.text.utf16.prefix(offset).count { $0 == 0x0A } / 2 }
            let before = lines(view.firstVisibleOffset)

            view.mode = .rendered
            view.mode = .editor

            #expect(abs(lines(view.firstVisibleOffset) - before) <= 1)
            #expect(view.controller.selection == lineStart + 3 ..< lineStart + 3)
            view.controller.undoManager.undo()
            #expect(view.text == text)
        }

        // MARK: checkboxes

        @Test(arguments: [MarkdownMode.rendered, .editor])
        func `a click on a drawn checkbox toggles the task`(mode: MarkdownMode) throws {
            let view = Self.givenView("- [ ] milk\n", mode: mode)
            let layout = try #require(view.textView.textLayoutManager)
            layout.ensureLayout(for: layout.documentRange)
            let fragment = try #require(layout.textLayoutFragment(for: layout.documentRange.location)
                as? MarkdownLayoutFragment)
            let box = try #require(fragment.markerBoxes.first)
            let center = CGPoint(
                x: box.rect.midX + fragment.layoutFragmentFrame.minX,
                y: box.rect.midY + fragment.layoutFragmentFrame.minY
            )

            #expect(view.textView.clickCheckbox(at: center))
            #expect(view.text == "- [x] milk\n")
        }

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
            let view = Self.givenView("intro\n![Map](https://e.com/a.png)\nafter")
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
            let view = Self.givenView("![Map](a.png)\nafter")
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
            let view = Self.givenView("![Map](a.png)\nafter")
            view.select(3 ..< 3)
            view.display.restyle(around: 3)

            let style = view.textView.textStorage?.attribute(
                .paragraphStyle,
                at: 0,
                effectiveRange: nil
            ) as? NSParagraphStyle
            #expect(style?.lineBreakMode != .byTruncatingTail)
        }

        // MARK: copy

        @Test
        func `select all and copy on a 2 MB document equal the model copy`() {
            let block = "## Heading *x*\n\nSome **bold** text, a [link](https://e.com), and `code`.\n\n- [ ] task\n\n"
            let text = String(repeating: block, count: 2_000_000 / block.utf8.count + 1)
            let view = Self.givenView(text, mode: .rendered)
            let pasteboard = NSPasteboard(name: NSPasteboard.Name("markdown-tests-\(UUID().uuidString)"))
            defer { pasteboard.releaseGlobally() }

            view.textView.selectAll(nil)
            _ = view.textView.writeSelection(to: pasteboard, types: [.string])

            let rendered = view.controller.document.rendered
            #expect(pasteboard.string(forType: .string) == rendered.copyText(0 ..< rendered.utf16Count))
        }
    }
#endif
