#if os(macOS)
    import AppKit
    import MarkdownCore

    /// The Mac format bar: it floats 8 pt above the selection (design log
    /// 001 › Format commands). Each button performs a `FormatAction`.
    final class FormatBarView: NSVisualEffectView {
        var onAction: ((FormatAction) -> Void)?
        /// Esc in the bar: focus goes back to the text.
        var onEscape: (() -> Void)?
        private var buttons: [FormatBarButton: NSButton] = [:]
        private let headingMenu = NSMenu()

        init() {
            super.init(frame: .zero)
            material = .popover
            state = .active
            wantsLayer = true
            layer?.cornerRadius = 8
            let stack = NSStackView()
            stack.spacing = 2
            stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
            for item in FormatBarButton.allCases {
                let button = BarButton(
                    image: NSImage(systemSymbolName: item.actions[0].symbol, accessibilityDescription: item.title)
                        ?? NSImage(),
                    target: self,
                    action: #selector(pressed(_:))
                )
                button.setButtonType(.pushOnPushOff)
                button.bezelStyle = .accessoryBar
                button.tag = FormatBarButton.allCases.firstIndex(of: item) ?? 0
                button.setAccessibilityLabel(item.title)
                let shortcut = Self.display(item.actions[0].shortcut)
                button.toolTip = item == .heading ? item.title : "\(item.title) \(shortcut)"
                buttons[item] = button
                stack.addArrangedSubview(button)
            }
            for action in FormatBarButton.heading.actions {
                let item = NSMenuItem(title: action.title, action: #selector(choose(_:)), keyEquivalent: "")
                item.target = self
                item.tag = FormatAction.allCases.firstIndex(of: action) ?? 0
                headingMenu.addItem(item)
            }
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            setAccessibilityRole(.toolbar)
            setAccessibilityLabel(FormatBarButton.barTitle)
            setFrameSize(fittingSize)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        var firstButton: NSButton? {
            FormatBarButton.allCases.first.flatMap { buttons[$0] }
        }

        /// Left Arrow and Right Arrow move between the buttons; Esc goes back to the text.
        override func keyDown(with event: NSEvent) {
            let order = FormatBarButton.allCases.compactMap { buttons[$0] }
            let current = order.firstIndex { window?.firstResponder === $0 }
            switch event.keyCode {
            case 123, 124:
                let step = event.keyCode == 123 ? -1 : 1
                let next = ((current ?? 0) + step + order.count) % order.count
                window?.makeFirstResponder(order[next])
            case 53:
                onEscape?()
            default:
                super.keyDown(with: event)
            }
        }

        /// `⌘B`, `⇧⌘C`, `⌥⌘1`: the shortcut as the tooltip shows it.
        static func display(_ shortcut: FormatShortcut) -> String {
            let modifiers = (shortcut.modifiers.contains(.option) ? "⌥" : "")
                + (shortcut.modifiers.contains(.shift) ? "⇧" : "") + "⌘"
            return modifiers + (shortcut.key == "\r" ? "↩" : shortcut.key.uppercased())
        }

        /// A button shows its active state with a filled background and the selected trait.
        func setActive(_ isActive: (FormatAction) -> Bool) {
            for (item, button) in buttons {
                let active = item.actions.contains(where: isActive)
                button.state = active ? .on : .off
                button.setAccessibilitySelected(active)
                if item == .heading {
                    let level = item.actions.first(where: isActive)
                    button.setAccessibilityValue(level.map(\.title))
                }
            }
        }

        /// Presses a button the way a click does; the heading button presses one menu level.
        func press(_ action: FormatAction) {
            if FormatBarButton.heading.actions.contains(action) {
                let index = headingMenu.indexOfItem(withTag: FormatAction.allCases.firstIndex(of: action) ?? 0)
                headingMenu.performActionForItem(at: index)
            } else if let item = FormatBarButton.allCases.first(where: { $0.actions == [action] }) {
                buttons[item]?.performClick(nil)
            }
        }

        @objc private func pressed(_ sender: NSButton) {
            let item = FormatBarButton.allCases[sender.tag]
            // A click flips a push-on-push-off state; the selection sets it again.
            sender.state = sender.state == .on ? .off : .on
            if item == .heading {
                headingMenu.popUp(positioning: nil, at: CGPoint(x: 0, y: sender.bounds.height + 4), in: sender)
            } else {
                onAction?(item.actions[0])
            }
        }

        @objc private func choose(_ sender: NSMenuItem) {
            onAction?(FormatAction.allCases[sender.tag])
        }
    }

    /// A bar button that takes keyboard focus without Full Keyboard Access.
    final class BarButton: NSButton {
        override var acceptsFirstResponder: Bool {
            true
        }

        override var canBecomeKeyView: Bool {
            true
        }
    }
#endif
