#if os(macOS)
    import AppKit
    import MarkdownCore

    /// The Mac Markdown view: TextKit 2 with the three modes (design log 001 ›
    /// Host interface, View settings, Modes). It holds the working text; the
    /// host sets it at creation and replaces it only with `reload(text:)`.
    @MainActor
    public final class MarkdownView: NSView {
        let controller: MarkdownTextController
        let scrollView = NSScrollView()
        let textView: MarkdownNSTextView
        let formatBar = FormatBarView()
        let display: MarkdownDisplay
        private let layoutDelegate = MarkdownLayoutDelegate()
        /// The edit the text view is applying, from `shouldChangeTextIn` to `textDidChange`.
        var pendingEdit: PendingEdit?
        /// The event of the next edit when it is not typing.
        var nextEvent: UndoGrouping.Event?
        var isSyncing = false

        /// The string VoiceOver announces after a mode switch. The host supplies it.
        public var modeSwitchAnnouncement: String?

        /// View › Show Format Bar. The host keeps the choice for all windows.
        public var showsFormatBar = true {
            didSet { updateFormatBar() }
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
            controller.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            textView = MarkdownNSTextView(usingTextLayoutManager: true)
            // A TextKit 2 text view always has a storage.
            let storage = textView.textStorage! // swiftlint:disable:this force_unwrapping
            display = MarkdownDisplay(controller: controller, storage: storage)
            super.init(frame: CGRect(x: 0, y: 0, width: 480, height: 640))
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
            textView.isRichText = false
            textView.allowsUndo = false
            textView.usesFindBar = true
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.drawsBackground = true
            textView.backgroundColor = MarkdownTheme.color(.pane)
            textView.textContainerInset = NSSize(width: 16, height: 16)
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            scrollView.documentView = textView
            scrollView.hasVerticalScroller = true
            scrollView.frame = bounds
            scrollView.autoresizingMask = [.width, .height]
            textView.frame = CGRect(origin: .zero, size: scrollView.contentSize)
            addSubview(scrollView)
            formatBar.isHidden = true
            formatBar.onAction = { [weak self] action in self?.perform(action) }
            addSubview(formatBar)
            display.owner = self
            controller.onDisplayChange = { [weak self] in self?.controllerChanged() }
            controller
                .onImageChange = { [weak self] destination in self?.display.refreshImages(destination: destination) }
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(displayOptionsChanged),
                name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
            )
            applyEditability()
            rebuild()
        }

        // MARK: host interface

        public var text: String {
            controller.text
        }

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
                announceAnchor()
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

        public var anchor: MarkdownAnchor {
            get {
                controller.document.anchor(
                    firstVisibleSourceOffset: controller.sourceByte(ofDisplayOffset: firstVisibleOffset),
                    selection: controller.sourceByte(ofDisplayOffset: controller.selection.lowerBound)
                        ..< controller.sourceByte(ofDisplayOffset: controller.selection.upperBound)
                )
            }
            set {
                let start = controller.displayOffset(ofSourceByte: newValue.selection.lowerBound)
                let end = max(start, controller.displayOffset(ofSourceByte: newValue.selection.upperBound))
                select(start ..< end)
                scroll(toOffset: controller.displayOffset(ofSourceByte: newValue.block + newValue.offsetInBlock))
            }
        }

        /// Replaces the text, clears Undo, keeps the anchor at the nearest block, and reports `reload`.
        public func reload(text newText: String) {
            let kept = anchor
            controller.reload(text: newText)
            anchor = kept
        }

        public func refreshImage(destination: String) {
            controller.refreshImage(destination: destination)
            display.refreshImages(destination: destination)
        }

        /// Performs a format command, as the format bar and the shortcuts do.
        public func perform(_ command: FormatCommand) {
            controller.perform(command)
        }

        func perform(_ action: FormatAction) {
            perform(action.command(clipboard: NSPasteboard.general.string(forType: .string)))
        }

        // MARK: display

        private func applyEditability() {
            textView.isEditable = controller.acceptsEdits
            textView.isSelectable = true
            textView.isContinuousSpellCheckingEnabled = controller.checksSpelling
            updateFormatBar()
        }

        private func rebuild() {
            isSyncing = true
            display.maxImageHeight = scrollView.contentSize.height * 0.8
            display.rebuild()
            textView.setSelectedRange(NSRange(controller.selection))
            isSyncing = false
            updateViewport()
        }

        /// The controller changed the text or the selection.
        private func controllerChanged() {
            isSyncing = true
            let visible = firstVisibleOffset
            display.sync()
            textView.setSelectedRange(NSRange(controller.selection))
            if controller.mode == .rendered {
                scroll(toOffset: visible)
            }
            isSyncing = false
            updateFormatBar()
        }

        func select(_ range: Range<Int>) {
            controller.selection = range
            textView.setSelectedRange(NSRange(range))
        }

        /// The first character of the topmost visible line fragment.
        var firstVisibleOffset: Int {
            guard let layout = textView.textLayoutManager else { return 0 }
            return layout.firstOffset(atY: textView.visibleRect.minY - textView.textContainerOrigin.y)
        }

        func scroll(toOffset offset: Int) {
            guard let frame = textView.textLayoutManager?.fragmentFrame(at: offset) else { return }
            textView.scroll(CGPoint(x: 0, y: frame.minY + textView.textContainerOrigin.y))
        }

        private func announceAnchor() {
            NSAccessibility.post(element: textView, notification: .selectedTextChanged)
            NSAccessibility.post(element: textView, notification: .focusedUIElementChanged)
            if let message = modeSwitchAnnouncement {
                NSAccessibility.post(element: textView, notification: .announcementRequested, userInfo: [
                    .announcement: message,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue
                ])
            }
        }

        @objc private func scrolled() {
            formatBar.isHidden = true
            updateViewport()
        }

        @objc private func displayOptionsChanged() {
            controller.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            rebuild()
        }

        /// Asks for the images near the viewport, in rendered mode.
        private func updateViewport() {
            guard controller.mode == .rendered, let layout = textView.textLayoutManager else { return }
            let origin = textView.textContainerOrigin.y
            let first = layout.firstOffset(atY: textView.visibleRect.minY - origin)
            let last = layout.firstOffset(atY: textView.visibleRect.maxY - origin)
            controller.viewportChanged(first ..< max(first + 1, last))
        }

        // MARK: format bar

        private func updateFormatBar() {
            let selection = controller.selection
            formatBar.setActive { [controller] action in
                FormatCommands.isActive(action.command(clipboard: nil), in: controller.text, selection: selection)
            }
            guard showsFormatBar, controller.acceptsEdits, !selection.isEmpty, let window else {
                formatBar.isHidden = true
                return
            }
            let screen = textView.firstRect(forCharacterRange: NSRange(selection), actualRange: nil)
            let rect = convert(window.convertFromScreen(screen), from: nil)
            let size = formatBar.fittingSize
            let above = rect.maxY + 8 + size.height <= bounds.maxY
            let y = above ? rect.maxY + 8 : rect.minY - 8 - size.height
            formatBar.frame = CGRect(
                x: max(0, min(rect.minX, bounds.maxX - size.width)),
                y: y,
                width: size.width,
                height: size.height
            )
            formatBar.isHidden = false
        }

        func hideFormatBar() -> Bool {
            defer { formatBar.isHidden = true }
            return !formatBar.isHidden
        }

        override public func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window == nil || window?.firstResponder === textView,
                  let action = Self.formatAction(for: event)
            else { return super.performKeyEquivalent(with: event) }
            guard controller.acceptsEdits else {
                NSSound.beep()
                return true
            }
            perform(action)
            return true
        }

        static func formatAction(for event: NSEvent) -> FormatAction? {
            var modifiers: FormatShortcut.Modifiers = []
            let flags = event.modifierFlags
            if flags.contains(.command) {
                modifiers.insert(.command)
            }
            if flags.contains(.shift) {
                modifiers.insert(.shift)
            }
            if flags.contains(.option) {
                modifiers.insert(.option)
            }
            // Shift-Command-8 arrives as `*`; the key without modifiers is `8`.
            let keys = [event.charactersIgnoringModifiers, event.characters(byApplyingModifiers: [])].compactMap(\.self)
            return keys.lazy.compactMap { FormatAction.matching(key: $0, modifiers: modifiers) }.first
        }
    }

    extension MarkdownView: NSTextViewDelegate {
        public func undoManager(for _: NSTextView) -> UndoManager? {
            controller.undoManager
        }

        public func textView(
            _: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let proposed = replacementString else { return true }
            guard controller.acceptsEdits else {
                NSSound.beep()
                return false
            }
            let range = affectedCharRange.location ..< NSMaxRange(affectedCharRange)
            let allowed = controller.allowedReplacement(for: range, proposed: proposed)
            let event = nextEvent ?? .typed(proposed)
            nextEvent = nil
            guard allowed == proposed else {
                // The cut keeps the longest prefix that fits; the rest is discarded.
                if allowed.isEmpty {
                    NSSound.beep()
                } else {
                    controller.replaceCut(range, with: allowed, event: event, at: ProcessInfo.processInfo.systemUptime)
                }
                return false
            }
            pendingEdit = PendingEdit(range: range, replacement: proposed, event: event)
            return true
        }

        public func textDidChange(_: Notification) {
            guard let edit = pendingEdit else { return }
            pendingEdit = nil
            controller.selection = controller.clamped(Range(textView.selectedRange()) ?? controller.selection)
            controller.textViewDidReplace(
                edit.range,
                with: edit.replacement,
                event: edit.event,
                at: ProcessInfo.processInfo.systemUptime
            )
            display.restyle(around: edit.range.lowerBound)
            formatBar.isHidden = true
        }

        public func textViewDidChangeSelection(_: Notification) {
            // During an edit the model does not have the new text yet; textDidChange takes the selection.
            guard !isSyncing, pendingEdit == nil else { return }
            let range = controller.clamped(Range(textView.selectedRange()) ?? 0 ..< 0)
            guard range != controller.selection else { return }
            controller.selection = range
            controller.caretMoved()
            display.restyle(around: range.lowerBound)
            updateFormatBar()
        }

        public func textView(_: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                if controller.pressReturn() {
                    return true
                }
                nextEvent = .returnKey
                return false
            case #selector(NSResponder.cancelOperation(_:)):
                return hideFormatBar()
            default:
                return false
            }
        }
    }
#endif
