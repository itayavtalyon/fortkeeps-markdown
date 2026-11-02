#if os(iOS)
    import MarkdownViews
    import UIKit

    /// One Markdown file on iOS (design log 001 › Files). The view holds the
    /// working text and its Undo; the document follows each change.
    public final class ScrollDocument: UIDocument {
        public private(set) var text = ""
        /// Why the last open or save failed.
        private(set) var lastError: (any Error)?
        /// The file was deleted or moved to the Trash; saves pause (screens §3.12).
        private(set) var isDeleted = false
        /// The title block follows the save state.
        var onStateChange: (() -> Void)?

        override public init(fileURL url: URL) {
            super.init(fileURL: url)
            NotificationCenter.default.addObserver(
                self, selector: #selector(stateChanged), name: UIDocument.stateChangedNotification, object: self
            )
        }

        var fileName: String {
            fileURL.lastPathComponent
        }

        override public func contents(forType _: String) throws -> Any {
            DocumentFile.data(for: text)
        }

        override public func load(fromContents contents: Any, ofType _: String?) throws {
            guard let data = contents as? Data, let decoded = try? DocumentFile.text(from: data) else {
                throw OpenRefusal.notUTF8
            }
            text = decoded
        }

        /// A change the view applied (`MarkdownHost.textDidChange(_:)`).
        func apply(_ change: TextChange) {
            text = change.text
            switch DocumentFile.saveAction(for: change) {
            case .stayClean:
                break
            case .autosave:
                updateChangeCount(.done)
            case .saveNow:
                updateChangeCount(.done)
                save(to: fileURL, for: .forOverwriting)
            }
            onStateChange?()
        }

        /// A save failed; the system keeps trying (screens §3.21).
        var saveFailed: Bool {
            documentState.contains(.savingError)
        }

        /// `close()` async sends the document off the main actor.
        @MainActor func closeOnMain() async {
            await withCheckedContinuation { done in close { _ in done.resume() } }
        }

        override public func handleError(_ error: any Error, userInteractionPermitted _: Bool) {
            lastError = error
            finishedHandlingError(error, recovered: false)
        }

        @objc private func stateChanged() {
            onStateChange?()
        }

        // MARK: deletion (screens §3.12)

        /// Saves pause while the file is deleted (autosave, a checkbox, closing);
        /// the text stays in memory.
        override public func save(
            to url: URL,
            for saveOperation: UIDocument.SaveOperation,
            completionHandler: (@Sendable (Bool) -> Void)? = nil
        ) {
            if !FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                noteDeleted()
            }
            guard !isDeleted else {
                completionHandler?(false)
                return
            }
            super.save(to: url, for: saveOperation, completionHandler: completionHandler)
        }

        override public nonisolated func accommodatePresentedItemDeletion(
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            onMain { $0.noteDeleted() }
            completionHandler(nil)
        }

        override public nonisolated func presentedItemDidMove(to newURL: URL) {
            super.presentedItemDidMove(to: newURL)
            onMain { $0.noteMoved(to: newURL) }
        }

        /// The file presenter calls come on the document's queue; its state changes on main.
        private nonisolated func onMain(_ change: @escaping @MainActor (ScrollDocument) -> Void) {
            nonisolated(unsafe) let document = self
            Task { @MainActor in change(document) }
        }

        /// A move to the Trash is a deletion; any other move renames the screen.
        func noteMoved(to url: URL) {
            if url.pathComponents.contains(".Trash") {
                noteDeleted()
            } else {
                onStateChange?()
            }
        }

        private func noteDeleted() {
            isDeleted = true
            onStateChange?()
        }
    }
#endif
