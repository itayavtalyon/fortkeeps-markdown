#if canImport(UIKit)
    import MarkdownCore
    @testable import MarkdownViews
    import Testing
    import UIKit

    /// Screens §3.11 and §3.20: the iOS compare view.
    @MainActor
    struct ResolveViewIOSTests {
        static func given() -> ResolveView {
            let view = ResolveView(
                mine: "a\nmine\nb\nc\nd\nmine 2\n",
                theirs: "a\ntheirs\nb\nc\nd\ntheirs 2\n",
                mineTitle: "Your Changes",
                theirsTitle: "On Disk"
            )
            view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
            view.layoutIfNeeded()
            return view
        }

        @Test
        func `each change shows both versions, its state, and its three buttons`() throws {
            let view = Self.given()

            let row = try #require(view.changeRows.first)
            #expect(row.panes.map(\.title) == ["Your Changes", "On Disk"])
            #expect(row.panes.map(\.text) == ["mine", "theirs"])
            #expect(row.stateLabel.text == "Not resolved")
            #expect(row.buttons.map(\.configuration?.title) == ["Use mine", "Use theirs", "Use both"])
            #expect(row.accessibilityContainerType == .semanticGroup)
            #expect(row.accessibilityLabel == "Change 1 of 2, not resolved. Mine: mine. Theirs: theirs.")
            #expect(row.accessibilityCustomActions?.map(\.name) == ["Use mine", "Use theirs", "Use both"])
        }

        @Test
        func `the buttons resolve the changes, and Apply sends the merged text once all are resolved`() throws {
            let view = Self.given()
            var applied: [String] = []
            var cancels = 0
            view.onApply = { applied.append($0) }
            view.onCancel = { cancels += 1 }
            #expect(view.countLabel.text == "0 of 2 resolved")
            #expect(!view.applyButton.isEnabled)

            view.changeRows[0].buttons[1].sendActions(for: .primaryActionTriggered)
            let action = try #require(view.changeRows[1].accessibilityCustomActions?[0])
            _ = action.actionHandler?(action)

            #expect(view.changeRows[0].stateLabel.text == "✓ Theirs")
            #expect(view.countLabel.text == "2 of 2 resolved")
            view.applyButton.sendActions(for: .primaryActionTriggered)
            view.cancelButton.sendActions(for: .primaryActionTriggered)
            #expect(applied == ["a\ntheirs\nb\nc\nd\nmine 2\n"])
            #expect(cancels == 1)
        }

        @Test
        func `each unchanged run is collapsed until Show`() throws {
            let view = Self.given()

            let run = try #require(view.unchangedRows.first { $0.lines == 3 })
            #expect(run.summary.text == "3 unchanged lines")
            #expect(run.text.isHidden)
            run.showButton.sendActions(for: .primaryActionTriggered)
            #expect(!run.text.isHidden)
            #expect(run.showButton.isHidden)
        }

        @Test
        func `the panes stack unless the width is regular and the text size is not an accessibility size`() {
            #expect(!ResolveView.sideBySide(UITraitCollection(horizontalSizeClass: .compact)))
            #expect(ResolveView.sideBySide(UITraitCollection(horizontalSizeClass: .regular)))
            #expect(!ResolveView.sideBySide(UITraitCollection { traits in
                traits.horizontalSizeClass = .regular
                traits.preferredContentSizeCategory = .accessibilityLarge
            }))
            #expect(Self.given().changeRows[0].panesStack.axis == .vertical)
        }

        @Test
        func `the hardware keys move, choose, apply, and cancel`() throws {
            let view = Self.given()
            var cancels = 0
            view.onCancel = { cancels += 1 }
            let commands = try #require(view.keyCommands)
            #expect(commands.map(\.input) == [
                UIKeyCommand.inputDownArrow, UIKeyCommand.inputUpArrow, UIKeyCommand.inputLeftArrow,
                UIKeyCommand.inputRightArrow, "b", "\r", UIKeyCommand.inputEscape, "z"
            ])
            #expect(commands.map(\.modifierFlags) == [
                .alternate, .alternate, [.command, .alternate], [.command, .alternate], [.command, .alternate],
                [], [], .command
            ])
            #expect(view.canBecomeFirstResponder)

            view.handle(commands[0])
            #expect(view.controller.model.current == 1)
            view.handle(commands[1])
            view.handle(commands[2])
            view.handle(commands[3])
            view.handle(commands[4])
            #expect(view.controller.model.choice(0) == .mine)
            #expect(view.controller.model.choice(1) == .both)
            view.handle(commands[6])
            #expect(cancels == 1)
            #expect(view.changeRows[1].isCurrent)
            #expect(view.changeRows.map(\.layer.borderWidth) == [0, 2])
            view.handle(commands[7])
            #expect(view.controller.model.choice(1) == .theirs)
        }

        /// The keys work as soon as a host shows the view.
        @Test
        func `the view takes the keys when it joins a window`() {
            let view = Self.given()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            window.addSubview(view)

            #expect(view.isFirstResponder)
        }
    }
#endif
