import Foundation
import MarkdownCore
@testable import ScrollSupport
import Testing

/// Design › iPhone home screen (log 002): both lists persist bookmarks, so
/// files reopen without asking again; a bookmark that fails marks the file missing.
@MainActor
struct FileListStoreTests {
    let defaults = UserDefaults(suiteName: "FileListStoreTests-\(UUID().uuidString)") ?? .standard
    let folder = FileManager.default.temporaryDirectory.appending(path: "FileListStore-\(UUID().uuidString)")
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func file(_ name: String) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Data("a\n".utf8).write(to: url)
        return url.resolvingSymlinksInPath()
    }

    @Test
    func `the lists come back after a relaunch`() throws {
        let store = FileListStore(defaults: defaults)
        let first = try file("a.md")
        let second = try file("b.md")
        store.opened(first, at: start)
        store.opened(second, at: start + 60)
        store.closed(second, at: start + 120)

        let relaunched = FileListStore(defaults: defaults)

        #expect(relaunched.lists.open.map(\.url) == [first])
        #expect(relaunched.lists.recent.map(\.url) == [second])
        #expect(relaunched.lists.recent.map(\.lastOpened) == [start + 60])
        #expect(relaunched.missing.isEmpty)
    }

    @Test
    func `a file that is gone comes back missing at its old path`() throws {
        let store = FileListStore(defaults: defaults)
        let url = try file("a.md")
        store.closed(url, at: start)
        try FileManager.default.removeItem(at: url)

        let relaunched = FileListStore(defaults: defaults)

        #expect(relaunched.lists.recent.map(\.url.lastPathComponent) == ["a.md"])
        #expect(relaunched.missing == Set(relaunched.lists.recent.map(\.url)))
    }

    @Test
    func `a missing file that is back and opens is no longer missing`() throws {
        let url = try file("a.md")
        FileListStore(defaults: defaults).closed(url, at: start)
        try FileManager.default.removeItem(at: url)
        let relaunched = FileListStore(defaults: defaults)
        let missing = try #require(relaunched.missing.first)

        try Data("a\n".utf8).write(to: missing)
        relaunched.opened(missing, at: start + 60)

        #expect(relaunched.missing.isEmpty)
    }

    @Test
    func `a found file replaces the missing one and keeps its place`() throws {
        let store = FileListStore(defaults: defaults)
        let gone = try file("a.md")
        store.closed(gone, at: start)
        try store.closed(file("b.md"), at: start + 60)
        try FileManager.default.removeItem(at: gone)
        let relaunched = FileListStore(defaults: defaults)
        let missing = try #require(relaunched.missing.first)
        let found = try file("found.md")

        relaunched.found(missing, at: found)

        #expect(relaunched.lists.recent.map(\.url.lastPathComponent) == ["b.md", "found.md"])
        #expect(relaunched.missing.isEmpty)
        #expect(FileListStore(defaults: defaults).lists.recent.last?.url == found)
    }

    @Test
    func `removing a Recent file forgets it`() throws {
        let store = FileListStore(defaults: defaults)
        let url = try file("a.md")
        store.closed(url, at: start)

        store.removeRecent(url)

        #expect(store.lists.recent.isEmpty)
        #expect(FileListStore(defaults: defaults).lists.recent.isEmpty)
    }

    @Test
    func `stored data that is not the store's reads as empty lists`() {
        defaults.set(Data("x".utf8), forKey: FileListStore.key)

        #expect(FileListStore(defaults: defaults).lists == FileLists())
    }

    @Test
    func `each change tells the screens`() throws {
        let store = FileListStore(defaults: defaults)
        var changes = 0
        store.onChange = { changes += 1 }

        try store.opened(file("a.md"), at: start)

        #expect(changes == 1)
    }

    @Test
    func `a renamed file keeps its row, under the new path, after a relaunch`() throws {
        let store = FileListStore(defaults: defaults)
        let first = try file("a.md")
        store.opened(first, at: start)
        let moved = folder.appending(path: "b.md").resolvingSymlinksInPath()
        try FileManager.default.moveItem(at: first, to: moved)

        store.moved(first, to: moved)

        #expect(store.lists.open.map(\.url) == [moved])
        #expect(FileListStore(defaults: defaults).lists.open.map(\.url) == [moved])
    }
}
