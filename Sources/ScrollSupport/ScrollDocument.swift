#if os(macOS)
    import AppKit
    import MarkdownViews

    /// Why the app does not open a file (design log 001 › Files).
    public enum OpenRefusal: Error, Equatable {
        /// Not one of the accepted extensions.
        case wrongExtension
        /// Not valid UTF-8, or a NUL byte.
        case notUTF8
    }

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
            MainActor.assumeIsolated { text = decoded }
        }

        override public func data(ofType _: String) throws -> Data {
            DocumentFile.data(for: text)
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
            guard !isDeleted else {
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

        /// A move to the Trash is a deletion; any other move renames the window.
        func noteMoved(to url: URL) {
            if url.pathComponents.contains(".Trash") {
                noteDeleted()
            } else {
                onStateChange?()
            }
        }

        private func noteDeleted() {
            guard !isDeleted else { return }
            isDeleted = true
            onStateChange?()
        }
    }
#endif
