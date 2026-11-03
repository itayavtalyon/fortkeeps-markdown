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

        /// The view scrolled, so the host can follow the current Outline row.
        public var onScroll: (() -> Void)?

        /// Settings › Line width: the widest the text column gets; nil fills the view.
        public var maxLineWidth: CGFloat? {
            didSet { setNeedsLayout() }
        }

        /// Find replaced text in the text view; the model takes it on the next turn.
        var isTakingFindReplacement = false

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
            // Find and replace (screens §3.6): the system find panel.
            textView.isFindInteractionEnabled = true
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
            controller.onAnnouncement = { message in
                UIAccessibility.post(notification: .announcement, argument: message)
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

        /// The caret goes into the text: a new file opens with the keyboard up.
        override public func becomeFirstResponder() -> Bool {
            textView.becomeFirstResponder()
        }

        /// Find in the ⋯ menu (screens §3.6): the system find navigator, without Replace.
        public func showFind() {
            textView.findInteraction?.presentFindNavigator(showingReplace: false)
        }

        /// Copy as Rich Text: RTF and HTML of the selection, or of the whole text
        /// with nothing selected; plain Copy stays the source.
        public func copyAsRichText(to pasteboard: UIPasteboard = .general) {
            let flavors = richTextFlavors()
            pasteboard.items = [[
                "public.rtf": flavors.rtf,
                "public.html": Data(flavors.html.utf8),
                "public.utf8-plain-text": flavors.plain
            ]]
        }

        /// A format command, as the format bar and the shortcuts give it.
        public func perform(_ action: FormatAction) {
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

        func rebuild() {
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

        /// The first character of the line fragment at the bottom of the view.
        var lastVisibleOffset: Int {
            guard let layout = textView.textLayoutManager else { return 0 }
            return layout
                .firstOffset(atY: textView.contentOffset.y - textView.textContainerInset.top + textView.bounds.height)
        }

        var containerOrigin: CGPoint {
            CGPoint(x: textView.textContainerInset.left, y: textView.textContainerInset.top)
        }

        func scroll(toOffset offset: Int) {
            guard let frame = textView.textLayoutManager?.fragmentFrame(at: offset) else { return }
            textView.setContentOffset(CGPoint(x: 0, y: frame.minY + textView.textContainerInset.top), animated: false)
        }

        func moveAccessibilityFocusToSelection() {
            UIAccessibility.post(notification: .layoutChanged, argument: textView)
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
        func updateViewport() {
            guard let layout = textView.textLayoutManager else { return }
            let top = textView.contentOffset.y - textView.textContainerInset.top
            let first = layout.firstOffset(atY: top)
            let last = layout.firstOffset(atY: top + textView.bounds.height)
            controller.viewportChanged(first ..< max(first + 1, last))
            updateBoxes()
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            let inset = Self.sideInset(width: textView.bounds.width, maxLineWidth: maxLineWidth, minimum: 12)
            if inset != textView.textContainerInset.left {
                textView.textContainerInset.left = inset
                textView.textContainerInset.right = inset
            }
            updateBoxes()
        }

        func updateFormatBar() {
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
#endif
