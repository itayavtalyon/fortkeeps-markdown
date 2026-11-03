#if os(macOS)
    import AppKit
    @testable import ScrollSupport
    import Testing

    /// Design › Product: the Acknowledgements window lists every shipped
    /// dependency with its license name and full text.
    @MainActor
    struct AcknowledgementsTests {
        static let folder = URL(filePath: #filePath)
            .deletingLastPathComponent().appending(path: "../../Acknowledgements").standardizedFileURL

        @Test
        func `the entries hold each name, license, and full text`() {
            let entries = Acknowledgement.load(from: Self.folder)

            #expect(entries.map(\.name) == ["IBM Plex", "swift-cmark (cmark-gfm)"])
            #expect(entries.map(\.license) == ["SIL OFL 1.1", "BSD-2-Clause"])
            #expect(entries.first?.text.contains("SIL OPEN FONT LICENSE") == true)
        }

        @Test
        func `a missing folder gives no entries`() {
            #expect(Acknowledgement.load(from: nil).isEmpty)
            #expect(Acknowledgement.load(from: URL(filePath: "/nonexistent")).isEmpty)
        }

        @Test
        func `a missing license file gives an empty text`() throws {
            let folder = FileManager.default.temporaryDirectory.appending(path: "Ack-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(#"[{"name": "A", "license": "MIT", "file": "a.txt"}]"#.utf8)
                .write(to: folder.appending(path: "acknowledgements.json"))

            #expect(Acknowledgement.load(from: folder).map(\.text) == [""])
        }

        @Test
        func `the window shows every entry`() throws {
            let entries = Acknowledgement.load(from: Self.folder)
            let controller = AcknowledgementsWindowController(entries: entries)

            let text = try #require(controller.textView.textStorage?.string)
            #expect(controller.window?.title == "Acknowledgements")
            #expect(text.contains("IBM Plex — SIL OFL 1.1"))
            #expect(text.contains("swift-cmark (cmark-gfm) — BSD-2-Clause"))
            #expect(!controller.textView.isEditable)
        }
    }
#endif
