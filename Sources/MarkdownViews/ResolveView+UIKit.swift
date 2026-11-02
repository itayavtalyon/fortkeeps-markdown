#if os(iOS)
    import MarkdownCore
    import UIKit

    /// The compare view (screens §3.11, design log 004 › Outside changes): the
    /// changes between the host's text and another version, each with Use
    /// mine, Use theirs, and Use both, then Apply. Fortkeeps Scroll shows it full
    /// screen; Fortkeeps can host it for its own conflicts.
    @MainActor
    public final class ResolveView: UIView {
        let controller: ResolveController
        private(set) var changeRows: [ResolveChangeRow] = []
        private(set) var unchangedRows: [ResolveUnchangedRow] = []
        let countLabel = UILabel()
        let applyButton: UIButton
        let cancelButton: UIButton

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
            let controller = ResolveController(mine: mine, theirs: theirs)
            self.controller = controller
            applyButton = UIButton(configuration: .borderedProminent(), primaryAction: UIAction { _ in
                controller.apply()
            })
            applyButton.configuration?.title = ResolveStrings.apply
            cancelButton = UIButton(configuration: .bordered(), primaryAction: UIAction { _ in
                controller.onCancel?()
            })
            cancelButton.configuration?.title = ResolveStrings.cancel
            super.init(frame: .zero)
            backgroundColor = .systemBackground
            let list = makeList(titles: [mineTitle, theirsTitle])
            let scroll = UIScrollView()
            scroll.addSubview(list)
            countLabel.font = .preferredFont(forTextStyle: .footnote)
            countLabel.adjustsFontForContentSizeCategory = true
            let bar = UIStackView(arrangedSubviews: [countLabel, UIView(), cancelButton, applyButton])
            bar.spacing = 8
            bar.isLayoutMarginsRelativeArrangement = true
            bar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            for view in [scroll, bar, list] {
                view.translatesAutoresizingMaskIntoConstraints = false
            }
            addSubview(scroll)
            addSubview(bar)
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: bar.topAnchor),
                bar.leadingAnchor.constraint(equalTo: leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: trailingAnchor),
                bar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                list.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                list.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                list.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
                list.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor)
            ])
            controller.onChange = { [weak self] in self?.update() }
            controller.onAnnouncement = { UIAccessibility.post(notification: .announcement, argument: $0) }
            let traits: [UITrait] = [UITraitHorizontalSizeClass.self, UITraitPreferredContentSizeCategory.self]
            registerForTraitChanges(traits) { (view: Self, _: UITraitCollection) in view.update() }
            update()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// The changes and the unchanged runs, in order.
        private func makeList(titles: [String]) -> UIStackView {
            let list = UIStackView()
            list.axis = .vertical
            list.spacing = 12
            list.isLayoutMarginsRelativeArrangement = true
            list.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
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
            return list
        }

        /// Side by side in a regular width, stacked in a compact one or at an
        /// accessibility text size (screens §3.11).
        static func sideBySide(_ traits: UITraitCollection) -> Bool {
            traits.horizontalSizeClass == .regular && !traits.preferredContentSizeCategory.isAccessibilityCategory
        }

        private func update() {
            countLabel.text = controller.count
            applyButton.isEnabled = controller.canApply
            let axis: NSLayoutConstraint.Axis = Self.sideBySide(traitCollection) ? .horizontal : .vertical
            for row in changeRows {
                row.panesStack.axis = axis
                row.update()
            }
        }

        // MARK: keys (screens §3.11)

        override public var canBecomeFirstResponder: Bool {
            true
        }

        /// The keys work as soon as the host shows the view.
        override public func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                becomeFirstResponder()
            }
        }

        override public var keyCommands: [UIKeyCommand]? {
            let keys: [(String, UIKeyModifierFlags)] = [
                (UIKeyCommand.inputDownArrow, .alternate),
                (UIKeyCommand.inputUpArrow, .alternate),
                (UIKeyCommand.inputLeftArrow, [.command, .alternate]),
                (UIKeyCommand.inputRightArrow, [.command, .alternate]),
                ("b", [.command, .alternate]),
                ("\r", []),
                (UIKeyCommand.inputEscape, []),
                ("z", .command)
            ]
            return keys.map { UIKeyCommand(input: $0, modifierFlags: $1, action: #selector(handle)) }
        }

        @objc func handle(_ command: UIKeyCommand) {
            let keys: [String: ResolveController.Key] = [
                UIKeyCommand.inputDownArrow: .next, UIKeyCommand.inputUpArrow: .previous,
                UIKeyCommand.inputLeftArrow: .mine, UIKeyCommand.inputRightArrow: .theirs,
                "b": .both, "\r": .apply, UIKeyCommand.inputEscape: .cancel, "z": .undo
            ]
            guard let key = command.input.flatMap({ keys[$0] }) else { return } // coverage:ignore - all have a key
            _ = controller.handleKey(key)
        }
    }

    /// One change: its state, the two versions, and its three buttons.
    /// VoiceOver reads it as one group with the choices as actions.
    @MainActor
    final class ResolveChangeRow: UIStackView {
        struct Pane {
            let title: String
            let text: String
        }

        let index: Int
        private unowned let controller: ResolveController
        let stateLabel = UILabel()
        let panesStack = UIStackView()
        let panes: [Pane]
        private(set) var buttons: [UIButton] = []
        private(set) var isCurrent = false

        init(index: Int, controller: ResolveController, titles: [String]) {
            self.index = index
            self.controller = controller
            panes = zip(titles, [controller.model.mine(index), controller.model.theirs(index)])
                .map { Pane(title: $0, text: $1) }
            super.init(frame: .zero)
            axis = .vertical
            spacing = 8
            isLayoutMarginsRelativeArrangement = true
            directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            layer.cornerRadius = 8
            layer.borderColor = UIColor.tintColor.cgColor
            stateLabel.font = .preferredFont(forTextStyle: .headline)
            stateLabel.adjustsFontForContentSizeCategory = true
            panesStack.distribution = .fillEqually
            panesStack.alignment = .top
            panesStack.spacing = 8
            for pane in panes {
                panesStack.addArrangedSubview(Self.column(pane))
            }
            buttons = zip(ResolveStrings.choiceTitles, ResolveStrings.choices).map { title, choice in
                var plain = UIButton.Configuration.bordered()
                plain.title = title
                return UIButton(configuration: plain, primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    self.controller.choose(choice, change: self.index)
                })
            }
            let buttonRow = UIStackView(arrangedSubviews: buttons)
            buttonRow.spacing = 8
            buttonRow.distribution = .fillEqually
            for view in [stateLabel, panesStack, buttonRow] {
                addArrangedSubview(view)
            }
            accessibilityContainerType = .semanticGroup
            let choices = zip(ResolveStrings.choiceTitles, ResolveStrings.choices)
            accessibilityCustomActions = choices.map { title, choice in
                UIAccessibilityCustomAction(name: title) { [weak self] _ in
                    guard let self else { return false }
                    self.controller.choose(choice, change: self.index)
                    return true
                }
            }
        }

        @available(*, unavailable)
        required init(coder _: NSCoder) {
            fatalError("unused") // coverage:ignore - never made from a nib
        }

        /// One version under its title.
        private static func column(_ pane: Pane) -> UIStackView {
            let title = UILabel()
            title.text = pane.title
            title.font = .preferredFont(forTextStyle: .caption1)
            let text = UILabel()
            text.text = pane.text
            text.numberOfLines = 0
            text.font = .preferredFont(forTextStyle: .body)
            for label in [title, text] {
                label.adjustsFontForContentSizeCategory = true
            }
            let column = UIStackView(arrangedSubviews: [title, text])
            column.axis = .vertical
            return column
        }

        func update() {
            stateLabel.text = controller.state(index)
            accessibilityLabel = controller.accessibilityLabel(index)
            isCurrent = controller.model.current == index
            // The state line says the same; color is not the only cue.
            layer.borderWidth = isCurrent ? 2 : 0
        }
    }

    /// Lines both versions share, collapsed to their count until Show.
    @MainActor
    final class ResolveUnchangedRow: UIStackView {
        let lines: Int
        let summary = UILabel()
        let text = UILabel()
        let showButton: UIButton

        init(text content: String, lines: Int) {
            self.lines = lines
            var plain = UIButton.Configuration.plain()
            plain.title = ResolveStrings.show
            showButton = UIButton(configuration: plain)
            super.init(frame: .zero)
            axis = .vertical
            summary.text = ResolveStrings.unchanged(lines)
            text.text = content
            text.numberOfLines = 0
            text.isHidden = true
            for label in [summary, text] {
                label.font = .preferredFont(forTextStyle: .body)
                label.adjustsFontForContentSizeCategory = true
                label.textColor = .secondaryLabel
            }
            showButton.addAction(UIAction { [weak self] _ in
                self?.text.isHidden = false
                self?.showButton.isHidden = true
            }, for: .primaryActionTriggered)
            let header = UIStackView(arrangedSubviews: [summary, showButton, UIView()])
            header.spacing = 8
            addArrangedSubview(header)
            addArrangedSubview(text)
        }

        @available(*, unavailable)
        required init(coder _: NSCoder) {
            fatalError("unused") // coverage:ignore - never made from a nib
        }
    }
#endif
