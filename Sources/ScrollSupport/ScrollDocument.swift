#if os(macOS)
    import AppKit
    import MarkdownViews

    /// One Markdown file (design log 001 › Files). The view holds the
    /// working text and its Undo; the document follows each change.
    public final class ScrollDocument: NSDocument {
        enum SaveState: Equatable {
            case saved
            case saving
            case failed
        }

        /// The type of the Info.plist document type.
        static let typeName = "Markdown"

        public private(set) var text = ""
        var environment = ScrollEnvironment.app
        private(set) var saveState = SaveState.saved
        /// The file is gone: autosave pauses until Save As….
        private(set) var isDeleted = false
        /// The window follows the save state and the deletion.
        var onStateChange: (() -> Void)?
        /// Another app changed the file; the window gets the disk text.
        var onOutsideChange: ((String) -> Void)?
        /// The outside-change dialog is up: saves pause, so no byte changes.
        var pausesSaves = false
        /// The bytes last read or written; other bytes on disk are another app's.
        private var diskData = Data()

        override public nonisolated static var autosavesInPlace: Bool {
            true
        }

        override public init() {
            super.init()
            // The view's undo groups are the document's Undo.
            hasUndoManager = false
        }

        override public func read(from data: Data, ofType _: String) throws {
            let decoded: String
            do {
                decoded = try DocumentFile.text(from: data)
            } catch {
                throw OpenRefusal.notUTF8
            }
            // NSDocument reads on the main thread: concurrent reading is off.
            MainActor.assumeIsolated {
                text = decoded
                diskData = data
            }
        }

        override public func data(ofType _: String) throws -> Data {
            let data = DocumentFile.data(for: text)
            diskData = data
            return data
        }

        /// A rename sets it after `presentedItemDidMove(to:)`: the window
        /// follows here, its title and the base of links and images.
        override public var fileURL: URL? {
            didSet { Task { @MainActor in onStateChange?() } }
        }

        /// The window title: the file name with its extension, or Untitled.
        var fileName: String {
            if let fileURL {
                return fileURL.lastPathComponent
            }
            return displayName
        }

        override public func makeWindowControllers() {
            guard let environment else { return } // coverage:ignore - main.swift sets it before launch
            addWindowController(DocumentWindowController(document: self, environment: environment))
        }

        /// A change the view applied (`MarkdownHost.textDidChange(_:)`).
        func apply(_ change: TextChange) {
            text = change.text
            switch DocumentFile.saveAction(for: change) {
            case .stayClean:
                break
            case .autosave:
                updateChangeCount(.changeDone)
            case .saveNow:
                updateChangeCount(.changeDone)
                autosave(withImplicitCancellability: false) { _ in }
            }
        }

        // MARK: saving

        override public func save(
            to url: URL,
            ofType typeName: String,
            for saveOperation: NSDocument.SaveOperationType,
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            setSaveState(.saving)
            super.save(to: url, ofType: typeName, for: saveOperation) { error in
                MainActor.assumeIsolated {
                    // Autosave pauses while deleted, so a save that works wrote the file back (Save, Save As).
                    if error == nil {
                        self.isDeleted = false
                    }
                    self.setSaveState(error == nil ? .saved : .failed)
                }
                completionHandler(error)
            }
        }

        /// Autosave pauses while the file is deleted; the text stays in memory.
        override public func autosave(
            withImplicitCancellability autosavingIsImplicitlyCancellable: Bool,
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            if let fileURL, !FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                noteDeleted()
            }
            guard !isDeleted, !pausesSaves else {
                completionHandler(nil)
                return
            }
            super.autosave(
                withImplicitCancellability: autosavingIsImplicitlyCancellable,
                completionHandler: completionHandler
            )
        }

        /// The strip shows the failure; the system shows no alert.
        override public func presentError(
            _ error: any Error,
            modalFor window: NSWindow,
            delegate: Any?,
            didPresent didPresentSelector: Selector?,
            contextInfo: UnsafeMutableRawPointer?
        ) {
            guard saveState != .failed else { return }
            super.presentError(
                error, modalFor: window, delegate: delegate, didPresent: didPresentSelector, contextInfo: contextInfo
            )
        }

        private func setSaveState(_ state: SaveState) {
            saveState = state
            onStateChange?()
        }

        // MARK: outside changes (design log 004 › Outside changes)

        /// Not `super`: NSDocument would revert on its own.
        override public nonisolated func presentedItemDidChange() {
            Task { @MainActor in noteChangeOnDisk() }
        }

        /// New bytes on disk go to the window. The modification date follows,
        /// so the next save does not ask about the other app.
        func noteChangeOnDisk() {
            // ponytail: bytes that are not UTF-8 are ignored; the next save writes over them.
            guard let fileURL, let data = try? Data(contentsOf: fileURL), data != diskData,
                  let disk = try? DocumentFile.text(from: data) else { return }
            diskData = data
            // Not the URL's resource values: they cache the date from the open.
            fileModificationDate = try? FileManager.default
                .attributesOfItem(atPath: fileURL.path(percentEncoded: false))[.modificationDate] as? Date
            // Another app's CRLF rewrite of the same text is no change.
            guard disk != text else { return }
            onOutsideChange?(disk)
        }

        // MARK: deletion (screens §3.12)

        override public nonisolated func accommodatePresentedItemDeletion(
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            Task { @MainActor in noteDeleted() }
            completionHandler(nil)
        }

        override public nonisolated func presentedItemDidMove(to newURL: URL) {
            super.presentedItemDidMove(to: newURL)
            Task { @MainActor in noteMoved(to: newURL) }
        }

        /// A move to the Trash is a deletion; any other move renames the
        /// window through `fileURL`.
        func noteMoved(to url: URL) {
            if url.pathComponents.contains(".Trash") {
                noteDeleted()
            }
        }

        private func noteDeleted() {
            guard !isDeleted else { return }
            isDeleted = true
            onStateChange?()
        }
    }
#endif
