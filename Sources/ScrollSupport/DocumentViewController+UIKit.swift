#if os(iOS)
    import MarkdownViews
    import UIKit

    /// One document on iPhone and in an iPad tab (screens §3.20): the title
    /// block, the text, and the ⋯ menu. It is the document's `MarkdownHost`.
    @MainActor
    final class DocumentViewController: UIViewController, MarkdownHost, UIDocumentPickerDelegate {
        let document: ScrollDocument
        let environment: ScrollEnvironment
        let markdownView: MarkdownView
        /// The strips under the nav bar (screens §3.12, §3.13, §3.21).
        let strips = UIStackView()
        let images: DocumentImages
        /// No write permission: Lock stays on (screens §3.13).
        let isReadOnly: Bool
        /// A new file opens with the keyboard up.
        var startsTyping = false
        /// A file over 5 MB loads after the screen shows (screens §3.14).
        var largeLoad: LargeLoadView?
        var largeLoadTask: Task<Void, Never>?
        /// The Outline loading off the main thread (log 004 Round 6).
        var outlineTask: Task<Void, Never>?
        /// Typing pauses this long before the Outline loads again.
        var outlinePause = Duration.seconds(1)
        /// The large file could not be read: the session refuses it.
        var onLargeRefusal: (() -> Void)?
        /// A relaunch's place in the text, set once the text is laid out.
        private var restoredAnchor: MarkdownAnchor?
        /// The open files of the scene, for Move to Trash.
        weak var session: DocumentSession?
        /// The iPad tabs show this screen's title and menu in their bar.
        var onUpdate: (() -> Void)?
        var outside = OutsideChange()
        /// The sidebar that shows this screen's Outline.
        weak var sidebar: SidebarViewController?

        init(document: ScrollDocument, environment: ScrollEnvironment) {
            self.document = document
            self.environment = environment
            isReadOnly = !FileManager.default.isWritableFile(atPath: document.fileURL.path(percentEncoded: false))
            images = DocumentImages(transport: environment.transport, access: environment.access)
            markdownView = MarkdownView(
                text: document.text,
                mode: isReadOnly ? .editorLocked : .editor,
                documentURL: document.fileURL,
                host: nil
            )
            super.init(nibName: nil, bundle: nil)
            markdownView.host = self
            images.onRefresh = { [weak self] in self?.markdownView.refreshImage(destination: $0) }
            document.onStateChange = { [weak self] in self?.update() }
            document.onOutsideChange = { [weak self] in self?.outsideChange($0) }
            navigationItem.largeTitleDisplayMode = .always
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle")),
                UIBarButtonItem(systemItem: .action, primaryAction: UIAction { [weak self] _ in self?.share() }),
                UIBarButtonItem(
                    image: UIImage(systemName: "list.bullet"),
                    primaryAction: UIAction { [weak self] _ in self?.showSidebar() }
                )
            ]
            navigationItem.rightBarButtonItems?[2].accessibilityLabel = ScrollStrings.outlineTitle
            markdownView.onScroll = { [weak self] in
                guard let self else { return } // coverage:ignore - the view goes with its screen
                sidebar?.follow(markdownView.currentOutlineIndex)
            }
            NotificationCenter.default.addObserver(
                self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification,
                object: environment.defaults
            )
            update()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// The text fills the screen; the strips sit under the nav bar and push
        /// the safe area, and so the text, down by their height.
        override func loadView() {
            view = UIView()
            strips.axis = .vertical
            for subview in [markdownView, strips] {
                subview.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(subview)
            }
            NSLayoutConstraint.activate([
                markdownView.topAnchor.constraint(equalTo: view.topAnchor),
                markdownView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                markdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                markdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                strips.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                strips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                strips.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            additionalSafeAreaInsets.top = strips.frame.height
            // The text has its width only now, so the kept place shows where it was.
            guard let anchor = restoredAnchor, view.bounds.width > 0, largeLoad == nil else { return }
            restoredAnchor = nil
            markdownView.layoutIfNeeded()
            markdownView.anchor = anchor
        }

        // MARK: state

        /// The folder and the save state, under the file name.
        var statusText: String {
            let saved = outside.keptMine ? ScrollStrings.savedOver : ScrollStrings.saved
            let state = markdownView.mode == .editorLocked ? ScrollStrings.locked
                : document.hasUnsavedChanges ? ScrollStrings.saving : saved
            return document.fileURL.deletingLastPathComponent().lastPathComponent + " · " + state
        }

        func update() {
            title = document.fileName
            markdownView.accessibilityLabel = document.fileName
            markdownView.documentURL = document.fileURL
            navigationItem.showStatus(statusText)
            navigationItem.rightBarButtonItem?.menu = moreMenu()
            markdownView.maxLineWidth = ScrollSettings(defaults: environment.defaults).lineWidth.points
            showStrips()
            onUpdate?()
        }

        private func showStrips() {
            let name = document.fileName
            let saveAs: (title: String, run: () -> Void) = (ScrollStrings.saveAs, { [weak self] in self?.saveAs() })
            var shown: [StripView] = []
            if let note = noteStrip() {
                shown.append(note)
            }
            if document.isDeleted {
                shown.append(StripView(kind: .deleted, text: ScrollStrings.deleted(name), buttons: [
                    saveAs, (ScrollStrings.close, { [weak self] in self?.confirmClose() })
                ]))
            } else if document.saveFailed {
                shown.append(StripView(kind: .saveFailed, text: ScrollStrings.saveFailed(name), buttons: [saveAs]))
            }
            if isReadOnly {
                shown.append(StripView(kind: .readOnly, text: ScrollStrings.readOnly, buttons: [
                    (ScrollStrings.duplicate, { [weak self] in self?.duplicate() })
                ]))
            }
            // Each change updates the screen: keep the strips VoiceOver may be on.
            guard shown.map(\.accessibilityLabel) != strips.arrangedSubviews.map(\.accessibilityLabel) else { return }
            strips.arrangedSubviews.forEach { $0.removeFromSuperview() }
            shown.forEach(strips.addArrangedSubview)
            view.setNeedsLayout()
        }

        // MARK: strip buttons

        /// The text as a file of the same name, for the Files export sheet.
        func exportCopy() throws -> URL {
            try temporaryFile(document.fileName, DocumentFile.data(for: document.text))
        }

        /// A file in a folder of its own, so its name is the one the sheet shows.
        func temporaryFile(_ name: String, _ data: Data) throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try data.write(to: url)
            return url
        }

        /// The Files export sheet; the saved copy opens.
        private func saveAs() {
            do {
                let picker = try UIDocumentPickerViewController(forExporting: [exportCopy()], asCopy: true)
                picker.delegate = self
                environment.present(picker, self)
            } catch {
                showError(error) // coverage:ignore - the app's temporary folder is always writable
            }
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            environment.openFile(url)
        }

        /// The file is gone, so Close loses the text: confirm first (screens §3.12).
        private func confirmClose() {
            let alert = UIAlertController(title: ScrollStrings.closeConfirm, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: ScrollStrings.cancel, style: .cancel))
            alert.addAction(UIAlertAction(title: ScrollStrings.close, style: .destructive) { [weak self] _ in
                guard let self else { return }
                environment.closeFile(document.fileURL)
            })
            environment.present(alert, self)
        }

        /// `{name} copy` in the app's folder, opened at once (log 004, Round 4).
        func duplicate() {
            do {
                let name = document.fileName
                let copy = try environment.newAppFile(DocumentFile.data(for: document.text)) {
                    DocumentFile.copyName(of: name, taken: $0)
                }
                environment.openFile(copy)
            } catch {
                showError(error)
            }
        }

        func showError(_ error: any Error) {
            let alert = UIAlertController(title: error.localizedDescription, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: ScrollStrings.ok, style: .default))
            environment.present(alert, self)
        }

        // MARK: commands

        override var keyCommands: [UIKeyCommand]? {
            [UIKeyCommand(
                title: markdownView.mode == .editorLocked ? ScrollStrings.unlock : ScrollStrings.lock,
                action: #selector(toggleLock),
                input: "l",
                modifierFlags: [.command, .alternate]
            )]
        }

        @objc func toggleLock() {
            guard !isReadOnly else { return }
            let lock = markdownView.mode != .editorLocked
            markdownView.modeSwitchAnnouncement = lock ? ScrollStrings.locked : nil
            markdownView.mode = lock ? .editorLocked : .editor
            update()
        }

        // MARK: MarkdownHost

        nonisolated func image(for request: ImageRequest) async -> ImageResult {
            await images.image(for: request)
        }

        func textDidChange(_ change: TextChange) {
            // A reload clears them too; a quiet reload shows its note after.
            outside.showsNote = false
            outside.keptMine = false
            document.apply(change)
            refreshOutline(after: change.reason == .reload ? .zero : outlinePause)
            update()
        }

        func activateImage(_ activation: ImageActivation) {
            images.activateImage(activation)
        }

        func reloadImage(_ request: ImageRequest) {
            images.reloadImage(request)
        }

        func loadAllImages() {
            images.loadAllImages(in: markdownView.text, documentURL: document.fileURL)
        }

        /// The browser or mail app, the app for a sibling file, the heading
        /// of a fragment; any other link does nothing (log 001 › Links).
        func open(_ link: LinkActivation) {
            switch LinkRules.classify(link.destination, documentURL: link.documentURL) {
            case let .browser(url), let .mail(url):
                environment.openURL(url)
            case let .siblingFile(url):
                Task { await openSibling(url) }
            case let .fragment(slug):
                markdownView.showHeading(fragment: slug)
            case .none:
                break
            }
        }

        /// No folder access asks for the folder first (log 001 › Folder access).
        func openSibling(_ url: URL) async {
            let folder = url.deletingLastPathComponent()
            if !environment.access.canRead(folder) {
                guard await images.requestAccess(folder) else { return }
            }
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                let alert = UIAlertController(
                    title: ScrollStrings.notInFolder(url.lastPathComponent), message: nil, preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: ScrollStrings.ok, style: .default))
                environment.present(alert, self)
                return
            }
            environment.openFile(url)
        }
    }

    // MARK: Settings, the sidebar sheet, and relaunch

    extension DocumentViewController {
        /// An in-app sheet (screens §3.17).
        func showSettings() {
            let settings = SettingsViewController(
                settings: ScrollSettings(defaults: environment.defaults),
                bookmarks: environment.access as? FolderBookmarks,
                cache: environment.cache
            )
            environment.present(UINavigationController(rootViewController: settings), self)
        }

        /// ☰ on iPhone: the Outline and the folder in a sheet.
        func showSidebar() {
            let sidebar = SidebarViewController(environment: environment)
            sidebar.session = session
            sidebar.show(self)
            sidebar.onChoose = { [weak sidebar] in sidebar?.dismiss(animated: true) }
            let sheet = UINavigationController(rootViewController: sidebar)
            sheet.sheetPresentationController?.detents = [.medium(), .large()]
            environment.present(sheet, self)
        }

        /// Settings changed here or on another screen.
        @objc func settingsChanged() {
            update()
        }

        // MARK: relaunch (log 001 Q14)

        var place: FileListStore.Place {
            // A place not yet applied (the screen not laid out, or still loading) is still the place.
            FileListStore.Place(
                anchor: restoredAnchor ?? markdownView.anchor,
                locked: markdownView.mode == .editorLocked
            )
        }

        func restore(_ place: FileListStore.Place) {
            if place.locked != (markdownView.mode == .editorLocked) {
                toggleLock()
            }
            restoredAnchor = place.anchor
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard startsTyping else { return }
            startsTyping = false
            _ = markdownView.becomeFirstResponder()
        }
    }

    extension UINavigationItem {
        /// The second line of the title block: the subtitle, or the prompt before iOS 26.
        func showStatus(_ text: String?) {
            if #available(iOS 26, *) {
                subtitle = text
            } else {
                prompt = text // coverage:ignore - iOS 18 to 25; the tests run on 26 and later
            } // coverage:ignore - the closing line of the branch above
        }
    }

    /// What a document screen asks of the system. The tests record it instead.
    @MainActor
    struct ScrollEnvironment {
        var transport: any ImageTransport
        var access: any FolderAccess
        /// A web or mail link: the default browser or mail app.
        var openURL: (URL) -> Void
        /// A sibling Markdown file: its tab, or the screen of that file.
        var openFile: (URL) -> Void
        /// Close on the deleted strip: the tab or the screen of the file goes.
        var closeFile: (URL) -> Void
        /// Presents a sheet or an alert over a screen.
        var present: (UIViewController, UIViewController) -> Void
        /// On My iPhone › FK Scroll: where New File and Duplicate write (log 004, Round 4).
        var appFolder: URL
        /// Print in the ⋯ menu: the system print sheet.
        var runPrint: (UIPrintInteractionController, UIViewController) -> Void
        /// Settings (screens §3.17), kept for every screen.
        var defaults: UserDefaults
        /// Copy as rich text.
        var pasteboard: UIPasteboard
        /// The remote images on disk; Settings clears it.
        var cache: ImageCache

        /// The app's services; the app delegate sets them before the first scene.
        static var app: ScrollEnvironment?

        /// A new file in the app's folder, under a name the folder does not have yet.
        func newAppFile(_ data: Data, name: ([String]) -> String) throws -> URL {
            let taken = (try? FileManager.default.contentsOfDirectory(atPath: appFolder.path(percentEncoded: false)))
            let url = appFolder.appending(path: name(taken ?? []))
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            try data.write(to: url, options: .withoutOverwriting)
            return url
        }
    }
#endif
