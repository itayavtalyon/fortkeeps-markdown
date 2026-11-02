#if os(macOS)
    import AppKit
    import Foundation
    import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// Design › Files: one Markdown file in an `NSDocument`.
    @MainActor
    struct ScrollDocumentTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ScrollDocumentTests-\(UUID().uuidString)")

        init() {
            _ = TestApp.controller
        }

        func given(_ name: String, _ bytes: String) throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data(bytes.utf8).write(to: url)
            return url
        }

        func change(_ reason: TextChange.Reason, _ text: String) -> TextChange {
            TextChange(reason: reason, groupReason: reason, range: NSRange(), replacement: "", text: text)
        }

        @Test
        func `a CRLF file opens as LF text, clean, and its bytes stay`() throws {
            let url = try given("a.md", "a\r\nb")

            let document = try ScrollDocument(contentsOf: url, ofType: ScrollDocument.typeName)

            #expect(document.text == "a\nb\n")
            #expect(!document.isDocumentEdited)
            #expect(try Data(contentsOf: url) == Data("a\r\nb".utf8))
        }

        @Test
        func `a file that is not UTF-8 is refused`() throws {
            let url = try given("a.md", "")
            try Data([0xFF, 0xFE]).write(to: url)

            #expect(throws: OpenRefusal.notUTF8) {
                try ScrollDocument(contentsOf: url, ofType: ScrollDocument.typeName)
            }
        }

        @Test
        func `a save writes the normalized text`() throws {
            let document = ScrollDocument()
            document.apply(change(.edit, "a\r\nb"))

            #expect(try document.data(ofType: ScrollDocument.typeName) == Data("a\nb\n".utf8))
        }

        @Test
        func `an edit marks the document dirty and does not save`() throws {
            let url = try given("a.md", "- [ ] a\n")
            let document = try ScrollDocument(contentsOf: url, ofType: ScrollDocument.typeName)

            document.apply(change(.edit, "- [ ] ab\n"))

            #expect(document.isDocumentEdited)
            #expect(try Data(contentsOf: url) == Data("- [ ] a\n".utf8))
        }

        @Test(.timeLimit(.minutes(1)))
        func `a checkbox change saves at once`() async throws {
            let url = try given("a.md", "- [ ] a\r\n")
            let document = try ScrollDocument(contentsOf: url, ofType: ScrollDocument.typeName)

            document.apply(change(.checkbox, "- [x] a\n"))
            while try Data(contentsOf: url) != Data("- [x] a\n".utf8) {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(!document.isDocumentEdited)
        }

        @Test
        func `a reload leaves the document clean`() {
            let document = ScrollDocument()

            document.apply(change(.reload, "b\n"))

            #expect(document.text == "b\n")
            #expect(!document.isDocumentEdited)
        }
    }
#endif
