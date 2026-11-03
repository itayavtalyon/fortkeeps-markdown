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
        private(set) var settings: SettingsWindowController?
        /// The folders with access; `main.swift` sets the app's.
        var bookmarks: FolderBookmarks?
        /// The windows of documents and of Open Folder….
        var environment = ScrollEnvironment.app
        /// Open Folder…'s panel; nil when cancelled.
        var chooseFolder: () -> URL? = { // coverage:ignore - a modal panel
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            return panel.runModal() == .OK ? panel.url : nil
        } // coverage:ignore - the closing line of the line above

        /// The document window in front.
        var frontWindow: () -> DocumentWindowController? = { // coverage:ignore - the app's key window
            NSApp.mainWindow?.windowController as? DocumentWindowController
        } // coverage:ignore - the closing line of the line above
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
            // D10: relaunch reopens every window not closed.
            UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": true])
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

        public func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
            true
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

        /// Settings… (⌘,): one window for the app's life.
        @objc func showSettings(_: Any?) {
            guard let bookmarks else { return } // coverage:ignore - main.swift sets it
            if settings == nil {
                settings = SettingsWindowController(
                    settings: ScrollSettings(defaults: environment?.defaults ?? .standard),
                    bookmarks: bookmarks,
                    cache: cache
                )
            }
            settings?.showWindow(nil)
        }

        /// Open Folder… (⇧⌘O; log 004 Round 6): the folder keeps its access and
        /// shows in the front window's sidebar, or in a new Untitled window.
        @objc func openFolder(_: Any?) {
            guard let bookmarks, let environment, let folder = chooseFolder(), bookmarks.grant(folder) else { return }
            if let window = frontWindow() {
                window.showFolder(folder)
                return
            }
            let document = ScrollDocument()
            document.environment = environment
            documents.addDocument(document)
            document.makeWindowControllers()
            (document.windowControllers.first as? DocumentWindowController)?.showFolder(folder)
            document.showWindows()
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
