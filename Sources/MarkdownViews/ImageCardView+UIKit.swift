#if canImport(UIKit)
    import ImageIO
    import MarkdownCore
    import UIKit

    /// The iOS view of one image: the image, a card per `ImageResult`, or the
    /// `Image: {alt}` link (design log 001 › Images).
    final class ImageCardView: UIView {
        private let attachment: ImageAttachment
        private var imageView: UIImageView?
        private var playGlyph: UIImageView?
        private var data: Data?

        init(attachment: ImageAttachment) {
            self.attachment = attachment
            super.init(frame: CGRect(origin: .zero, size: attachment.size(lineWidth: 10000)))
            let content = attachment.content
            switch content.kind {
            case let .image(data):
                buildImage(data)
            case .card:
                buildCard(content)
            case .link:
                buildLink(content)
            }
            isAccessibilityElement = content.isAccessibilityElement && content.kind != .link
            accessibilityHint = content.accessibilityHint
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private func pin(_ view: UIView) {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        /// A gif plays as an animated image; otherwise the first frame.
        static func image(_ data: Data, animating: Bool) -> UIImage? {
            guard animating, let source = CGImageSourceCreateWithData(data as CFData, nil),
                  CGImageSourceGetCount(source) > 1
            else { return UIImage(data: data) }
            let count = CGImageSourceGetCount(source)
            let frames = (0 ..< count).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }.map(UIImage.init)
            return UIImage.animatedImage(with: frames, duration: Double(count) / 10)
        }

        private func buildImage(_ data: Data) {
            self.data = data
            let imageView = UIImageView(image: Self.image(data, animating: attachment.animating))
            imageView.contentMode = .scaleAspectFit
            pin(imageView)
            self.imageView = imageView
            accessibilityTraits = .image
            accessibilityLabel = attachment.content.title
            // A gif under Reduce Motion shows frame 1 with a play glyph.
            if data.starts(with: Array("GIF8".utf8)), !attachment.animating {
                let glyph = UIImageView(image: UIImage(systemName: "play.circle.fill"))
                glyph.frame = CGRect(x: 8, y: 8, width: 28, height: 28)
                addSubview(glyph)
                playGlyph = glyph
                accessibilityCustomActions = [UIAccessibilityCustomAction(name: Strings.play) { [weak self] _ in
                    self?.play()
                    return true
                }]
            }
        }

        func play() {
            guard let data else { return }
            imageView?.image = Self.image(data, animating: true)
            playGlyph?.removeFromSuperview()
        }

        private func buildCard(_ content: ImageCardContent) {
            layer.cornerRadius = 8
            backgroundColor = MarkdownTheme.color(.pill)
            let glyph = UIImageView(image: UIImage(systemName: "photo"))
            glyph.tintColor = MarkdownTheme.color(.text3)
            let title = UILabel()
            title.text = content.title
            title.textColor = MarkdownTheme.color(.text)
            title.font = .preferredFont(forTextStyle: .body)
            title.adjustsFontForContentSizeCategory = true
            let texts = UIStackView(arrangedSubviews: [title])
            texts.axis = .vertical
            texts.spacing = 2
            for line in content.lines {
                let label = UILabel()
                label.text = line
                label.textColor = MarkdownTheme.color(.text3)
                label.font = .preferredFont(forTextStyle: .footnote)
                label.adjustsFontForContentSizeCategory = true
                texts.addArrangedSubview(label)
            }
            let row = UIStackView(arrangedSubviews: [glyph, texts])
            row.spacing = 10
            row.alignment = .center
            row.isLayoutMarginsRelativeArrangement = true
            row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            if content.showsProgress {
                let progress = UIActivityIndicatorView(style: .medium)
                // Static under Reduce Motion.
                if !UIAccessibility.isReduceMotionEnabled {
                    progress.startAnimating()
                }
                row.addArrangedSubview(progress)
            }
            if let button = content.button {
                let action = UIAction(title: button) { [weak self] _ in self?.activate() }
                let control = UIButton(configuration: .plain(), primaryAction: action)
                control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                row.addArrangedSubview(control)
                accessibilityTraits = .button
                addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(activate)))
            }
            pin(row)
            accessibilityLabel = content.accessibilityLabel
        }

        private func buildLink(_ content: ImageCardContent) {
            let action = UIAction { [weak self] _ in self?.openLink() }
            let button = UIButton(primaryAction: action)
            button.setAttributedTitle(NSAttributedString(string: content.title, attributes: [
                .font: attachment.linkFont, .foregroundColor: MarkdownTheme.color(.accent)
            ]), for: .normal)
            button.accessibilityTraits = .link
            pin(button)
        }

        override func accessibilityActivate() -> Bool {
            guard attachment.content.activates else { return false }
            activate()
            return true
        }

        /// The person activated this card: consent the host receives.
        @objc func activate() {
            attachment.owner?.controller.activateImage(destination: attachment.destination)
        }

        private func openLink() {
            attachment.owner?.controller.openImageLink(attachment.index, modifiers: [])
        }
    }

    extension LinkModifiers {
        init(_ flags: UIKeyModifierFlags) {
            self = []
            if flags.contains(.command) {
                insert(.command)
            }
            if flags.contains(.alternate) {
                insert(.option)
            }
            if flags.contains(.shift) {
                insert(.shift)
            }
            if flags.contains(.control) {
                insert(.control)
            }
        }
    }
#endif
