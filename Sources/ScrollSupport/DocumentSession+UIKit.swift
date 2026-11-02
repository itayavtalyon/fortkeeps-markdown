#if os(iOS)
    import MarkdownViews
    import UIKit

    /// The open documents of the iOS app, one screen per file (design log 001
    /// › Files), and the open and recent lists they keep (log 002).
    @MainActor
    final class DocumentSession {
        let store: FileListStore
        let environment: ScrollEnvironment
        private var screens: [URL: DocumentViewController] = [:]
        /// A picked file outside the sandbox: the URL that holds its access.
        private var scoped: [URL: URL] = [:]
        /// A second tap while the file opens waits for the first open.
        private var opening: [URL: Task<DocumentViewController?, Never>] = [:]
        /// The screen that shows the refusal alerts.
        weak var alertHost: UIViewController?

        init(store: FileListStore, environment: ScrollEnvironment) {
            self.store = store
            self.environment = environment
        }

        func screen(for url: URL) -> DocumentViewController? {
            screens[FileListStore.key(url)]
        }

        /// The screen of the file, opening it first; nil when refused.
        func open(_ url: URL) async -> DocumentViewController? {
            let key = FileListStore.key(url)
            if let screen = screens[key] {
                store.opened(url, at: .now)
                return screen
            }
            if let pending = opening[key] {
                return await pending.value
            }
            let pending = Task { await load(url, key: key) }
            opening[key] = pending
            defer { opening[key] = nil }
            return await pending.value
        }

        private func load(_ url: URL, key: URL) async -> DocumentViewController? {
            guard DocumentFile.accepts(url) else {
                refuse(url, ScrollStrings.wrongExtension)
                return nil
            }
            let accessing = url.startAccessingSecurityScopedResource()
            let document = ScrollDocument(fileURL: url)
            guard await document.open() else {
                if accessing {
                    url.stopAccessingSecurityScopedResource() // coverage:ignore - a picked file outside the sandbox
                }
                let reason = document.lastError
                refuse(url, (reason as? OpenRefusal)?.message ?? reason?.localizedDescription)
                return nil
            }
            let screen = DocumentViewController(document: document, environment: environment)
            document.onMove = { [weak self] in self?.moved($0, to: $1) }
            screens[key] = screen
            if accessing {
                scoped[key] = url // coverage:ignore - a picked file outside the sandbox
            }
            store.opened(url, at: .now)
            return screen
        }

        /// A rename keeps the screen and the row, under the new path.
        private func moved(_ url: URL, to newURL: URL) {
            let key = FileListStore.key(url)
            let newKey = FileListStore.key(newURL)
            screens[newKey] = screens.removeValue(forKey: key)
            scoped[newKey] = scoped.removeValue(forKey: key)
            store.moved(url, to: newURL)
        }

        /// An Open file from before a relaunch has no screen yet.
        func close(_ url: URL) async {
            let key = FileListStore.key(url)
            if let screen = screens.removeValue(forKey: key) {
                await screen.document.closeOnMain()
                scoped.removeValue(forKey: key)?.stopAccessingSecurityScopedResource()
            }
            guard store.lists.open.contains(where: { $0.url == key }) else { return }
            store.closed(url, at: .now)
        }

        /// `Untitled.md`, then `Untitled 2.md`, … in the app's folder (log 004, Round 4).
        func newFile() async -> DocumentViewController? {
            do {
                return try await open(environment.newAppFile(Data(), name: DocumentFile.untitledName(taken:)))
            } catch {
                refuse(
                    environment.appFolder.appending(path: DocumentFile.untitledName(taken: [])),
                    error.localizedDescription
                )
                return nil
            }
        }

        func refuse(_ url: URL, _ message: String?) {
            guard let alertHost else { return } // coverage:ignore - every screen sets the host before it opens a file
            let alert = UIAlertController(
                title: ScrollStrings.cannotOpen(url.lastPathComponent), message: message, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: ScrollStrings.ok, style: .default))
            environment.present(alert, alertHost)
        }
    }
#endif
