#if canImport(UIKit)
    import MarkdownCore
    import UIKit

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

        /// Reload Image and Load All Images join the edit menu, before the suggested actions.
        public func textView(
            _: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let destination = controller.mode == .rendered ? nil : controller
                .imageDestination(atDisplayOffset: range.location)
            return UIMenu(children: imageMenuElements(destination: destination) + suggestedActions)
        }

        /// The image items of the controller as menu actions.
        func imageMenuElements(destination: String?) -> [UIMenuElement] {
            controller.imageMenuItems(destination: destination).map { item in
                UIAction(title: item.title) { [weak self] _ in self?.controller.perform(item) }
            }
        }

        public func textViewDidChange(_ textView: UITextView) {
            guard let edit = pendingEdit else {
                // Find's Replace and Replace All change the text without asking (screens §3.6),
                // once per match: the model takes the result as one undo group when UIKit is done.
                if !isTakingFindReplacement {
                    isTakingFindReplacement = true
                    Task { @MainActor [weak self] in self?.takeFindReplacement() }
                }
                return
            }
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

        private func takeFindReplacement() {
            isTakingFindReplacement = false
            let replaced = textView.text ?? ""
            // The text view shows the model's text again, then the model makes the change.
            rebuild()
            controller.undoManager.dropEmptyGroup()
            _ = controller.replaceAll(replaced)
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
            mirrorSelection()
            updateFormatBar()
        }

        public func scrollViewDidScroll(_: UIScrollView) {
            updateViewport()
            onScroll?()
        }

        // MARK: accessibility

        /// The name VoiceOver reads for the text, such as the file name. An
        /// empty text has no value to read, so the host names it.
        override public var accessibilityLabel: String? {
            get { textView.accessibilityLabel }
            set { textView.accessibilityLabel = newValue }
        }

        /// The text, then each checkbox of the laid-out text.
        override public var accessibilityElements: [Any]? {
            get { [textView] + textView.checkboxElements(container: self) }
            set { _ = newValue }
        }
    }
#endif
