#if os(iOS)
    import MarkdownViews
    import UIKit

    /// The iOS half of the outside-change flow (design log 004 › Outside changes).
    extension DocumentViewController: OutsideChangeHost {
        var hasUnsavedEdits: Bool {
            document.hasUnsavedChanges
        }

        func pauseSaves(_ paused: Bool) {
            document.pausesSaves = paused
        }

        func markClean() {
            document.updateChangeCount(.cleared)
        }

        func markEdited() {
            document.updateChangeCount(.done)
        }

        /// The status says so once the next save is done.
        func noteKeptMine() {
            outside.keptMine = true
        }

        func announce(_ text: String) {
            UIAccessibility.post(notification: .announcement, argument: NSAttributedString(
                string: text, attributes: [.accessibilitySpeechQueueAnnouncement: true]
            ))
        }

        func isPointerOverNote() -> Bool {
            outside.isPointerOver
        }

        func fadeNote() async {
            if let note = strips.arrangedSubviews.first, !UIAccessibility.isReduceMotionEnabled {
                await withCheckedContinuation { done in
                    UIView.animate(withDuration: 0.3) { note.alpha = 0 } completion: { _ in done.resume() }
                }
            }
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

        func askAboutOutsideChange() {
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

        // MARK: the compare view

        private func compare() {
            guard let disk = outside.disk else { return } // coverage:ignore - the dialog is up only with a disk text
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
    }
#endif
