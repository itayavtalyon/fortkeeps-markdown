#if os(iOS)
    import MarkdownViews
    import UIKit

    /// What the screen shows about another app's change (design log 004 ›
    /// Outside changes).
    @MainActor
    struct OutsideChange {
        /// The disk text the dialog or the compare view is about.
        var disk: String?
        var showsNote = false
        var noteDuration = Duration.seconds(4)
        var noteTask: Task<Void, Never>?
        /// The iPad pointer is over the note: it stays.
        var isPointerOver = false
        /// Keep my changes: the status says so once the next save is done.
        var keptMine = false
        var compare: UIViewController?
        var resolveView: ResolveView?
    }

    extension DocumentViewController {
        /// No unsaved edits: an undoable reload and the note. Unsaved edits:
        /// the dialog, with the text paused.
        func outsideChange(_ disk: String) {
            guard document.hasUnsavedChanges else {
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
            UIAccessibility.post(notification: .announcement, argument: NSAttributedString(
                string: ScrollStrings.reloadNote, attributes: [.accessibilitySpeechQueueAnnouncement: true]
            ))
            outside.noteTask?.cancel()
            outside.noteTask = Task { [weak self] in await self?.hideNoteLater() }
        }

        /// The note stays while the pointer is over it, then fades, unless Reduce Motion is on.
        private func hideNoteLater() async {
            try? await Task.sleep(for: outside.noteDuration)
            while !Task.isCancelled, outside.isPointerOver {
                try? await Task.sleep(for: outside.noteDuration)
            }
            guard !Task.isCancelled else { return } // coverage:ignore - a newer note replaced this one
            if let note = strips.arrangedSubviews.first, !UIAccessibility.isReduceMotionEnabled {
                await withCheckedContinuation { done in
                    UIView.animate(withDuration: 0.3) { note.alpha = 0 } completion: { _ in done.resume() }
                }
            }
            outside.showsNote = false
            update()
        }

        func noteStrip() -> StripView? {
            guard outside.showsNote else { return nil }
            let note = StripView(kind: .reloaded, text: ScrollStrings.reloadNote, buttons: [
                (ScrollStrings.undo, { [weak self] in self?.markdownView.undoManager?.undo() })
            ])
            note.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(noteHover)))
            return note
        }

        @objc func noteHover(_ hover: UIHoverGestureRecognizer) {
            outside.isPointerOver = [.began, .changed].contains(hover.state)
        }

        // MARK: the dialog (log 003)

        private func askAboutOutsideChange() {
            markdownView.isEditable = false
            document.pausesSaves = true
            let alert = UIAlertController(
                title: ScrollStrings.changedOutside(document.fileName),
                message: ScrollStrings.changedOutsideBody,
                preferredStyle: .alert
            )
            // No preferred action and no cancel: Return and Esc do nothing.
            alert.addAction(UIAlertAction(title: ScrollStrings.useDisk, style: .destructive) { [weak self] _ in
                self?.useDisk()
            })
            alert.addAction(UIAlertAction(title: ScrollStrings.keepMine, style: .default) { [weak self] _ in
                self?.keepMine()
            })
            alert.addAction(UIAlertAction(title: ScrollStrings.compare, style: .default) { [weak self] _ in
                self?.compare()
            })
            environment.present(alert, self)
        }

        private func endOutsideChange() {
            outside.disk = nil
            markdownView.isEditable = true
            document.pausesSaves = false
        }

        /// Plan 01's `reload(text:)`: the disk text, and Undo cleared.
        private func useDisk() {
            guard let disk = outside.disk else { return } // coverage:ignore - the dialog is up only with a disk text
            endOutsideChange()
            markdownView.reload(text: disk)
            document.updateChangeCount(.cleared)
            update()
        }

        /// The document keeps its unsaved changes, so the next autosave writes the local text.
        private func keepMine() {
            endOutsideChange()
            outside.keptMine = true
            update()
        }

        // MARK: the compare view

        private func compare() {
            guard let disk = outside.disk else { return } // coverage:ignore - as above
            let resolve = ResolveView(
                mine: document.text, theirs: disk,
                mineTitle: ScrollStrings.yourChanges, theirsTitle: ScrollStrings.onDisk
            )
            resolve.onApply = { [weak self] merged in
                self?.closeCompare { self?.applyResolved(merged) }
            }
            resolve.onCancel = { [weak self] in
                self?.closeCompare { self?.askAboutOutsideChange() }
            }
            let screen = UIViewController()
            screen.view = resolve
            screen.title = ScrollStrings.compareTitle(document.fileName)
            let navigation = UINavigationController(rootViewController: screen)
            navigation.modalPresentationStyle = .fullScreen
            outside.compare = navigation
            outside.resolveView = resolve
            environment.present(navigation, self)
        }

        private func closeCompare(then next: @escaping () -> Void) {
            let presenting = outside.compare?.presentingViewController
            outside.compare = nil
            outside.resolveView = nil
            guard let presenting else { return next() }
            presenting.dismiss(animated: true, completion: next) // coverage:ignore - presented only in the app
        } // coverage:ignore - the closing line of the line above

        /// One undo group with reason `edit`; autosave writes it once.
        private func applyResolved(_ merged: String) {
            endOutsideChange()
            markdownView.replaceText(merged, undoActionName: ScrollStrings.resolveAction)
        }
    }
#endif
