import Foundation
import MarkdownCore

/// The open and recent files of the iOS app, kept as bookmarks so files
/// reopen without asking again (design log 002 › iPhone home screen).
@MainActor
final class FileListStore {
    static let key = "FileLists"

    /// Where a file was left (log 001 Q14): the place in the text and Lock.
    struct Place: Codable, Equatable {
        var anchor: MarkdownAnchor
        var locked: Bool
    }

    private struct Item: Codable {
        var bookmark: Data?
        var path: String
        var lastOpened: Date
        var isOpen: Bool
        var place: Place?
    }

    private let defaults: UserDefaults
    private(set) var lists = FileLists()
    /// The files whose bookmark no longer resolves, at their last path.
    private(set) var missing: Set<URL> = []
    private var bookmarks: [URL: Data] = [:]
    private var places: [URL: Place] = [:]
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
            places[url] = item.place
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
        lists.replace(url, with: remember(newURL))
        save()
    }

    /// A rename or a move: the row keeps its place under the new path.
    func moved(_ url: URL, to newURL: URL) {
        let place = places.removeValue(forKey: Self.key(url))
        let newURL = remember(newURL)
        places[newURL] = place
        lists.replace(Self.key(url), with: newURL)
        save()
    }

    func place(of url: URL) -> Place? {
        places[Self.key(url)]
    }

    /// A screen closes, or the app goes to the background.
    func keep(_ place: Place, for url: URL) {
        places[Self.key(url)] = place
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
            isOpen: isOpen,
            place: places[entry.url]
        )
    }
}
