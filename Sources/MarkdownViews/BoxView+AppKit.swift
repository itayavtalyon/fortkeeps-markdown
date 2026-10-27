#if os(macOS)
    import AppKit
    import MarkdownCore

    /// A rendered box wider than the column: it covers the box's clipped
    /// lines and scrolls them sideways (design log 001 › Boxes).
    final class BoxView: NSScrollView {
        /// The fade at an edge that has hidden content.
        static let fadeWidth: CGFloat = 16

        let mark: BoxMark
        /// The box's characters in the document.
        private(set) var range: Range<Int>
        let textView = NSTextView(usingTextLayoutManager: true)
        private let leadingFade = CAGradientLayer()
        private let trailingFade = CAGradientLayer()

        init(mark: BoxMark) {
            self.mark = mark
            range = 0 ..< 0
            super.init(frame: .zero)
            hasHorizontalScroller = true
            hasVerticalScroller = false
            autohidesScrollers = true
            horizontalScrollElasticity = .none
            verticalScrollElasticity = .none
            drawsBackground = true
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = false
            textView.textContainer?.widthTracksTextView = false
            textView.textContainerInset = .zero
            documentView = textView
            wantsLayer = true
            for fade in [leadingFade, trailingFade] {
                fade.startPoint = CGPoint(x: 0, y: 0.5)
                fade.endPoint = CGPoint(x: 1, y: 0.5)
                layer?.addSublayer(fade)
            }
            contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: contentView
            )
            setAccessibilityRole(.group)
            setAccessibilityRoleDescription(mark.kind == .code
                ? String(localized: "box.code", defaultValue: "code block", bundle: resourceBundle)
                : String(localized: "box.table", defaultValue: "table", bundle: resourceBundle))
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// Shows the box's characters at its laid-out frame. `padding` is the
        /// main text view's line fragment padding, so the lines stay in place.
        func update(
            content: NSAttributedString,
            geometry: NSTextLayoutManager.BoxGeometry,
            origin: CGPoint,
            padding: CGFloat
        ) {
            range = geometry.range
            frame = geometry.frame.offsetBy(dx: origin.x, dy: origin.y)
            backgroundColor = MarkdownTheme.color(mark.kind == .code ? .pill : .pane)
            textView.textContainer?.lineFragmentPadding = padding
            textView.textContainer?.size = CGSize(
                width: geometry.contentWidth + 2 * padding,
                height: .greatestFiniteMagnitude
            )
            if textView.textStorage?.isEqual(to: content) != true {
                textView.textStorage?.setAttributedString(content)
            }
            textView.frame = CGRect(x: 0, y: 0, width: geometry.contentWidth + 2 * padding, height: frame.height)
            scrolled()
        }

        /// Scrolls sideways by a step; Left Arrow and Right Arrow use it.
        func scroll(by step: CGFloat) {
            let maxX = max(0, textView.frame.width - contentView.bounds.width)
            let x = min(maxX, max(0, contentView.bounds.minX + step))
            contentView.scroll(to: CGPoint(x: x, y: 0))
            reflectScrolledClipView(contentView)
        }

        var scrollOffset: CGFloat {
            contentView.bounds.minX
        }

        /// A fade on each edge with hidden content; a 1 pt `line2` edge under Increase Contrast.
        @objc private func scrolled() {
            let hiddenBefore = contentView.bounds.minX > 0.5
            let hiddenAfter = contentView.bounds.maxX < textView.frame.width - 0.5
            let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            let background = (backgroundColor.usingColorSpace(.sRGB) ?? backgroundColor).cgColor
            let width = contrast ? 1 : Self.fadeWidth
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            leadingFade.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
            trailingFade.frame = CGRect(x: bounds.width - width, y: 0, width: width, height: bounds.height)
            if contrast {
                let line = MarkdownTheme.color(.line2).cgColor
                leadingFade.colors = [line, line]
                trailingFade.colors = [line, line]
            } else {
                leadingFade.colors = [background, background.copy(alpha: 0) ?? background]
                trailingFade.colors = [background.copy(alpha: 0) ?? background, background]
            }
            leadingFade.isHidden = !hiddenBefore
            trailingFade.isHidden = !hiddenAfter
            CATransaction.commit()
        }

        /// A vertical wheel without Shift scrolls the document, not the box.
        override func scrollWheel(with event: NSEvent) {
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                nextResponder?.scrollWheel(with: event)
            } else {
                super.scrollWheel(with: event)
            }
        }
    }

    extension MarkdownView {
        /// Places a box view over each laid-out box wider than the column, in rendered mode.
        func updateBoxes() {
            guard controller.mode == .rendered, let layout = textView.textLayoutManager,
                  let start = layout.location(at: firstVisibleOffset),
                  let end = layout.location(at: min(display.storage.length, lastVisibleOffset + 1)),
                  let range = NSTextRange(location: start, end: end)
            else {
                boxViews.values.forEach { $0.removeFromSuperview() }
                boxViews = [:]
                return
            }
            let wide = layout.boxes(in: range).filter { $0.contentWidth > $0.frame.width + 0.5 }
            for (id, view) in boxViews where !wide.contains(where: { $0.mark.id == id }) {
                view.removeFromSuperview()
                boxViews[id] = nil
            }
            for geometry in wide {
                let view = boxViews[geometry.mark.id] ?? BoxView(mark: geometry.mark)
                boxViews[geometry.mark.id] = view
                if view.superview == nil {
                    textView.addSubview(view)
                }
                let content = display.storage.attributedSubstring(from: NSRange(geometry.range))
                view.update(content: content, geometry: geometry, origin: textView.textContainerOrigin, padding: 0)
            }
            mirrorSelection()
        }

        /// The main selection shows inside each box view too.
        func mirrorSelection() {
            let selection = controller.selection
            for view in boxViews.values {
                let lower = max(selection.lowerBound, view.range.lowerBound)
                let upper = min(selection.upperBound, view.range.upperBound)
                let local = lower < upper ? NSRange(location: lower - view.range.lowerBound, length: upper - lower)
                    : NSRange(location: 0, length: 0)
                view.textView.setSelectedRange(local)
            }
        }

        /// The first character of the line fragment at the bottom of the view.
        var lastVisibleOffset: Int {
            guard let layout = textView.textLayoutManager else { return 0 }
            return layout.firstOffset(atY: textView.visibleRect.maxY - textView.textContainerOrigin.y)
        }
    }
#endif
