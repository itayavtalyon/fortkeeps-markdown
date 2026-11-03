import Foundation

/// The folders the person granted, as security-scoped bookmarks (design
/// log 001 › Windows and chrome, Folder access). Access to each starts at
/// launch and lasts while the app runs. An iOS bookmark is security-scoped
/// without the option.
@MainActor
final class FolderBookmarks: FolderAccess {
    static let key = "FolderBookmarks"
    #if os(macOS)
        static let creationOptions: URL.BookmarkCreationOptions = .withSecurityScope
        static let resolutionOptions: URL.BookmarkResolutionOptions = .withSecurityScope
    #else
        static let creationOptions: URL.BookmarkCreationOptions = []
        static let resolutionOptions: URL.BookmarkResolutionOptions = []
    #endif

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
              folder.standardizedFileURL.pathComponents.starts(with: chosen.standardizedFileURL.pathComponents)
        else { return false }
        return grant(chosen)
    }

    /// Open Folder… on iPad: the picker, and the chosen folder keeps its access.
    func openFolder(from folder: URL) async -> URL? {
        guard let chosen = await choose(folder), grant(chosen) else { return nil }
        return chosen
    }

    /// Keeps access to a folder the person chose: the picker above, or Open Folder….
    @discardableResult
    func grant(_ folder: URL) -> Bool {
        guard let bookmark = try? folder.bookmarkData(
            options: Self.creationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return false }
        stored[folder.path(percentEncoded: false)] = bookmark
        _ = folder.startAccessingSecurityScopedResource()
        if !folders.contains(folder) {
            folders.append(folder)
        }
        return true
    }

    /// Settings › Remove (screens §3.17): the bookmark goes, and access ends.
    func remove(_ folder: URL) {
        // A restored folder's path can differ from its key: a trailing slash, or /private.
        let path = folder.resolvingSymlinksInPath().pathComponents
        stored = stored.filter { URL(fileURLWithPath: $0.key).resolvingSymlinksInPath().pathComponents != path }
        folder.stopAccessingSecurityScopedResource()
        folders.removeAll { $0 == folder }
    }

    /// A bookmark that no longer resolves, or is stale, is dropped.
    private func restore() {
        for (path, data) in stored {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: Self.resolutionOptions,
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
