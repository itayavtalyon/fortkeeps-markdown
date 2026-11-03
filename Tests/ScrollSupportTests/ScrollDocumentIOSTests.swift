#if os(iOS)
    import Foundation
    import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Design › Files: one Markdown file in a `UIDocument`.
    @MainActor
    struct ScrollDocumentIOSTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ScrollDocumentIOS-\(UUID().uuidString)")

        func given(_ name: String, _ bytes: String) throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data(bytes.utf8).write(to: url)
            return url
        }

        static func opened(_ url: URL) async -> (ScrollDocument, Bool) {
            let document = ScrollDocument(fileURL: url)
            let success = await document.open()
            return (document, success)
        }

        static func change(_ reason: TextChange.Reason, _ text: String) -> TextChange {
            TextChange(reason: reason, groupReason: reason, range: NSRange(), replacement: "", text: text)
        }

        @Test
        func `a CRLF file opens as LF text, clean, and its bytes stay`() async throws {
            let url = try given("a.md", "a\r\nb")

            let (document, success) = await Self.opened(url)

            #expect(success)
            #expect(document.text == "a\nb\n")
            #expect(!document.hasUnsavedChanges)
            #expect(document.fileName == "a.md")
            await document.closeOnMain()
            #expect(try Data(contentsOf: url) == Data("a\r\nb".utf8))
        }

        @Test
        func `a file that is not UTF-8 is refused`() throws {
            let document = try ScrollDocument(fileURL: given("a.md", "a"))

            #expect(throws: OpenRefusal.notUTF8) {
                try document.load(fromContents: Data([0xFF]), ofType: nil)
            }
            #expect(throws: OpenRefusal.notUTF8) {
                try document.load(fromContents: "not data", ofType: nil)
            }
        }

        @Test
        func `an edit marks the document dirty and does not save`() async throws {
            let url = try given("a.md", "a\n")
            let (document, _) = await Self.opened(url)

            document.apply(Self.change(.edit, "ab\n"))

            #expect(document.hasUnsavedChanges)
            #expect(try Data(contentsOf: url) == Data("a\n".utf8))
            await document.closeOnMain()
        }

        @Test(.timeLimit(.minutes(2)))
        func `a checkbox change saves at once, and a reload stays clean`() async throws {
            let url = try given("a.md", "- [ ] a\r\n")
            let (document, _) = await Self.opened(url)
            var states = 0
            document.onStateChange = { states += 1 }

            document.apply(Self.change(.reload, "- [ ] a\n"))
            #expect(!document.hasUnsavedChanges)
            document.apply(Self.change(.checkbox, "- [x] a\n"))

            while (try? Data(contentsOf: url)) != Data("- [x] a\n".utf8) {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(states > 0)
            while document.hasUnsavedChanges {
                try await Task.sleep(for: .milliseconds(10))
            }
            await document.closeOnMain()
        }

        static func autosaved(_ document: ScrollDocument) async -> Bool {
            await withCheckedContinuation { done in document.autosave { done.resume(returning: $0) } }
        }

        @Test
        func `a deleted file pauses the checkbox save and autosave, and keeps the text`() async throws {
            let url = try given("a.md", "- [ ] a\n")
            let (document, _) = await Self.opened(url)
            try FileManager.default.removeItem(at: url)

            document.apply(Self.change(.checkbox, "- [x] a\n"))

            #expect(document.isDeleted)
            #expect(await Self.autosaved(document) == false)
            #expect(!FileManager.default.fileExists(atPath: url.path()))
            #expect(document.text == "- [x] a\n")
            await document.closeOnMain()
            #expect(!FileManager.default.fileExists(atPath: url.path()))
        }

        @Test(.timeLimit(.minutes(2)))
        func `a deletion or a move to the Trash marks the file deleted; another move renames`() async throws {
            let (document, _) = try await Self.opened(given("a.md", "a\n"))
            var states = 0
            document.onStateChange = { states += 1 }

            document.noteMoved(from: document.fileURL, to: folder.appending(path: "b.md"))
            #expect(!document.isDeleted)
            #expect(states == 1)
            document.presentedItemDidMove(to: folder.appending(path: ".Trash/b.md"))
            while !document.isDeleted {
                try await Task.sleep(for: .milliseconds(10))
            }

            let (other, _) = try await Self.opened(given("c.md", "c\n"))
            other.accommodatePresentedItemDeletion { _ in }
            while !other.isDeleted {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test(.timeLimit(.minutes(2)))
        func `a failed save marks the document failed and keeps the text`() async throws {
            let url = try given("a.md", "a\n")
            let (document, _) = await Self.opened(url)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path())
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path())
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path())
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path())
            }
            #expect(!document.saveFailed)
            var outsideChanges: [DiskWatch.Change] = []
            document.onOutsideChange = { outsideChanges.append($0) }

            document.apply(Self.change(.edit, "ab\n"))

            #expect(await Self.autosaved(document) == false)
            while !document.saveFailed {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(document.text == "ab\n")
            #expect(try Data(contentsOf: url) == Data("a\n".utf8))
            // The bytes it did not write are not on disk: the file is still its own.
            document.noteChangeOnDisk()
            #expect(outsideChanges.isEmpty)
        }

        /// Not opened, so no file presenter calls in on its own.
        @Test
        func `the bytes it read are no outside change, even with edits`() throws {
            let document = try ScrollDocument(fileURL: given("a.md", "a\n"))
            try document.load(fromContents: Data("a\n".utf8), ofType: nil)
            var outsideChanges: [DiskWatch.Change] = []
            document.onOutsideChange = { outsideChanges.append($0) }
            document.apply(Self.change(.edit, "b\n"))

            document.noteChangeOnDisk()

            #expect(outsideChanges.isEmpty)
        }
    }
#endif
