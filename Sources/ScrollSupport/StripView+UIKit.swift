#if os(iOS)
    import UIKit

    /// One strip under the nav bar (screens §3.12, §3.13, §3.21): an icon,
    /// a line, and its buttons. VoiceOver reads it as one group.
    @MainActor
    final class StripView: UIStackView {
        enum Kind: Equatable {
            case deleted
            case readOnly
            case saveFailed
        }

        let kind: Kind
        let buttons: [UIButton]

        init(kind: Kind, text: String, buttons: [(title: String, run: () -> Void)]) {
            self.kind = kind
            self.buttons = buttons.map { button in
                var plain = UIButton.Configuration.plain()
                plain.title = button.title
                return UIButton(configuration: plain, primaryAction: UIAction { _ in button.run() })
            }
            super.init(frame: .zero)
            let icon = UIImageView(image: UIImage(systemName: "info.circle"))
            icon.setContentHuggingPriority(.required, for: .horizontal)
            let label = UILabel()
            label.text = text
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            for view in [icon, label] + self.buttons {
                addArrangedSubview(view)
            }
            spacing = 8
            alignment = .center
            isLayoutMarginsRelativeArrangement = true
            directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            backgroundColor = .secondarySystemBackground
            accessibilityContainerType = .semanticGroup
            accessibilityLabel = text
        }

        @available(*, unavailable)
        required init(coder _: NSCoder) {
            fatalError("unused") // coverage:ignore - never made from a nib
        }
    }
#endif
