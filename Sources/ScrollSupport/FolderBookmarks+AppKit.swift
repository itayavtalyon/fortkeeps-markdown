#if os(macOS)
    import AppKit

    /// The folders the person granted, as security-scoped bookmarks (design
    /// log 001 › Windows and chrome, Folder access). Access to each starts at
    /// launch and lasts while the app runs.
    @MainActor
    final class FolderBookmarks: FolderAccess {
        static let key = "FolderBookmarks"

        private let defaults: UserDefaults
        /// The folder picker, opened at the document's folder; nil when cancelled.
        private let choose: @MainActor (URL) async -> URL?
        private(set) var folders: [URL] = []

        init(defaults: UserDefaults, choose: @escaping @MainActor (URL) async -> URL?) {
            self.defaults = defaults
            self.choose = choose
            restore()
        }

        /// The bookmarks by path.
        private var stored: [String: Data] {
            get { defaults.dictionary(forKey: Self.key) as? [String: Data] ?? [:] }
            set { defaults.set(newValue, forKey: Self.key) }
        }

        /// The sandbox lets the app list the folder.
        nonisolated func canRead(_ folder: URL) -> Bool {
            (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) != nil
        }

        /// True when the person chose the folder or a folder that holds it.
        func request(_ folder: URL) async -> Bool {
            guard let chosen = await choose(folder),
                  folder.standardizedFileURL.pathComponents.starts(with: chosen.standardizedFileURL.pathComponents),
                  let bookmark = try? chosen.bookmarkData(
                      options: .withSecurityScope,
                      includingResourceValuesForKeys: nil,
                      relativeTo: nil
                  )
            else { return false }
            stored[chosen.path(percentEncoded: false)] = bookmark
            _ = chosen.startAccessingSecurityScopedResource()
            folders.append(chosen)
            return true
        }

        /// A bookmark that no longer resolves, or is stale, is dropped.
        private func restore() {
            for (path, data) in stored {
                var isStale = false
                guard let url = try? URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ),
                    !isStale
                else {
                    stored[path] = nil
                    continue
                }
                _ = url.startAccessingSecurityScopedResource()
                folders.append(url)
            }
        }
    }
#endif
