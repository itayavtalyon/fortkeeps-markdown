#if canImport(UIKit)
    import Accessibility
    import MarkdownCore
    import UIKit

    /// The iOS Markdown view: TextKit 2 with the three modes (design log 001 ›
    /// Host interface, View settings, Modes). It holds the working text; the
    /// host sets it at creation and replaces it only with `reload(text:)`.
    @MainActor
    public final class MarkdownView: UIView, UIGestureRecognizerDelegate {
        let controller: MarkdownTextController
        let textView: MarkdownUITextView
        let formatBar = FormatBarView()
        /// The box views of rendered mode, by box id.
        var boxViews: [Int: BoxView] = [:]
        /// The element keyboard focus is on, in `.rendered` and `.editorLocked`.
        var focusedTarget: FocusTarget? {
            didSet { showFocus() }
        }

        let focusRing = FocusRingView()
        let display: MarkdownDisplay
        private let layoutDelegate = MarkdownLayoutDelegate()
        /// The edit the text view is applying, from `shouldChangeTextIn` to `textViewDidChange`.
        var pendingEdit: PendingEdit?
        /// The event of the next edit when it is not typing.
        var nextEvent: UndoGrouping.Event?
        var isSyncing = false

        /// The string VoiceOver announces after a mode switch. The host supplies it.
        public var modeSwitchAnnouncement: String?

        /// The host's Show Format Bar choice.
        public var showsFormatBar = true {
            didSet { applyEditability() }
        }

        public init(
            text: String,
            features: MarkdownFeatures = MarkdownFeatures(),
            presentation: MarkdownPresentation = MarkdownPresentation(),
            mode: MarkdownMode = .editor,
            isEditable: Bool = true,
            maxUTF8Bytes: Int? = nil,
            documentURL: URL? = nil,
            host: MarkdownHost?
        ) {
            controller = MarkdownTextController(
                text: text,
                features: features,
                presentation: presentation,
                mode: mode,
                maxUTF8Bytes: maxUTF8Bytes,
                documentURL: documentURL
            )
            controller.host = host
            controller.isEditable = isEditable
            controller.reduceMotion = Self.stillImages
            textView = MarkdownUITextView(usingTextLayoutManager: true)
            display = MarkdownDisplay(controller: controller, storage: textView.textStorage)
            super.init(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
            configure()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private func configure() {
            textView.owner = self
            textView.delegate = self
            textView.textLayoutManager?.delegate = layoutDelegate
            textView.smartQuotesType = .no
            textView.smartDashesType = .no
            textView.backgroundColor = MarkdownTheme.color(.pane)
            textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
            textView.frame = bounds
            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(textView)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.delegate = self
            tap.cancelsTouchesInView = false
            textView.addGestureRecognizer(tap)
            formatBar.onAction = { [weak self] action in self?.perform(action) }
            display.owner = self
            controller.onDisplayChange = { [weak self] in self?.controllerChanged() }
            // The layout reflows once; the first visible line stays in place.
            controller.onImageChange = { [weak self] destination in
                guard let self else { return }
                let visible = firstVisibleOffset
                display.refreshImages(destination: destination)
                scroll(toOffset: visible)
                updateBoxes()
            }
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: MarkdownView, _) in
                view.rebuild()
            }
            NotificationCenter.default.addObserver(
                self, selector: #selector(reduceMotionChanged),
                name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(reduceMotionChanged),
                name: AccessibilitySettings.animatedImagesEnabledDidChangeNotification, object: nil
            )
            applyEditability()
            rebuild()
        }

        // MARK: host interface

        /// Applies in place: the model is not rebuilt and Undo is kept. The
        /// anchor stays, and VoiceOver focus moves to it.
        public var mode: MarkdownMode {
            get { controller.mode }
            set {
                guard newValue != controller.mode else { return }
                let visible = controller.setMode(newValue, firstVisibleOffset: firstVisibleOffset)
                applyEditability()
                rebuild()
                scroll(toOffset: visible)
                UIAccessibility.post(notification: .layoutChanged, argument: textView)
                if let message = modeSwitchAnnouncement {
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            }
        }

        /// False pauses edits and disables the checkboxes in any mode.
        public var isEditable: Bool {
            get { controller.isEditable }
            set {
                controller.isEditable = newValue
                applyEditability()
            }
        }

        func perform(_ action: FormatAction) {
            perform(action.command(clipboard: UIPasteboard.general.string))
        }

        // MARK: display

        private func applyEditability() {
            textView.isEditable = controller.acceptsEdits
            textView.isSelectable = true
            textView.spellCheckingType = controller.checksSpelling ? .yes : .no
            textView.inputAccessoryView = showsFormatBar && controller.acceptsEdits ? formatBar : nil
            textView.reloadInputViews()
        }

        private func rebuild() {
            isSyncing = true
            display.maxImageHeight = bounds.height * 0.8
            display.columnWidth = textView.textContainer.size.width - 2 * textView.textContainer.lineFragmentPadding
            display.rebuild()
            textView.selectedRange = NSRange(controller.selection)
            isSyncing = false
            updateViewport()
            updateFormatBar()
        }

        /// The controller changed the text or the selection.
        private func controllerChanged() {
            isSyncing = true
            let visible = firstVisibleOffset
            display.sync()
            textView.selectedRange = NSRange(controller.selection)
            if controller.mode == .rendered {
                scroll(toOffset: visible)
                updateBoxes()
            }
            isSyncing = false
            updateFormatBar()
        }

        func select(_ range: Range<Int>) {
            controller.selection = range
            textView.selectedRange = NSRange(range)
        }

        /// The first character of the topmost visible line fragment.
        var firstVisibleOffset: Int {
            guard let layout = textView.textLayoutManager else { return 0 }
            return layout.firstOffset(atY: textView.contentOffset.y - textView.textContainerInset.top)
        }

        func scroll(toOffset offset: Int) {
            guard let frame = textView.textLayoutManager?.fragmentFrame(at: offset) else { return }
            textView.setContentOffset(CGPoint(x: 0, y: frame.minY + textView.textContainerInset.top), animated: false)
        }

        /// A gif shows frame 1 under Reduce Motion or with Auto-Play Animated Images off.
        static var stillImages: Bool {
            UIAccessibility.isReduceMotionEnabled || !AccessibilitySettings.animatedImagesEnabled
        }

        @objc private func reduceMotionChanged() {
            controller.reduceMotion = Self.stillImages
            rebuild()
        }

        /// Asks for the images near the viewport.
        private func updateViewport() {
            guard let layout = textView.textLayoutManager else { return }
            let top = textView.contentOffset.y - textView.textContainerInset.top
            let first = layout.firstOffset(atY: top)
            let last = layout.firstOffset(atY: top + textView.bounds.height)
            controller.viewportChanged(first ..< max(first + 1, last))
            updateBoxes()
        }

        /// Places a box view over each laid-out box wider than the column, in rendered mode.
        func updateBoxes() {
            let top = textView.contentOffset.y - textView.textContainerInset.top
            guard controller.mode == .rendered, let layout = textView.textLayoutManager,
                  let start = layout.location(at: layout.firstOffset(atY: top)),
                  let end = layout.location(at: min(
                      display.storage.length,
                      layout.firstOffset(atY: top + textView.bounds.height) + 1
                  )),
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
            let origin = CGPoint(x: textView.textContainerInset.left, y: textView.textContainerInset.top)
            for geometry in wide {
                let view = boxViews[geometry.mark.id] ?? BoxView(mark: geometry.mark)
                boxViews[geometry.mark.id] = view
                if view.superview == nil {
                    textView.addSubview(view)
                }
                let content = display.storage.attributedSubstring(from: NSRange(geometry.range))
                view.update(content: content, geometry: geometry, origin: origin, padding: 0)
            }
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            updateBoxes()
        }

        private func updateFormatBar() {
            let selection = controller.selection
            formatBar.setActive { [controller] action in
                FormatCommands.isActive(action.command(clipboard: nil), in: controller.text, selection: selection)
            }
        }

        // MARK: taps

        public func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func tapped(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: textView)
            let inset = textView.textContainerInset
            let container = CGPoint(x: point.x - inset.left, y: point.y - inset.top)
            if textView.clickCheckbox(at: container) || textView.clickEditorImage(at: container) {
                return
            }
            guard let position = textView.closestPosition(to: point) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            controller.click(atDisplayOffset: offset, modifiers: LinkModifiers(gesture.modifierFlags))
        }
    }

    extension MarkdownView: UITextViewDelegate {
        public func textView(
            _: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText proposed: String
        ) -> Bool {
            // A typed key does nothing while edits are paused.
            guard controller.acceptsEdits else { return false }
            let edited = range.location ..< NSMaxRange(range)
            if proposed == "\n", nextEvent == nil {
                controller.selection = edited
                if controller.pressReturn() {
                    return false
                }
                nextEvent = .returnKey
            }
            let allowed = controller.allowedReplacement(for: edited, proposed: proposed)
            let event = nextEvent ?? .typed(proposed)
            nextEvent = nil
            guard allowed == proposed else {
                // The cut keeps the longest prefix that fits; the rest is discarded.
                if !allowed.isEmpty {
                    controller.replaceCut(edited, with: allowed, event: event, at: ProcessInfo.processInfo.systemUptime)
                }
                return false
            }
            pendingEdit = PendingEdit(range: edited, replacement: proposed, event: event)
            return true
        }

        public func textViewDidChange(_ textView: UITextView) {
            guard let edit = pendingEdit else { return }
            pendingEdit = nil
            controller.selection = controller.clamped(Range(textView.selectedRange) ?? controller.selection)
            controller.textViewDidReplace(
                edit.range,
                with: edit.replacement,
                event: edit.event,
                at: ProcessInfo.processInfo.systemUptime
            )
            display.restyle(around: edit.range.lowerBound)
            updateFormatBar()
        }

        public func textViewDidChangeSelection(_ textView: UITextView) {
            // During an edit the model does not have the new text yet; textViewDidChange takes the selection.
            guard !isSyncing, pendingEdit == nil else { return }
            let range = controller.clamped(Range(textView.selectedRange) ?? 0 ..< 0)
            guard range != controller.selection else { return }
            let previous = controller.selection.lowerBound
            controller.selection = range
            controller.caretMoved()
            // The old caret line hides its task marker and its image source again.
            display.restyle(around: previous)
            display.restyle(around: range.lowerBound)
            updateFormatBar()
        }

        public func scrollViewDidScroll(_: UIScrollView) {
            updateViewport()
        }

        // MARK: accessibility

        /// The text, then each checkbox of the laid-out text.
        override public var accessibilityElements: [Any]? {
            get { [textView] + textView.checkboxElements(container: self) }
            set { _ = newValue }
        }
    }
#endif
