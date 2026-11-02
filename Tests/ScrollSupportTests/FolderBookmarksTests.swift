#if os(macOS)
    import AppKit
    @testable import ScrollSupport
    import Testing

    /// Design › Windows and chrome, Folder access: one bookmark per folder.
    @MainActor
    struct FolderBookmarksTests {
        let root = FileManager.default.temporaryDirectory.appending(path: "FolderBookmarksTests-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "FolderBookmarksTests-\(UUID().uuidString)") ?? .standard

        func folder(_ path: String) throws -> URL {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        @Test
        func `a granted folder or a parent of it is kept, and a new launch still has it`() async throws {
            let docs = try folder("a/docs")
            let bookmarks = FolderBookmarks(defaults: defaults) { _ in docs.deletingLastPathComponent() }

            #expect(await bookmarks.request(docs))
            #expect(FolderBookmarks(defaults: defaults) { _ in nil }.folders.map(\.lastPathComponent) == ["a"])
        }

        @Test
        func `a cancelled picker or another folder grants nothing`() async throws {
            let docs = try folder("a/docs")
            let other = try folder("b")

            #expect(await !FolderBookmarks(defaults: defaults) { _ in nil }.request(docs))
            #expect(await !FolderBookmarks(defaults: defaults) { _ in other }.request(docs))
            #expect(FolderBookmarks(defaults: defaults) { _ in nil }.folders.isEmpty)
        }

        @Test
        func `the picker opens at the document folder`() async throws {
            let docs = try folder("a/docs")
            var asked: URL?
            let bookmarks = FolderBookmarks(defaults: defaults) { folder in
                asked = folder
                return nil
            }

            _ = await bookmarks.request(docs)

            #expect(asked == docs)
        }

        @Test
        func `a folder is readable when the system lets the app list it`() throws {
            let bookmarks = FolderBookmarks(defaults: defaults) { _ in nil }

            #expect(try bookmarks.canRead(folder("a")))
            #expect(!bookmarks.canRead(root.appending(path: "missing")))
        }

        @Test
        func `a broken bookmark is dropped`() {
            defaults.set(["/gone": Data("not a bookmark".utf8)], forKey: FolderBookmarks.key)

            #expect(FolderBookmarks(defaults: defaults) { _ in nil }.folders.isEmpty)
        }
    }
#endif
