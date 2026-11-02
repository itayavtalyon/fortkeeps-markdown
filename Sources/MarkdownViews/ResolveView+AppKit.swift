#if os(macOS)
    import AppKit
    import MarkdownCore

    /// The compare view (screens §3.11, design log 004 › Outside changes): the
    /// changes between the host's text and another version, each with Use
    /// Mine, Use Theirs, and Use Both, then Apply. Fortkeeps Scroll shows it in
    /// place of the document; Fortkeeps can host it for its own conflicts.
    @MainActor
    public final class ResolveView: NSView {
        /// Side by side from this width; stacked below it (screens §3.11).
        static let sideBySideWidth: CGFloat = 640

        let controller: ResolveController
        private(set) var changeRows: [ResolveChangeRow] = []
        private(set) var unchangedRows: [ResolveUnchangedRow] = []
        let countLabel = NSTextField(labelWithString: "")
        let applyButton = NSButton(title: ResolveStrings.apply, target: nil, action: nil)
        let cancelButton = NSButton(title: ResolveStrings.cancel, target: nil, action: nil)

        /// The merged text, once every change is resolved.
        public var onApply: ((String) -> Void)? {
            get { controller.onApply }
            set { controller.onApply = newValue }
        }

        /// Cancel or Esc: nothing is applied.
        public var onCancel: (() -> Void)? {
            get { controller.onCancel }
            set { controller.onCancel = newValue }
        }

        /// `mine` is the host's text; the column titles are the host's words.
        public init(mine: String, theirs: String, mineTitle: String, theirsTitle: String) {
            controller = ResolveController(mine: mine, theirs: theirs)
            super.init(frame: .zero)
            let list = makeList(titles: [mineTitle, theirsTitle])
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.drawsBackground = false
            let clip = FlippedClipView()
            clip.drawsBackground = false
            scroll.contentView = clip
            scroll.documentView = list
            list.translatesAutoresizingMaskIntoConstraints = false
            list.widthAnchor.constraint(equalTo: clip.widthAnchor).isActive = true

            applyButton.keyEquivalent = "\r"
            applyButton.target = self
            applyButton.action = #selector(applyClicked)
            cancelButton.keyEquivalent = "\u{1b}"
            cancelButton.target = self
            cancelButton.action = #selector(cancelClicked)
            let bar = NSStackView(views: [countLabel, NSView(), cancelButton, applyButton])
            bar.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

            let stack = NSStackView(views: [scroll, bar])
            stack.orientation = .vertical
            stack.spacing = 0
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),
                scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
                bar.widthAnchor.constraint(equalTo: stack.widthAnchor)
            ])
            controller.onChange = { [weak self] in self?.update() }
            controller.onAnnouncement = { [weak self] message in
                guard let self else { return }
                NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
                    .announcement: message,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue
                ])
            }
            update()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// The changes and the unchanged runs, in order.
        private func makeList(titles: [String]) -> NSStackView {
            let list = NSStackView()
            list.orientation = .vertical
            list.alignment = .leading
            list.spacing = 12
            list.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            for row in controller.model.rows {
                switch row {
                case let .unchanged(text, lines):
                    let view = ResolveUnchangedRow(text: text, lines: lines)
                    unchangedRows.append(view)
                    list.addArrangedSubview(view)
                case let .change(index):
                    let view = ResolveChangeRow(index: index, controller: controller, titles: titles)
                    changeRows.append(view)
                    list.addArrangedSubview(view)
                }
            }
            for view in list.arrangedSubviews {
                view.widthAnchor.constraint(equalTo: list.widthAnchor, constant: -32).isActive = true
            }
            return list
        }

        private func update() {
            countLabel.stringValue = controller.count
            applyButton.isEnabled = controller.canApply
            for row in changeRows {
                row.update()
            }
        }

        override public func layout() {
            super.layout()
            let sideBySide = bounds.width >= Self.sideBySideWidth
            for row in changeRows {
                row.panesStack.orientation = sideBySide ? .horizontal : .vertical
            }
        }

        @objc private func applyClicked() {
            controller.apply()
        }

        @objc private func cancelClicked() {
            controller.onCancel?()
        }

        // MARK: keys (screens §3.11)

        override public var acceptsFirstResponder: Bool {
            true
        }

        /// Edit › Undo while the view has the keys: the last choice.
        @objc func undo(_: Any?) {
            _ = controller.handleKey(.undo)
        }

        override public func keyDown(with event: NSEvent) {
            guard let key = Self.key(for: event), controller.handleKey(key) else {
                super.keyDown(with: event)
                return
            }
        }

        /// Option-Down and Option-Up; Command-Option-Left, Right, and B.
        static func key(for event: NSEvent) -> ResolveController.Key? {
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let character = event.charactersIgnoringModifiers ?? ""
            let keys: [String: ResolveController.Key] = switch flags {
            case [.option]: ["\u{F701}": .next, "\u{F700}": .previous]
            case [.command, .option]: ["\u{F702}": .mine, "\u{F703}": .theirs, "b": .both]
            default: [:]
            }
            return keys[character]
        }
    }

    extension ResolveView: NSUserInterfaceValidations {
        public func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
            item.action == NSSelectorFromString("undo:") ? controller.model.canUndoChoice : true
        }
    }

    /// One change: its state, the two versions, and its three buttons.
    /// VoiceOver reads it as one group with the choices as actions.
    @MainActor
    final class ResolveChangeRow: NSStackView {
        struct Pane {
            let title: String
            let text: String
        }

        let index: Int
        private unowned let controller: ResolveController
        let stateLabel = NSTextField(labelWithString: "")
        let panesStack = NSStackView()
        let panes: [Pane]
        private(set) var buttons: [NSButton] = []
        private(set) var isCurrent = false

        init(index: Int, controller: ResolveController, titles: [String]) {
            self.index = index
            self.controller = controller
            panes = zip(titles, [controller.model.mine(index), controller.model.theirs(index)])
                .map { Pane(title: $0, text: $1) }
            super.init(frame: .zero)
            orientation = .vertical
            alignment = .leading
            edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            wantsLayer = true
            layer?.cornerRadius = 6
            panesStack.distribution = .fillEqually
            panesStack.alignment = .top
            for pane in panes {
                let title = NSTextField(labelWithString: pane.title)
                title.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
                let text = NSTextField(wrappingLabelWithString: pane.text)
                text.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                let column = NSStackView(views: [title, text])
                column.orientation = .vertical
                column.alignment = .leading
                panesStack.addArrangedSubview(column)
            }
            buttons = zip(ResolveStrings.choiceTitles, ResolveStrings.choices).map { title, choice in
                let button = NSButton(title: title, target: nil, action: nil)
                button.target = self
                button.action = #selector(choose(_:))
                button.tag = ResolveStrings.choices.firstIndex(of: choice) ?? 0
                return button
            }
            for view in [stateLabel, panesStack, NSStackView(views: buttons)] {
                addArrangedSubview(view)
            }
            panesStack.widthAnchor.constraint(equalTo: widthAnchor, constant: -16).isActive = true
            setAccessibilityElement(true)
            setAccessibilityRole(.group)
            let actions = zip(ResolveStrings.choiceTitles, ResolveStrings.choices).map { title, choice in
                NSAccessibilityCustomAction(name: title) { [weak self] in
                    guard let self else { return false }
                    self.controller.choose(choice, change: self.index)
                    return true
                }
            }
            setAccessibilityCustomActions(actions)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        @objc private func choose(_ sender: NSButton) {
            controller.choose(ResolveStrings.choices[sender.tag], change: index)
        }

        func update() {
            stateLabel.stringValue = controller.state(index)
            setAccessibilityLabel(controller.accessibilityLabel(index))
            isCurrent = controller.model.current == index
            // The state line says the same; color is not the only cue.
            layer?.borderWidth = isCurrent ? 2 : 0
            layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
        }
    }

    /// Lines both versions share, collapsed to their count until Show.
    @MainActor
    final class ResolveUnchangedRow: NSStackView {
        let lines: Int
        let summary: NSTextField
        let text: NSTextField
        let showButton = NSButton(title: ResolveStrings.show, target: nil, action: nil)

        init(text: String, lines: Int) {
            self.lines = lines
            summary = NSTextField(labelWithString: ResolveStrings.unchanged(lines))
            summary.textColor = .secondaryLabelColor
            self.text = NSTextField(wrappingLabelWithString: text)
            self.text.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            self.text.textColor = .secondaryLabelColor
            self.text.isHidden = true
            super.init(frame: .zero)
            orientation = .vertical
            alignment = .leading
            showButton.target = self
            showButton.action = #selector(show)
            addArrangedSubview(NSStackView(views: [summary, showButton]))
            addArrangedSubview(self.text)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        @objc private func show() {
            text.isHidden = false
            showButton.isHidden = true
        }
    }

    /// Lays the list out from the top.
    private final class FlippedClipView: NSClipView {
        override var isFlipped: Bool {
            true
        }
    }
#endif
