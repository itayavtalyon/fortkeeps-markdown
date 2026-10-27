#if os(macOS)
    import AppKit
    import MarkdownCore

    /// The Mac view of one image: the image, a card per `ImageResult`, or the
    /// `Image: {alt}` link (design log 001 › Images).
    final class ImageCardView: NSView {
        private let attachment: ImageAttachment
        private var imageView: NSImageView?
        private var playGlyph: NSImageView?

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
            setAccessibilityElement(content.isAccessibilityElement)
            setAccessibilityHelp(content.accessibilityHint)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private func pin(_ view: NSView) {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        private func buildImage(_ data: Data) {
            let imageView = NSImageView(image: NSImage(data: data) ?? NSImage())
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.animates = attachment.animating
            imageView.setAccessibilityElement(false)
            pin(imageView)
            self.imageView = imageView
            setAccessibilityRole(.image)
            setAccessibilityLabel(attachment.content.title)
            // A gif under Reduce Motion shows frame 1 with a play glyph.
            if data.starts(with: Array("GIF8".utf8)), !attachment.animating {
                let glyph = NSImageView(image: NSImage(
                    systemSymbolName: "play.circle.fill",
                    accessibilityDescription: nil
                )
                    ?? NSImage())
                glyph.frame = CGRect(x: 8, y: 8, width: 28, height: 28)
                addSubview(glyph)
                playGlyph = glyph
                setAccessibilityCustomActions([NSAccessibilityCustomAction(name: Strings.play) { [weak self] in
                    self?.play()
                    return true
                }])
            }
        }

        func play() {
            imageView?.animates = true
            playGlyph?.removeFromSuperview()
        }

        private func buildCard(_ content: ImageCardContent) {
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.backgroundColor = MarkdownTheme.color(.pill).cgColor
            let glyph =
                NSImageView(image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil) ?? NSImage())
            glyph.contentTintColor = MarkdownTheme.color(.text3)
            let title = NSTextField(labelWithString: content.title)
            title.textColor = MarkdownTheme.color(.text)
            let texts = NSStackView(views: [title])
            texts.orientation = .vertical
            texts.alignment = .leading
            texts.spacing = 2
            for line in content.lines {
                let label = NSTextField(labelWithString: line)
                label.textColor = MarkdownTheme.color(.text3)
                label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
                texts.addArrangedSubview(label)
            }
            let row = NSStackView(views: [glyph, texts])
            row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            row.spacing = 10
            if content.showsProgress {
                let progress = NSProgressIndicator()
                progress.style = .spinning
                progress.controlSize = .small
                // Static under Reduce Motion.
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    progress.startAnimation(nil)
                }
                row.addArrangedSubview(progress)
            }
            if let button = content.button {
                row.addArrangedSubview(NSButton(title: button, target: self, action: #selector(activate)))
                setAccessibilityRole(.button)
            } else {
                setAccessibilityRole(.group)
            }
            pin(row)
            setAccessibilityLabel(content.accessibilityLabel)
        }

        private func buildLink(_ content: ImageCardContent) {
            let button = NSButton(title: content.title, target: self, action: #selector(openLink))
            button.isBordered = false
            button.font = attachment.linkFont
            button.contentTintColor = MarkdownTheme.color(.accent)
            button.attributedTitle = NSAttributedString(string: content.title, attributes: [
                .font: attachment.linkFont, .foregroundColor: MarkdownTheme.color(.accent)
            ])
            button.setAccessibilityRole(.link)
            pin(button)
            setAccessibilityElement(false)
        }

        override func mouseDown(with event: NSEvent) {
            if attachment.content.activates {
                activate()
            } else {
                super.mouseDown(with: event)
            }
        }

        override func accessibilityPerformPress() -> Bool {
            guard attachment.content.activates else { return false }
            activate()
            return true
        }

        /// The person activated this card: consent the host receives.
        @objc func activate() {
            attachment.owner?.controller.activateImage(destination: attachment.destination)
        }

        @objc func openLink() {
            attachment.owner?.controller.openImageLink(
                attachment.index,
                modifiers: LinkModifiers(NSEvent.modifierFlags)
            )
        }
    }

    extension LinkModifiers {
        init(_ flags: NSEvent.ModifierFlags) {
            self = []
            if flags.contains(.command) {
                insert(.command)
            }
            if flags.contains(.option) {
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
