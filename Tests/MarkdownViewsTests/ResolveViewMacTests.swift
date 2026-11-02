#if os(macOS)
    import AppKit
    import MarkdownCore
    @testable import MarkdownViews
    import Testing

    /// Screens §3.11: the Mac compare view.
    @MainActor
    struct ResolveViewMacTests {
        static func given(width: CGFloat = 900) -> ResolveView {
            let view = ResolveView(
                mine: "a\nmine\nb\nc\nd\nmine 2\n",
                theirs: "a\ntheirs\nb\nc\nd\ntheirs 2\n",
                mineTitle: "Your Changes",
                theirsTitle: "On Disk"
            )
            view.frame = CGRect(x: 0, y: 0, width: width, height: 600)
            view.layoutSubtreeIfNeeded()
            return view
        }

        static func key(_ characters: String, _ flags: NSEvent.ModifierFlags, code: UInt16 = 0) -> NSEvent? {
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: code
            )
        }

        @Test
        func `each change shows both versions, its state, and its three buttons`() throws {
            let view = Self.given()

            let row = try #require(view.changeRows.first)
            #expect(row.panes.map(\.title) == ["Your Changes", "On Disk"])
            #expect(row.panes.map(\.text) == ["mine", "theirs"])
            #expect(row.stateLabel.stringValue == "Not resolved")
            #expect(row.buttons.map(\.title) == ["Use Mine", "Use Theirs", "Use Both"])
            #expect(row.accessibilityRole() == .group)
            #expect(row.accessibilityLabel() == "Change 1 of 2, not resolved. Mine: mine. Theirs: theirs.")
            #expect(row.accessibilityCustomActions()?.map(\.name) == ["Use Mine", "Use Theirs", "Use Both"])
        }

        @Test
        func `the buttons resolve the changes, and Apply sends the merged text once all are resolved`() {
            let view = Self.given()
            var applied: [String] = []
            view.onApply = { applied.append($0) }
            #expect(view.countLabel.stringValue == "0 of 2 resolved")
            #expect(!view.applyButton.isEnabled)
            #expect(view.applyButton.keyEquivalent == "\r")
            #expect(view.cancelButton.keyEquivalent == "\u{1b}")

            view.changeRows[0].buttons[1].performClick(nil)
            _ = view.changeRows[1].accessibilityCustomActions()?[0].handler?()

            #expect(view.changeRows[0].stateLabel.stringValue == "✓ Theirs")
            #expect(view.countLabel.stringValue == "2 of 2 resolved")
            #expect(view.applyButton.isEnabled)
            view.applyButton.performClick(nil)
            #expect(applied == ["a\ntheirs\nb\nc\nd\nmine 2\n"])
        }

        @Test
        func `cancel calls the host`() {
            let view = Self.given()
            var cancels = 0
            view.onCancel = { cancels += 1 }

            view.cancelButton.performClick(nil)

            #expect(cancels == 1)
        }

        @Test
        func `each unchanged run is collapsed until Show`() throws {
            let view = Self.given()

            let run = try #require(view.unchangedRows.first { $0.lines == 3 })
            #expect(run.summary.stringValue == "3 unchanged lines")
            #expect(run.text.isHidden)
            run.showButton.performClick(nil)
            #expect(!run.text.isHidden)
            #expect(run.showButton.isHidden)
            #expect(view.unchangedRows.first { $0.lines == 1 }?.summary.stringValue == "1 unchanged line")
        }

        @Test
        func `wide is side by side; narrow is stacked`() {
            #expect(Self.given(width: 900).changeRows[0].panesStack.orientation == .horizontal)
            #expect(Self.given(width: 640).changeRows[0].panesStack.orientation == .horizontal)
            #expect(Self.given(width: 639).changeRows[0].panesStack.orientation == .vertical)
        }

        @Test
        func `the current change has a border`() {
            let view = Self.given()

            #expect(view.changeRows.map { $0.layer?.borderWidth } == [2, 0])
        }

        @Test
        func `the Edit › Undo item takes back a choice`() {
            let view = Self.given()
            let undo = NSMenuItem(title: "Undo", action: NSSelectorFromString("undo:"), keyEquivalent: "z")
            #expect(!view.validateUserInterfaceItem(undo))

            view.changeRows[0].buttons[0].performClick(nil)
            #expect(view.validateUserInterfaceItem(undo))
            view.undo(nil)

            #expect(view.changeRows[0].stateLabel.stringValue == "Not resolved")
            #expect(view.validateUserInterfaceItem(NSMenuItem(title: "Other", action: nil, keyEquivalent: "")))
        }

        @Test
        func `the Option arrows move between changes and the Command-Option keys choose`() throws {
            let view = Self.given()

            try view.keyDown(with: #require(Self.key("\u{F701}", [.option, .numericPad, .function])))
            #expect(view.controller.model.current == 1)
            try view.keyDown(with: #require(Self.key("\u{F700}", [.option, .numericPad, .function])))
            #expect(view.controller.model.current == 0)
            try view.keyDown(with: #require(Self.key("\u{F702}", [.command, .option, .numericPad, .function])))
            #expect(view.controller.model.choice(0) == .mine)
            try view.keyDown(with: #require(Self.key("\u{F703}", [.command, .option, .numericPad, .function])))
            #expect(view.controller.model.choice(1) == .theirs)
            try view.keyDown(with: #require(Self.key("b", [.command, .option])))
            #expect(view.controller.model.choice(1) == .both)
            #expect(view.acceptsFirstResponder)
            #expect(view.changeRows[1].isCurrent)
        }
    }
#endif
