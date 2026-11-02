#if os(macOS)
    import AppKit
    import MarkdownViews

    /// What the window shows about another app's change (design log 004 ›
    /// Outside changes).
    @MainActor
    struct OutsideChange {
        /// The disk text the dialog or the compare view is about.
        var disk: String?
        var showsNote = false
        var noteDuration = Duration.seconds(4)
        var noteTask: Task<Void, Never>?
        var isPointerOver: (NSView) -> Bool = { view in
            guard let window = view.window else { return false }
            return view.bounds.contains(view.convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }

        /// Keep My Changes: the next save is the kept one, and the status says so.
        var keepsMine = false
        var keptMine = false
        /// The compare view, in place of the text.
        var resolveView: ResolveView?
    }

    extension DocumentWindowController {
        /// No unsaved edits: an undoable reload and the note. Unsaved edits:
        /// the dialog, with the text paused.
        func outsideChange(_ disk: String) {
            guard let document = scrollDocument else { return } // coverage:ignore - the document sets this hook
            guard document.isDocumentEdited else {
                reloadQuietly(disk)
                return
            }
            let asking = outside.disk != nil
            // ponytail: a second change while asking updates the disk text; the changed-again banner waits (Round 5).
            outside.disk = disk
            if !asking {
                askAboutOutsideChange()
            }
        }

        private func reloadQuietly(_ disk: String) {
            markdownView.reload(text: disk, undoActionName: ScrollStrings.reloadAction)
            outside.showsNote = true
            update()
            if let window {
                NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: [
                    .announcement: ScrollStrings.reloadNote,
                    .priority: NSAccessibilityPriorityLevel.medium.rawValue
                ])
            }
            outside.noteTask?.cancel()
            outside.noteTask = Task { [weak self] in await self?.hideNoteLater() }
        }

        /// The note stays while the pointer is over it, then fades, unless Reduce Motion is on.
        private func hideNoteLater() async {
            try? await Task.sleep(for: outside.noteDuration)
            while !Task.isCancelled, isPointerOverNote() {
                try? await Task.sleep(for: outside.noteDuration)
            }
            guard !Task.isCancelled else { return } // coverage:ignore - a newer note replaced this one
            if let note = strips.arrangedSubviews.first, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                await NSAnimationContext.runAnimationGroup { _ in note.animator().alphaValue = 0 }
            }
            outside.showsNote = false
            update()
        }

        func isPointerOverNote() -> Bool {
            guard let note = strips.arrangedSubviews.first else { return false }
            return outside.isPointerOver(note)
        }

        @objc func undoReload() {
            markdownView.undoManager?.undo()
        }

        // MARK: the dialog (log 003)

        private func askAboutOutsideChange() {
            guard let document = scrollDocument else { return } // coverage:ignore - asked only with a document
            markdownView.isEditable = false
            document.pausesSaves = true
            let alert = NSAlert()
            alert.messageText = ScrollStrings.changedOutside(document.fileName)
            alert.informativeText = ScrollStrings.changedOutsideBody
            // No default button: Return and Esc do nothing.
            let titles = [ScrollStrings.useDisk, ScrollStrings.keepMine, ScrollStrings.compare]
            for (title, hint) in zip(titles, ScrollStrings.outsideHints) {
                let button = alert.addButton(withTitle: title)
                button.keyEquivalent = ""
                button.setAccessibilityHelp(hint)
            }
            // Focus starts on no button (screens §3.10), so Space cannot choose either.
            alert.layout()
            // The panel gives its first button for nil; the content view takes no focus itself.
            alert.window.initialFirstResponder = alert.window.contentView
            environment.presentAlert(alert, window) { [weak self] response in
                switch response {
                case .alertFirstButtonReturn: self?.useDisk()
                case .alertSecondButtonReturn: self?.keepMine()
                default: self?.compare()
                }
            }
        }

        private func endOutsideChange() {
            outside.disk = nil
            markdownView.isEditable = true
            scrollDocument?.pausesSaves = false
        }

        /// Plan 01's `reload(text:)`: the disk text, and Undo cleared.
        private func useDisk() {
            guard let disk = outside.disk else { return } // coverage:ignore - the dialog is up only with a disk text
            endOutsideChange()
            markdownView.reload(text: disk)
            scrollDocument?.updateChangeCount(.changeCleared)
            update()
        }

        /// The document stays edited, so the next autosave writes the local text.
        private func keepMine() {
            endOutsideChange()
            outside.keepsMine = true
            update()
        }

        // MARK: the compare view

        private func compare() {
            guard let document = scrollDocument, let disk = outside.disk,
                  let stack = window?.contentView as? NSStackView else { return } // coverage:ignore - as above
            let resolve = ResolveView(
                mine: document.text, theirs: disk,
                mineTitle: ScrollStrings.yourChanges, theirsTitle: ScrollStrings.onDisk
            )
            resolve.onApply = { [weak self] in self?.applyResolved($0) }
            resolve.onCancel = { [weak self] in self?.cancelCompare() }
            markdownView.isHidden = true
            // The window's stack is the strips, the text, and the status bar.
            stack.insertArrangedSubview(resolve, at: 1)
            resolve.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            outside.resolveView = resolve
            synchronizeWindowTitleWithDocumentName()
            window?.makeFirstResponder(resolve)
        }

        private func closeCompare() {
            outside.resolveView?.removeFromSuperview()
            outside.resolveView = nil
            synchronizeWindowTitleWithDocumentName()
            markdownView.isHidden = false
            window?.makeFirstResponder(markdownView)
        }

        /// One undo group with reason `edit`; autosave writes it once.
        private func applyResolved(_ merged: String) {
            closeCompare()
            endOutsideChange()
            markdownView.replaceText(merged, undoActionName: ScrollStrings.resolveAction)
        }

        private func cancelCompare() {
            closeCompare()
            askAboutOutsideChange()
        }
    }
#endif
