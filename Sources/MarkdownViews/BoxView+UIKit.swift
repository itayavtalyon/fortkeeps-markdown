#if canImport(UIKit)
    import MarkdownCore
    import UIKit

    /// A rendered box wider than the column: it covers the box's clipped
    /// lines and scrolls them sideways (design log 001 › Boxes).
    final class BoxView: UIScrollView, UIScrollViewDelegate {
        /// The fade at an edge that has hidden content.
        static let fadeWidth: CGFloat = 16

        let mark: BoxMark
        /// The box's characters in the document.
        private(set) var range: Range<Int>
        let textView = UITextView(usingTextLayoutManager: true)
        private let leadingFade = CAGradientLayer()
        private let trailingFade = CAGradientLayer()

        init(mark: BoxMark) {
            self.mark = mark
            range = 0 ..< 0
            super.init(frame: .zero)
            delegate = self
            showsVerticalScrollIndicator = false
            alwaysBounceVertical = false
            bounces = false
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = false
            textView.backgroundColor = .clear
            textView.textContainerInset = .zero
            textView.textContainer.widthTracksTextView = false
            textView.textContainer.lineFragmentPadding = 0
            addSubview(textView)
            for fade in [leadingFade, trailingFade] {
                fade.startPoint = CGPoint(x: 0, y: 0.5)
                fade.endPoint = CGPoint(x: 1, y: 0.5)
                layer.addSublayer(fade)
            }
            accessibilityLabel = mark.kind == .code
                ? String(localized: "box.code", defaultValue: "code block", bundle: resourceBundle)
                : String(localized: "box.table", defaultValue: "table", bundle: resourceBundle)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// Shows the box's characters at its laid-out frame.
        func update(content: NSAttributedString, geometry: NSTextLayoutManager.BoxGeometry, origin: CGPoint) {
            range = geometry.range
            frame = geometry.frame.offsetBy(dx: origin.x, dy: origin.y)
            backgroundColor = MarkdownTheme.color(mark.kind == .code ? .pill : .pane)
            let width = geometry.contentWidth
            textView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
            if !textView.textStorage.isEqual(to: content) {
                textView.textStorage.setAttributedString(content)
            }
            textView.frame = CGRect(x: 0, y: 0, width: width, height: frame.height)
            contentSize = CGSize(width: width, height: frame.height)
            scrollViewDidScroll(self)
        }

        /// Scrolls sideways by a step; Left Arrow and Right Arrow use it.
        func scroll(by step: CGFloat) {
            let maxX = max(0, contentSize.width - bounds.width)
            contentOffset = CGPoint(x: min(maxX, max(0, contentOffset.x + step)), y: 0)
        }

        var scrollOffset: CGFloat {
            contentOffset.x
        }

        /// A fade on each edge with hidden content; a 1 pt `line2` edge under Increase Contrast.
        func scrollViewDidScroll(_: UIScrollView) {
            let contrast = traitCollection.accessibilityContrast == .high
            let background = (backgroundColor ?? .clear).resolvedColor(with: traitCollection).cgColor
            let width = contrast ? 1 : Self.fadeWidth
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            leadingFade.frame = CGRect(x: contentOffset.x, y: 0, width: width, height: bounds.height)
            trailingFade.frame = CGRect(
                x: contentOffset.x + bounds.width - width,
                y: 0,
                width: width,
                height: bounds.height
            )
            if contrast {
                let line = MarkdownTheme.color(.line2).resolvedColor(with: traitCollection).cgColor
                leadingFade.colors = [line, line]
                trailingFade.colors = [line, line]
            } else {
                leadingFade.colors = [background, background.copy(alpha: 0) ?? background]
                trailingFade.colors = [background.copy(alpha: 0) ?? background, background]
            }
            leadingFade.isHidden = contentOffset.x <= 0.5
            trailingFade.isHidden = contentOffset.x + bounds.width >= contentSize.width - 0.5
            CATransaction.commit()
        }
    }
#endif
