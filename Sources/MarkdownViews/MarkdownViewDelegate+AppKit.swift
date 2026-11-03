#if os(macOS)
    import AppKit
    import MarkdownCore

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

        /// Several ranges at once is Replace All from the find bar (screens §3.6):
        /// the view makes the change itself, as one undo group.
        public func textView(
            _ view: NSTextView,
            shouldChangeTextInRanges affectedRanges: [NSValue],
            replacementStrings: [String]?
        ) -> Bool {
            guard affectedRanges.count > 1, let replacementStrings else {
                return textView(
                    view,
                    shouldChangeTextIn: affectedRanges.first?.rangeValue ?? NSRange(),
                    replacementString: replacementStrings?.first
                )
            }
            let text = NSMutableString(string: controller.text)
            for (range, string) in zip(affectedRanges, replacementStrings).sorted(by: {
                $0.0.rangeValue.location > $1.0.rangeValue.location
            }) {
                text.replaceCharacters(in: range.rangeValue, with: string)
            }
            if !controller.acceptsEdits || !controller.replaceAll(text as String) {
                NSSound.beep()
            }
            return false
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
            let previous = controller.selection.lowerBound
            controller.selection = range
            controller.caretMoved()
            // The old caret line hides its task marker and its image source again.
            display.restyle(around: previous)
            display.restyle(around: range.lowerBound)
            mirrorSelection()
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
