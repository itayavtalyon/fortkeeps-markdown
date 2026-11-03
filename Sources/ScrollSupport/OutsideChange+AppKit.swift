#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The Mac half of the outside-change flow (design log 004 › Outside changes).
    extension DocumentWindowController: OutsideChangeHost {
        var hasUnsavedEdits: Bool {
            scrollDocument?.isDocumentEdited == true
        }

        func pauseSaves(_ paused: Bool) {
            scrollDocument?.pausesSaves = paused
        }

        func markClean() {
            scrollDocument?.updateChangeCount(.changeCleared)
        }

        func markEdited() {
            scrollDocument?.updateChangeCount(.changeDone)
        }

        /// The status says so once the next save starts.
        func noteKeptMine() {
            outside.keepsMine = true
        }

        func announce(_ text: String) {
            guard let window else { return } // coverage:ignore - a document window always has one
            NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ])
        }

        func isPointerOverNote() -> Bool {
            guard let note = strips.arrangedSubviews.first else { return false }
            return outside.isPointerOver(note)
        }

        /// The fade's completion handler can wait on a busy run loop for good, which
        /// left the note up; the note goes once the fade's time has passed.
        func fadeNote() async {
            guard let note = strips.arrangedSubviews.first, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            else { return }
            let duration = 0.25
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                note.animator().alphaValue = 0
            }, completionHandler: nil)
            try? await Task.sleep(for: .seconds(duration))
        }

        @objc func undoReload() {
            markdownView.undoManager?.undo()
        }

        @objc func keepMineOverUnreadableAction() {
            keepMineOverUnreadable()
        }

        // MARK: the dialog (log 003)

        func askAboutOutsideChange() {
            guard let document = scrollDocument else { return } // coverage:ignore - asked only with a document
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

        // MARK: the compare view

        private func compare() {
            guard let document = scrollDocument, let disk = outside.disk else { return } // coverage:ignore - as above
            let stack = contentStack
            let resolve = ResolveView(
                mine: document.text, theirs: disk,
                mineTitle: ScrollStrings.yourChanges, theirsTitle: ScrollStrings.onDisk
            )
            resolve.onApply = { [weak self] merged in
                self?.closeCompare()
                self?.applyResolved(merged)
            }
            resolve.onCancel = { [weak self] in
                self?.closeCompare()
                self?.askAboutOutsideChange()
            }
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
    }
#endif
