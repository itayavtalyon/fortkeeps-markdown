#if os(macOS)
    import AppKit

    /// The app: its menu bar, its documents, and the empty window (design
    /// log 001 › Windows and chrome).
    @MainActor
    public final class ScrollAppDelegate: NSObject, NSApplicationDelegate, EmptyWindowActions {
        let documents: ScrollDocumentController
        let cache: ImageCache
        private(set) var emptyWindow: EmptyWindowController?
        private var acknowledgements: NSWindowController?
        /// Any document is open. AppKit keeps one document list for every
        /// controller, so the tests set this instead.
        var hasDocuments: () -> Bool

        /// `documents` must be the first document controller made, so it is the shared one.
        init(documents: ScrollDocumentController, cache: ImageCache = .standard) {
            self.documents = documents
            self.cache = cache
            hasDocuments = { [weak documents] in documents?.documents.isEmpty == false }
            super.init()
            documents.onDocumentsChange = { [weak self] in self?.showEmptyWindowIfNeeded() }
        }

        override public convenience init() {
            self.init(documents: ScrollDocumentController())
        }

        public func applicationWillFinishLaunching(_: Notification) {
            let menu = MainMenu.make()
            NSApplication.shared.mainMenu = menu
            NSApplication.shared.windowsMenu = menu.item(withTitle: "Window")?.submenu
            NSApplication.shared.helpMenu = menu.item(withTitle: "Help")?.submenu
            cache.purge()
        }

        /// After the system restores and opens documents.
        public func applicationDidFinishLaunching(_: Notification) {
            showEmptyWindowIfNeeded()
        }

        /// The Mac has no background; the cache purges when the app is left.
        public func applicationDidResignActive(_: Notification) {
            cache.purge()
        }

        public func applicationShouldOpenUntitledFile(_: NSApplication) -> Bool {
            false
        }

        public func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
            if !hasVisibleWindows {
                showEmptyWindowIfNeeded()
            }
            return hasVisibleWindows
        }

        func showEmptyWindowIfNeeded() {
            // One controller for the app's life; it rebuilds for the current recent files.
            guard !hasDocuments() else {
                emptyWindow?.close()
                return
            }
            if let emptyWindow {
                emptyWindow.build(recent: documents.recentDocumentURLs)
            } else {
                emptyWindow = EmptyWindowController(recent: documents.recentDocumentURLs, actions: self)
            }
            emptyWindow?.showWindow(nil)
        }

        @objc func showAcknowledgements(_: Any?) {
            if acknowledgements == nil {
                let folder = Bundle.main.url(forResource: "Acknowledgements", withExtension: nil)
                acknowledgements = AcknowledgementsWindowController(entries: Acknowledgement.load(from: folder))
            }
            acknowledgements?.showWindow(nil)
        }

        // MARK: EmptyWindowActions

        func open(_ url: URL) {
            documents.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }

        /// The system has no call to remove one file: the list is rebuilt without it.
        func removeRecent(_ url: URL) {
            let kept = documents.recentDocumentURLs.filter { $0 != url }
            documents.clearRecentDocuments(nil)
            kept.reversed().forEach(documents.noteNewRecentDocumentURL)
            showEmptyWindowIfNeeded()
        }
    }
#endif
