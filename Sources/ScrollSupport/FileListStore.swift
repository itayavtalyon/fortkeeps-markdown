import Foundation
import MarkdownCore

/// The open and recent files of the iOS app, kept as bookmarks so files
/// reopen without asking again (design log 002 › iPhone home screen).
@MainActor
final class FileListStore {
    static let key = "FileLists"

    private struct Item: Codable {
        var bookmark: Data?
        var path: String
        var lastOpened: Date
        var isOpen: Bool
    }

    private let defaults: UserDefaults
    private(set) var lists = FileLists()
    /// The files whose bookmark no longer resolves, at their last path.
    private(set) var missing: Set<URL> = []
    private var bookmarks: [URL: Data] = [:]
    /// The home screen and the tabs follow the lists.
    var onChange: (() -> Void)?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let items = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? []
        var open: [FileLists.Entry] = []
        var recent: [FileLists.Entry] = []
        for item in items {
            let url = resolve(item)
            let entry = FileLists.Entry(url: url, lastOpened: item.lastOpened)
            if item.isOpen {
                open.append(entry)
            } else {
                recent.append(entry)
            }
        }
        lists = FileLists(open: open, recent: recent)
    }

    private func resolve(_ item: Item) -> URL {
        var isStale = false
        guard let data = item.bookmark,
              let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        else {
            let url = URL(filePath: item.path)
            missing.insert(url)
            bookmarks[url] = item.bookmark
            return url
        }
        let key = Self.key(url)
        bookmarks[key] = isStale ? try? url.bookmarkData() : data
        return key
    }

    /// A bookmark resolves to `/private/var/…` where the picker gave
    /// `/var/…`: the lists keep one form of each path.
    static func key(_ url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }

    func opened(_ url: URL, at date: Date) {
        let url = remember(url)
        lists.opened(url, at: date)
        save()
    }

    func closed(_ url: URL, at date: Date) {
        lists.closed(remember(url), at: date)
        save()
    }

    func removeRecent(_ url: URL) {
        lists.removeRecent(Self.key(url))
        save()
    }

    /// Find File… chose the file again.
    func found(_ url: URL, at newURL: URL) {
        missing.remove(url)
        lists.replaceRecent(url, with: remember(newURL))
        save()
    }

    private func remember(_ url: URL) -> URL {
        let key = Self.key(url)
        missing.remove(key)
        // A picked file outside the sandbox makes its bookmark only while accessed.
        let accessing = url.startAccessingSecurityScopedResource()
        bookmarks[key] = try? url.bookmarkData()
        if accessing {
            url.stopAccessingSecurityScopedResource() // coverage:ignore - a picked file outside the sandbox
        }
        return key
    }

    private func save() {
        let items = lists.open.map { item($0, isOpen: true) } + lists.recent.map { item($0, isOpen: false) }
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.key)
        onChange?()
    }

    private func item(_ entry: FileLists.Entry, isOpen: Bool) -> Item {
        Item(
            bookmark: bookmarks[entry.url],
            path: entry.url.path(percentEncoded: false),
            lastOpened: entry.lastOpened,
            isOpen: isOpen
        )
    }
}
