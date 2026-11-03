import Foundation

/// The open and the recent files (design log 002 › iPhone home screen; log
/// 001 › Windows and chrome, the iPad tabs). A file is in one list only.
public struct FileLists: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let url: URL
        public let lastOpened: Date

        public init(url: URL, lastOpened: Date) {
            self.url = url
            self.lastOpened = lastOpened
        }
    }

    public static let recentLimit = 20

    /// In the order the files opened: the iPad tab order.
    public private(set) var open: [Entry] = []
    /// Newest first.
    public private(set) var recent: [Entry] = []

    public init(open: [Entry] = [], recent: [Entry] = []) {
        self.open = open
        self.recent = Array(recent.prefix(Self.recentLimit))
    }

    /// A file already open keeps its place and takes the new time.
    public mutating func opened(_ url: URL, at date: Date) {
        recent.removeAll { $0.url == url }
        let entry = Entry(url: url, lastOpened: date)
        if let index = open.firstIndex(where: { $0.url == url }) {
            open[index] = entry
        } else {
            open.append(entry)
        }
    }

    /// The file goes to the top of Recent with the time it was last opened.
    public mutating func closed(_ url: URL, at date: Date) {
        let lastOpened = open.first { $0.url == url }?.lastOpened ?? date
        open.removeAll { $0.url == url }
        recent.removeAll { $0.url == url }
        recent.insert(Entry(url: url, lastOpened: lastOpened), at: 0)
        recent = Array(recent.prefix(Self.recentLimit))
    }

    public mutating func removeRecent(_ url: URL) {
        recent.removeAll { $0.url == url }
    }

    /// Find File… or a rename points an entry at its new path; it keeps its place in its list.
    public mutating func replace(_ url: URL, with newURL: URL) {
        let moved = { (entry: Entry) in entry.url == url ? Entry(url: newURL, lastOpened: entry.lastOpened) : entry }
        open = open.map(moved)
        recent = recent.map(moved)
    }

    /// The entries whose file name contains the query, ignoring case and
    /// the spaces around it. An empty query matches all.
    public func matching(_ query: String) -> FileLists {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return self }
        let matches = { (entry: Entry) in entry.url.lastPathComponent.localizedStandardContains(query) }
        return FileLists(open: open.filter(matches), recent: recent.filter(matches))
    }
}

public extension DocumentFile {
    /// `Untitled.md`, then `Untitled 2.md`, … The names compare ignoring case,
    /// as the file system does.
    static func untitledName(taken: [String]) -> String {
        numbered("Untitled", extension: "md", taken: taken)
    }

    /// The Duplicate of a read-only file: `Trip copy.md`, then `Trip copy 2.md`, …
    static func copyName(of name: String, taken: [String]) -> String {
        let file = URL(filePath: name)
        return numbered(
            file.deletingPathExtension().lastPathComponent + " copy",
            extension: file.pathExtension,
            taken: taken
        )
    }

    /// The name, or `Trip 2.md`, `Trip 3.md`, … when the folder has it.
    static func freeName(_ name: String, taken: [String]) -> String {
        let file = URL(filePath: name)
        return numbered(file.deletingPathExtension().lastPathComponent, extension: file.pathExtension, taken: taken)
    }

    private static func numbered(_ base: String, extension ext: String, taken: [String]) -> String {
        let taken = Set(taken.map { $0.lowercased() })
        let suffix = ext.isEmpty ? "" : "." + ext
        var number = 1
        while true {
            let name = (number == 1 ? base : "\(base) \(number)") + suffix
            if !taken.contains(name.lowercased()) {
                return name
            }
            number += 1
        }
    } // coverage:ignore - the loop leaves only by a return
}
