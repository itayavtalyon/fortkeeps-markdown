#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The window of one document (screens §3.3): the strips, the text, and
    /// the status bar, in a system tab. It is the document's `MarkdownHost`.
    @MainActor
    final class DocumentWindowController: NSWindowController, NSMenuItemValidation, MarkdownHost {
        static let showsStatusBarKey = "ShowsStatusBar"
        static let showsFormatBarKey = "ShowsFormatBar"

        let environment: ScrollEnvironment
        let markdownView: MarkdownView
        let images: DocumentImages
        /// No write permission: Lock stays on (screens §3.13).
        let isReadOnly: Bool
        let strips = NSStackView()
        /// The strips, the text, and the status bar, right of the sidebar.
        let contentStack = NSStackView()
        let sidebar: SidebarController
        let split = SidebarSplitController()
        private let status = NSTextField(labelWithString: "")
        private let statusBar: NSStackView
        let lockItem = NSToolbarItem(itemIdentifier: .lock)
        /// The folder-access strip shows once per document per session.
        private var showsFolderStrip = false
        var outside = OutsideChange()
        /// A large file loading (screens §3.14).
        var largeLoad: LargeLoad?
        var largeLoadTask: Task<Void, Never>?
        /// The Outline loading off the main thread (log 004 Round 6).
        var outlineTask: Task<Void, Never>?
        /// Typing pauses this long before the Outline loads again.
        var outlinePause = Duration.seconds(1)

        var scrollDocument: ScrollDocument? {
            document as? ScrollDocument
        }

        /// `addWindowController(_:)` sets the document after `init`.
        override var document: AnyObject? {
            didSet { update() }
        }

        init(document: ScrollDocument, environment: ScrollEnvironment) {
            self.environment = environment
            let url = document.fileURL
            isReadOnly = url
                .map { !FileManager.default.isWritableFile(atPath: $0.path(percentEncoded: false)) } ?? false
            images = DocumentImages(transport: environment.transport, access: environment.access)
            markdownView = MarkdownView(
                text: document.text, mode: isReadOnly ? .editorLocked : .editor, documentURL: url, host: nil
            )
            statusBar = NSStackView(views: [status])
            sidebar = SidebarController(environment: environment)
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 760, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: true
            )
            window.tabbingMode = .preferred
            window.tabbingIdentifier = "ScrollDocument"
            window.setFrameAutosaveName("ScrollDocument")
            super.init(window: window)
            markdownView.host = self
            images.onRefresh = { [weak self] in self?.markdownView.refreshImage(destination: $0) }
            if let url, !environment.access.canRead(url.deletingLastPathComponent()) {
                showsFolderStrip = MarkdownDocument(
                    text: document.text, features: MarkdownFeatures(), presentation: MarkdownPresentation()
                ).needsFolder(documentURL: url)
            }
            layOut(window)
            if let folder = url?.deletingLastPathComponent(), environment.access.canRead(folder) {
                sidebar.folder = folder
            }
            refreshOutline()
            sidebar.onHeading = { [weak self] in self?.showHeading($0) }
            markdownView.onScroll = { [weak self] in self?.scrolled() }
            if document.largeFileURL != nil {
                beginLargeLoad(document)
            }
            document.onStateChange = { [weak self] in self?.update() }
            document.onOutsideChange = { [weak self] in self?.outsideChange($0) }
            NotificationCenter.default.addObserver(
                self, selector: #selector(preferencesChanged), name: UserDefaults.didChangeNotification, object: nil
            )
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private func layOut(_ window: NSWindow) {
            strips.orientation = .vertical
            strips.spacing = 0
            statusBar.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
            status.textColor = .secondaryLabelColor
            status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            contentStack.setViews([strips, markdownView, statusBar], in: .top)
            contentStack.orientation = .vertical
            contentStack.spacing = 0
            contentStack.alignment = .leading
            for view in [strips, markdownView, statusBar] {
                view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            }
            markdownView.setContentHuggingPriority(.defaultLow, for: .vertical)
            let content = NSViewController()
            content.view = contentStack
            let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
            sidebarItem.isCollapsed = !ScrollSettings(defaults: environment.defaults).showsSidebar
            split.splitViewItems = [sidebarItem, NSSplitViewItem(viewController: content)]
            let settings = ScrollSettings(defaults: environment.defaults)
            split.onToggle = { [weak self] shows in
                settings.showsSidebar = shows
                self?.refreshOutline()
                self?.invalidateRestorableState()
            }
            window.contentViewController = split
            window.setContentSize(CGSize(width: 760, height: 720))
            window.initialFirstResponder = markdownView
            let toolbar = NSToolbar(identifier: "ScrollDocument")
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            window.toolbar = toolbar
            lockItem.target = self
            lockItem.action = #selector(toggleLock)
        }

        // MARK: title (design log 001 › Windows and chrome)

        /// The compare view's title while it shows (screens §3.11).
        override func windowTitle(forDocumentDisplayName displayName: String) -> String {
            let name = scrollDocument?.fileName ?? displayName
            return outside.resolveView == nil ? name : ScrollStrings.compareTitle(name)
        }

        override func synchronizeWindowTitleWithDocumentName() {
            super.synchronizeWindowTitleWithDocumentName()
            window?.subtitle = scrollDocument?.fileURL.map {
                ($0.deletingLastPathComponent().path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
            } ?? ""
        }

        // MARK: state

        /// The status bar, the strips, and the Lock button follow the document.
        func update() {
            guard let document = scrollDocument else { return }
            if outside.keepsMine, document.saveState == .saving {
                outside.keepsMine = false
                outside.keptMine = true
            }
            let saved = outside.keptMine ? ScrollStrings.savedOver : ScrollStrings.saved
            let state = markdownView.mode == .editorLocked ? ScrollStrings.locked
                : document.saveState == .saved ? saved : ScrollStrings.saving
            // ponytail: counts the whole text per change; count off the main thread if large files lag.
            let settings = ScrollSettings(defaults: environment.defaults)
            status.stringValue = settings.showsWordCount
                ? state + " · " + ScrollStrings.words(WordCount.count(document.text)) : state
            markdownView.maxLineWidth = settings.lineWidth.points
            statusBar.isHidden = !UserDefaults.standard.bool(forKey: Self.showsStatusBarKey, default: true)
            markdownView.showsFormatBar = UserDefaults.standard.bool(forKey: Self.showsFormatBarKey, default: true)
            let locked = markdownView.mode == .editorLocked
            lockItem.label = locked ? ScrollStrings.unlock : ScrollStrings.lock
            lockItem.image = NSImage(systemSymbolName: locked ? "lock" : "lock.open", accessibilityDescription: nil)
            synchronizeWindowTitleWithDocumentName()
            markdownView.documentURL = document.fileURL
            strips.setViews(currentStrips(document), in: .top)
        }

        @objc private func allowAccess() {
            guard let folder = scrollDocument?.fileURL?.deletingLastPathComponent() else { return }
            Task {
                guard await images.requestAccess(folder) else { return }
                sidebar.folder = folder
                dismissFolderStrip()
            }
        }

        @objc private func dismissFolderStrip() {
            showsFolderStrip = false
            update()
        }

        /// A sibling link with no folder access shows the strip again.
        func showFolderStrip() {
            showsFolderStrip = true
            update()
        }

        /// The file is gone, so Close loses the text: confirm first (screens §3.12).
        @objc private func confirmClose() {
            let alert = NSAlert()
            alert.messageText = ScrollStrings.closeConfirm
            alert.addButton(withTitle: ScrollStrings.cancel)
            alert.addButton(withTitle: ScrollStrings.close).hasDestructiveAction = true
            environment.presentAlert(alert, window) { [weak self] response in
                guard response == .alertSecondButtonReturn else { return }
                self?.scrollDocument?.close()
            }
        }

        @objc private func preferencesChanged() {
            update()
        }

        // MARK: commands

        @objc func toggleLock(_: Any?) {
            guard !isReadOnly else { return }
            markdownView.mode = markdownView.mode == .editorLocked ? .editor : .editorLocked
            invalidateRestorableState()
            update()
        }

        @objc func zoomIn(_: Any?) {
            markdownView.zoom = Zoom.zoomedIn(markdownView.zoom)
        }

        @objc func zoomOut(_: Any?) {
            markdownView.zoom = Zoom.zoomedOut(markdownView.zoom)
        }

        @objc func actualSize(_: Any?) {
            markdownView.zoom = Zoom.actualSize
        }

        /// A Format menu item; its tag is the index of the action.
        @objc func format(_ sender: NSMenuItem) {
            markdownView.perform(FormatAction.allCases[sender.tag])
        }

        @objc func toggleStatusBar(_: Any?) {
            UserDefaults.standard.set(statusBar.isHidden, forKey: Self.showsStatusBarKey)
        }

        @objc func toggleFormatBar(_: Any?) {
            UserDefaults.standard.set(!markdownView.showsFormatBar, forKey: Self.showsFormatBarKey)
        }

        /// File › Save… names an untitled document; a named one has no Save.
        @objc func saveDocument(_ sender: Any?) {
            scrollDocument?.save(sender)
        }

        /// Close Window: every tab of this window.
        @objc func closeWindow(_: Any?) {
            for window in window?.tabbedWindows ?? [window].compactMap(\.self) {
                window.performClose(nil)
            }
        }

        /// Command-1 to Command-9: the tab of the item's tag.
        @objc func selectTab(_ sender: NSMenuItem) {
            let tabs = window?.tabbedWindows ?? [window].compactMap(\.self)
            guard tabs.indices.contains(sender.tag) else { return }
            tabs[sender.tag].makeKeyAndOrderFront(nil)
        }

        func validateMenuItem(_ item: NSMenuItem) -> Bool {
            switch item.action {
            case #selector(toggleLock):
                item.state = markdownView.mode == .editorLocked ? .on : .off
                return !isReadOnly
            case #selector(format):
                return markdownView.mode == .editor
            case #selector(toggleStatusBar):
                item.state = statusBar.isHidden ? .off : .on
            case #selector(toggleFormatBar):
                item.state = markdownView.showsFormatBar ? .on : .off
            case #selector(saveDocument):
                item.isHidden = scrollDocument?.fileURL != nil
                return scrollDocument?.fileURL == nil
            default:
                break
            }
            return true
        }
    }

    /// The strips over the text (screens §3.2, §3.12, §3.13; log 004 › Outside changes).
    extension DocumentWindowController {
        private func currentStrips(_ document: ScrollDocument) -> [StripView] {
            let name = document.fileName
            var views: [StripView] = []
            if outside.showsNote {
                views.append(StripView(kind: .reloaded, text: ScrollStrings.reloadNote, buttons: [
                    .init(title: ScrollStrings.undo, target: self, action: #selector(undoReload))
                ]))
            }
            if showsFolderStrip, let folder = document.fileURL?.deletingLastPathComponent() {
                views.append(StripView(
                    kind: .folderAccess,
                    text: ScrollStrings.accessBar(folder.lastPathComponent),
                    buttons: [.init(title: ScrollStrings.allowAccess, target: self, action: #selector(allowAccess))],
                    dismiss: .init(title: "", target: self, action: #selector(dismissFolderStrip))
                ))
            }
            let saveAs = StripView.Button(
                title: ScrollStrings.saveAs, target: document, action: #selector(NSDocument.saveAs(_:))
            )
            if document.isDeleted {
                views.append(StripView(kind: .deleted, text: ScrollStrings.deleted(name), buttons: [
                    saveAs, .init(title: ScrollStrings.close, target: self, action: #selector(confirmClose))
                ]))
            } else if document.saveState == .failed {
                views.append(StripView(kind: .saveFailed, text: ScrollStrings.saveFailed(name), buttons: [saveAs]))
            }
            if isReadOnly {
                views.append(StripView(kind: .readOnly, text: ScrollStrings.readOnly, buttons: [
                    .init(title: ScrollStrings.duplicate, target: document, action: #selector(NSDocument.duplicate(_:)))
                ]))
            }
            return views
        }
    }

    extension DocumentWindowController: NSToolbarDelegate {
        func toolbar(
            _: NSToolbar,
            itemForItemIdentifier _: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar _: Bool
        ) -> NSToolbarItem? {
            lockItem
        }

        /// The sidebar button shows or hides the sidebar (log 004 Round 6), as ⌃⌘S does.
        func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .lock]
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarDefaultItemIdentifiers(toolbar)
        }
    }

    /// What a document window asks of the system. The tests record it instead.
    @MainActor
    struct ScrollEnvironment {
        var transport: any ImageTransport
        var access: any FolderAccess
        /// A web or mail link: the default browser or mail app.
        var openURL: (URL) -> Void
        /// A sibling Markdown file: a tab, or the open tab of that path.
        var openFile: (URL) -> Void
        var beep: () -> Void
        /// Shows an alert as a sheet of the window; the handler gets the button.
        var presentAlert: (NSAlert, NSWindow?, @escaping (NSApplication.ModalResponse) -> Void) -> Void
        /// A short note next to the mouse in a view.
        var showPopover: (String, NSView) -> Void
        /// The save panel of Export, as a sheet, with a suggested name; nil when cancelled.
        var chooseExportURL: @MainActor (String, NSWindow?) async -> URL?
        /// The print panel, as a sheet.
        var runPrint: (NSPrintOperation, NSWindow?) -> Void
        /// Settings (screens §3.17); the tests use their own.
        var defaults: UserDefaults
        /// Copy as Rich Text; the tests use their own.
        var pasteboard: NSPasteboard

        /// The app's services; `main.swift` sets them before the app runs.
        static var app: ScrollEnvironment?
    }

    extension NSToolbarItem.Identifier {
        static let lock = NSToolbarItem.Identifier("lock")
    }

    extension UserDefaults {
        func bool(forKey key: String, default value: Bool) -> Bool {
            object(forKey: key) == nil ? value : bool(forKey: key)
        }
    }
#endif
