#if canImport(UIKit)
    import MarkdownCore
    @testable import MarkdownViews
    import Testing
    import UIKit

    /// Design › Accessibility: keyboard focus and VoiceOver attributes on the iOS view.
    @MainActor
    struct KeyboardFocusIOSTests {
        static let longCode = "```\n" + String(repeating: "let value = compute(input) + 1; ", count: 12) + "\n```\n"

        static func givenView(_ text: String, mode: MarkdownMode = .rendered) -> (MarkdownView, RecordingHost) {
            let host = RecordingHost()
            let view = MarkdownView(text: text, mode: mode, host: host)
            view.layoutIfNeeded()
            return (view, host)
        }

        @Test
        func `tab visits links, checkboxes, and wide boxes in reading order, then leaves`() {
            let (view, _) = Self.givenView("[a](https://a.com)\n\n- [ ] task\n\n" + Self.longCode)
            var count = 0
            while view.handle(.tab(forward: true)) == .handled {
                count += 1
            }

            #expect(count == 3)
            #expect(view.focusedTarget == nil)
        }

        @Test
        func `return opens a focused link and space toggles a focused checkbox`() {
            let (view, host) = Self.givenView("[a](https://a.com)\n\n- [ ] task\n")
            _ = view.handle(.tab(forward: true))
            #expect(view.handle(.returnKey) == .handled)
            _ = view.handle(.tab(forward: true))
            #expect(view.handle(.space) == .handled)

            #expect(host.opened.map(\.destination) == ["https://a.com"])
            #expect(view.text.contains("- [x] task"))
        }

        @Test
        func `the focus keys exist in rendered mode and only Ctrl-Tab in the editor`() {
            let (rendered, _) = Self.givenView("[a](https://a.com)\n")
            let (editor, _) = Self.givenView("a\n", mode: .editor)

            #expect(rendered.focusKeyCommands.map(\.input) == ["\t", "\t"])
            _ = rendered.handle(.tab(forward: true))
            #expect(rendered.focusKeyCommands.count == 7)
            #expect(editor.focusKeyCommands.map(\.modifierFlags) == [.control])
        }

        @Test
        func `voiceOver reads heading levels and the kind of a list, table, or quote`() {
            let (view, _) = Self.givenView("## Two\n\n- a\n\n> q\n")
            let storage = view.textView.textStorage

            #expect(storage.attribute(.accessibilityTextHeadingLevel, at: 0, effectiveRange: nil) as? Int == 2)
            #expect(storage.attribute(.accessibilityTextCustom, at: 4, effectiveRange: nil) as? [String] == ["list"])
            #expect(storage.attribute(.accessibilityTextCustom, at: 6, effectiveRange: nil) as? [String] == ["quote"])
        }
    }
#endif
