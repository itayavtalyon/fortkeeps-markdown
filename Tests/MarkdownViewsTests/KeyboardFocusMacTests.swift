#if os(macOS)
    import AppKit
    import MarkdownCore
    @testable import MarkdownViews
    import Testing

    /// Design › Accessibility: keyboard focus and VoiceOver elements on the Mac view.
    @MainActor
    struct KeyboardFocusMacTests {
        static let longCode = "```\n" + String(repeating: "let value = compute(input) + 1; ", count: 12) + "\n```\n"
        static let text = "[a](https://a.com)\n\n- [ ] task\n\n![m](https://e.com/m.png)\n\n" + longCode
            + "\n```\nshort\n```\n\n[b](https://b.com)\n"

        static func givenView(_ text: String = text, mode: MarkdownMode = .rendered) -> (MarkdownView, RecordingHost) {
            let host = RecordingHost()
            let view = MarkdownView(text: text, mode: mode, host: host)
            view.controller.setImageResult(.remoteNotLoaded(host: "e.com"), for: "https://e.com/m.png")
            view.layoutSubtreeIfNeeded()
            return (view, host)
        }

        static func kind(_ target: FocusTarget?) -> String {
            switch target {
            case .link: "link"
            case .checkbox: "checkbox"
            case .card: "card"
            case .box: "box"
            case nil: "none"
            }
        }

        @Test
        func `tab visits links, checkboxes, cards, and wide boxes in reading order, then leaves`() {
            let (view, _) = Self.givenView()
            var visited: [String] = []
            while view.handle(.tab(forward: true)) == .handled {
                visited.append(Self.kind(view.focusedTarget))
            }

            #expect(visited == ["link", "checkbox", "card", "box", "link"])
            #expect(view.focusedTarget == nil)
        }

        @Test
        func `shift-tab walks back and leaves before the first element`() {
            let (view, _) = Self.givenView()
            _ = view.handle(.tab(forward: true))

            #expect(view.handle(.tab(forward: false)) == .leave(forward: false))
        }

        @Test
        func `return opens a focused link, space toggles a focused checkbox, and return activates a card`() {
            let (view, host) = Self.givenView()
            _ = view.handle(.tab(forward: true))
            #expect(view.handle(.returnKey) == .handled)
            #expect(host.opened.map(\.destination) == ["https://a.com"])

            _ = view.handle(.tab(forward: true))
            #expect(view.handle(.space) == .handled)
            #expect(view.text.contains("- [x] task"))

            view.focusedTarget = .card(destination: "https://e.com/m.png", offset: 0)
            #expect(view.handle(.returnKey) == .handled)
            #expect(host.activated == ["https://e.com/m.png"])
        }

        @Test
        func `the arrows scroll a focused box and escape clears focus`() throws {
            let (view, _) = Self.givenView()
            for _ in 0 ..< 4 {
                _ = view.handle(.tab(forward: true))
            }
            let box = try #require(view.boxViews.values.first)

            #expect(view.handle(.right) == .handled)
            #expect(box.scrollOffset == 40)
            #expect(view.focusRing.superview != nil)
            #expect(view.handle(.escape) == .handled)
            #expect(view.focusedTarget == nil)
            #expect(view.focusRing.superview == nil)
        }

        @Test
        func `the locked editor focuses links and checkboxes, and the editor leaves tab to the text`() {
            let (locked, _) = Self.givenView("[a](https://a.com)\n\n- [ ] task\n", mode: .editorLocked)
            var visited: [String] = []
            while locked.handle(.tab(forward: true)) == .handled {
                visited.append(Self.kind(locked.focusedTarget))
            }
            let (editor, _) = Self.givenView("[a](https://a.com)\n", mode: .editor)

            #expect(visited == ["link", "checkbox"])
            #expect(editor.handle(.tab(forward: true)) == .ignored)
        }

        @Test
        func `voiceOver reads each heading with its level, and lists, tables, and quotes`() {
            let (view, _) = Self.givenView("# One\n\n## Two\n\n- a\n\n> q\n\n| h |\n| - |\n| c |\n")
            let elements = view.textView.blockElements()

            #expect(elements.map(\.kind) == [.heading(1), .heading(2), .list, .quote, .table])
            #expect(elements.first?.accessibilityLabel() == "One")
            #expect(elements[1].accessibilityValue() as? Int == 2)
            #expect(elements[1].accessibilityRoleDescription() == "heading level 2")
        }
    }
#endif
