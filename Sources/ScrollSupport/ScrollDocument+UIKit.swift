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
        /// The session and the lists follow a rename: the old and the new URL.
        var onMove: ((URL, URL) -> Void)?
        /// Another app changed the file; the screen gets the disk text.
        var onOutsideChange: ((DiskWatch.Change) -> Void)?
        /// The outside-change dialog is up: saves pause, so no byte changes.
        var pausesSaves = false
        private var disk = DiskWatch()
        /// The bytes a save is writing: they are on disk once the save is done.
        private var savingData: Data?

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
            let data = DocumentFile.data(for: text)
            savingData = data
            return data
        }

        override public func load(fromContents contents: Any, ofType _: String?) throws {
            guard let data = contents as? Data, let decoded = try? DocumentFile.text(from: data) else {
                throw OpenRefusal.notUTF8
            }
            text = decoded
            disk.data = data
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

        /// `open()` async sends the document off the main actor.
        @MainActor func openOnMain() async -> Bool {
            await withCheckedContinuation { done in open { done.resume(returning: $0) } }
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

        // MARK: outside changes (design log 004 › Outside changes)

        /// Not `super`: UIDocument would revert on its own.
        override public nonisolated func presentedItemDidChange() {
            onMain { $0.noteChangeOnDisk() }
        }

        /// New bytes on disk go to the screen.
        func noteChangeOnDisk() {
            guard let data = try? Data(contentsOf: fileURL), data != disk.data,
                  let change = disk.change(to: data, text: text) else { return }
            onOutsideChange?(change)
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
            guard !isDeleted, !pausesSaves else {
                completionHandler?(false)
                return
            }
            // A presenter call before the write is done still reads the old bytes.
            nonisolated(unsafe) let document = self
            super.save(to: url, for: saveOperation) { saved in
                MainActor.assumeIsolated {
                    if saved, let data = document.savingData {
                        document.disk.data = data
                    }
                }
                completionHandler?(saved)
            }
        }

        override public nonisolated func accommodatePresentedItemDeletion(
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            onMain { $0.noteDeleted() }
            completionHandler(nil)
        }

        override public nonisolated func presentedItemDidMove(to newURL: URL) {
            let old = fileURL
            super.presentedItemDidMove(to: newURL)
            onMain { $0.noteMoved(from: old, to: newURL) }
        }

        /// The file presenter calls come on the document's queue; its state changes on main.
        private nonisolated func onMain(_ change: @escaping @MainActor (ScrollDocument) -> Void) {
            nonisolated(unsafe) let document = self
            Task { @MainActor in change(document) }
        }

        /// A move to the Trash is a deletion; any other move renames the screen.
        func noteMoved(from old: URL, to url: URL) {
            if DiskWatch.isTrash(url) {
                noteDeleted()
            } else {
                onMove?(old, url)
                onStateChange?()
            }
        }

        private func noteDeleted() {
            isDeleted = true
            onStateChange?()
        }
    }
#endif
