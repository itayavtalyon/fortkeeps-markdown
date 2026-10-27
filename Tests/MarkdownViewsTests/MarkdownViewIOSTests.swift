#if canImport(UIKit)
    import MarkdownCore
    @testable import MarkdownViews
    import Testing
    import UIKit

    /// Design › Modes, Editor, Format commands, Copy: the iOS view.
    @MainActor
    struct MarkdownViewIOSTests {
        static func givenView(
            _ text: String,
            mode: MarkdownMode = .editor,
            features: MarkdownFeatures = MarkdownFeatures()
        ) -> MarkdownView {
            let view = MarkdownView(text: text, features: features, mode: mode, host: nil)
            view.layoutIfNeeded()
            return view
        }

        /// Types as the keyboard does: UIKit asks the delegate, applies the
        /// text, moves the caret, and reports the change. A logic test has no
        /// keyboard, and UIKit asks the delegate only for keyboard input.
        static func type(_ text: String, in view: MarkdownView) {
            let textView = view.textView
            let range = textView.selectedRange
            guard view.textView(textView, shouldChangeTextIn: range, replacementText: text) else { return }
            textView.textStorage.replaceCharacters(in: range, with: text)
            textView.selectedRange = NSRange(location: range.location + text.utf16.count, length: 0)
            view.textViewDidChange(textView)
        }

        /// A dynamic color as drawn in the light appearance.
        static func lightComponents(_ color: Any?) -> [CGFloat] {
            guard let color = (color as? UIColor)?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            else { return [] }
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return [red, green, blue]
        }

        static func components(_ color: SRGBColor) -> [CGFloat] {
            [CGFloat(color.red) / 255, CGFloat(color.green) / 255, CGFloat(color.blue) / 255]
        }

        // MARK: format bar

        @Test(arguments: FormatAction.allCases)
        func `each format bar button gives the same text as its shortcut`(action: FormatAction) throws {
            let text = "one\n## two words\nthree"
            let byButton = Self.givenView(text)
            let byShortcut = Self.givenView(text)
            byButton.select(7 ..< 10)
            byShortcut.select(7 ..< 10)
            let index = try #require(FormatAction.allCases.firstIndex(of: action))
            let shortcut = try #require(byShortcut.textView.keyCommands?.first { $0.propertyList as? Int == index })

            byButton.formatBar.press(action)
            byShortcut.textView.performShortcut(shortcut)

            #expect(shortcut.input == action.shortcut.key)
            #expect(byButton.text != text)
            #expect(byButton.text == byShortcut.text)
            #expect(byButton.textView.text == byButton.text)
        }

        @Test
        func `the format bar docks above the keyboard only in the editor`() {
            let view = Self.givenView("a")
            #expect(view.textView.inputAccessoryView === view.formatBar)

            view.mode = .editorLocked
            #expect(view.textView.inputAccessoryView == nil)
        }

        // MARK: editor

        @Test(arguments: [true, false])
        func `tildes are dimmed only when strikethrough is on`(strikethrough: Bool) {
            var features = MarkdownFeatures()
            features.strikethrough = strikethrough
            let view = Self.givenView("a ~~b~~", features: features)
            let color = view.textView.textStorage.attribute(.foregroundColor, at: 2, effectiveRange: nil)

            let dimmed = Self.lightComponents(color) == Self.components(DesignColors.text3.light)
            #expect(dimmed == strikethrough)
        }

        @Test
        func `the editor spellchecks and rendered mode does not`() {
            let view = Self.givenView("text")
            #expect(view.textView.spellCheckingType == .yes)

            view.mode = .rendered
            #expect(view.textView.spellCheckingType == .no)
        }

        @Test
        func `smart quotes and smart dashes are off`() {
            let view = Self.givenView("text")

            #expect(view.textView.smartQuotesType == .no)
            #expect(view.textView.smartDashesType == .no)
        }

        @Test
        func `a typed edit reaches the model and Undo removes it`() {
            let view = Self.givenView("ab")
            view.select(2 ..< 2)

            Self.type("c", in: view)
            #expect(view.text == "abc")

            view.textView.undoManager?.undo()
            #expect(view.text == "ab")
            #expect(view.textView.text == "ab")
        }

        @Test
        func `an insertion past the byte limit keeps the prefix that fits`() {
            let view = MarkdownView(text: "ab", maxUTF8Bytes: 4, host: nil)
            view.select(2 ..< 2)

            Self.type("cdef", in: view)

            #expect(view.text == "abcd")
            #expect(view.textView.text == "abcd")
        }

        @Test
        func `pressing Return in a list item continues the list`() {
            let view = Self.givenView("- a")
            view.select(3 ..< 3)

            Self.type("\n", in: view)

            #expect(view.text == "- a\n- ")
            #expect(view.textView.text == "- a\n- ")
        }

        // MARK: modes

        @Test
        func `a switch to rendered and back keeps the caret, the first visible line, and Undo`() throws {
            let text = (0 ..< 300).map { "Line \($0) with **bold** text" }.joined(separator: "\n\n")
            let view = Self.givenView(text)
            let lineStart = try #require(text.range(of: "Line 150 ")).lowerBound.utf16Offset(in: text)
            view.select(lineStart + 2 ..< lineStart + 2)
            Self.type("x", in: view)
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
        func `a tap on a drawn checkbox toggles the task`(mode: MarkdownMode) throws {
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

        // MARK: copy

        @Test
        func `select all and copy on a 2 MB document equal the model copy`() {
            let block = "## Heading *x*\n\nSome **bold** text, a [link](https://e.com), and `code`.\n\n- [ ] task\n\n"
            let text = String(repeating: block, count: 2_000_000 / block.utf8.count + 1)
            let view = Self.givenView(text, mode: .rendered)
            let pasteboard = UIPasteboard.withUniqueName()
            defer { UIPasteboard.remove(withName: pasteboard.name) }
            view.textView.pasteboard = pasteboard

            view.textView.selectAll(nil)
            view.textView.copy(nil)

            let rendered = view.controller.document.rendered
            #expect(pasteboard.string == rendered.copyText(0 ..< rendered.utf16Count))
        }
    }
#endif
