#if canImport(UIKit)
    import MarkdownCore
    import UIKit

    /// The iOS format bar: it docks above the software keyboard, or at the
    /// window bottom with a hardware keyboard on iPad (design log 001 ›
    /// Format commands). It scrolls at large Dynamic Type sizes.
    final class FormatBarView: UIInputView {
        var onAction: ((FormatAction) -> Void)?
        private var buttons: [FormatBarButton: UIButton] = [:]

        init() {
            super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 52), inputViewStyle: .keyboard)
            allowsSelfSizing = true
            let stack = UIStackView()
            stack.spacing = 4
            for item in FormatBarButton.allCases {
                let button = UIButton(configuration: .plain())
                button.configuration?.image = UIImage(systemName: item.actions[0].symbol)
                button.accessibilityLabel = item.title
                button.showsLargeContentViewer = true
                button.largeContentTitle = item.title
                button.addInteraction(UILargeContentViewerInteraction())
                if item == .heading {
                    button.menu = UIMenu(children: item.actions.map { action in
                        UIAction(title: action.title) { [weak self] _ in self?.onAction?(action) }
                    })
                    button.showsMenuAsPrimaryAction = true
                } else {
                    button.addAction(
                        UIAction { [weak self] _ in self?.onAction?(item.actions[0]) },
                        for: .primaryActionTriggered
                    )
                }
                // 44 pt hit size.
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
                    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
                ])
                buttons[item] = button
                stack.addArrangedSubview(button)
            }
            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(stack)
            scroll.translatesAutoresizingMaskIntoConstraints = false
            addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                scroll.topAnchor.constraint(equalTo: topAnchor),
                scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -4),
                stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -8)
            ])
            accessibilityTraits = .tabBar
            accessibilityLabel = FormatBarButton.barTitle
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// A button shows its active state with a filled background and the selected trait.
        func setActive(_ isActive: (FormatAction) -> Bool) {
            for (item, button) in buttons {
                let level = item.actions.first(where: isActive)
                button.configuration?.background.backgroundColor = level == nil ? .clear : MarkdownTheme.color(.pill)
                button.accessibilityTraits = level == nil ? .button : [.button, .selected]
                button.accessibilityValue = item == .heading ? level?.title : nil
            }
        }

        /// Presses a button the way a tap does; the heading button picks one menu level.
        func press(_ action: FormatAction) {
            if FormatBarButton.heading.actions.contains(action) {
                onAction?(action)
            } else if let item = FormatBarButton.allCases.first(where: { $0.actions == [action] }) {
                buttons[item]?.sendActions(for: .primaryActionTriggered)
            }
        }
    }
#endif
