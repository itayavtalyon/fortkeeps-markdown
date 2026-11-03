#if os(macOS)
    import AppKit
    @testable import ScrollSupport
    import Testing

    /// Design › Files: opening, refusing, and the one document per path.
    /// Serialized: the tests share the app's controller and its alert hook.
    @MainActor
    @Suite(.serialized)
    struct ScrollDocumentControllerTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ControllerTests-\(UUID().uuidString)")

        func given(_ name: String, _ data: Data = Data("a\n".utf8)) throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try data.write(to: url)
            return url
        }

        func open(_ url: URL, with controller: ScrollDocumentController) async -> NSDocument? {
            await withCheckedContinuation { continuation in
                controller.openDocument(withContentsOf: url, display: false) { document, _, _ in
                    continuation.resume(returning: document)
                }
            }
        }

        func refusing() -> (ScrollDocumentController, () -> [String]) {
            let controller = TestApp.controller
            var shown: [String] = []
            controller.presentRefusal = { alert in shown.append(alert.messageText + " | " + alert.informativeText) }
            return (controller, { shown })
        }

        @Test
        func `an accepted file opens, in any case of its extension`() async throws {
            let (controller, shown) = refusing()

            let document = try await open(given("a.MD"), with: controller)

            #expect((document as? ScrollDocument)?.text == "a\n")
            #expect(shown().isEmpty)
        }

        @Test
        func `another extension is refused with its alert and not opened`() async throws {
            let (controller, shown) = refusing()

            let document = try await open(given("a.rtf"), with: controller)

            #expect(document == nil)
            #expect(!controller.documents.contains { $0.fileURL?.lastPathComponent == "a.rtf" })
            #expect(shown() == ["Can’t Open “a.rtf” | Open a .md, .markdown, or .txt file."])
        }

        @Test
        func `a file that is not UTF-8 is refused with its alert`() async throws {
            let (controller, shown) = refusing()

            let document = try await open(given("a.md", Data([0x61, 0x00])), with: controller)

            #expect(document == nil)
            #expect(shown() == ["Can’t Open “a.md” | This file is not UTF-8, so it was not opened."])
        }

        @Test
        func `a refusal alert has only OK`() {
            let alert = ScrollDocumentController.alert(for: .notUTF8, name: "a.md")

            #expect(alert.buttons.map(\.title) == ["OK"])
        }

        @Test
        func `a second open of the same path gives the open document`() async throws {
            let (controller, _) = refusing()
            let url = try given("a.md")

            let first = await open(url, with: controller)
            let second = await open(url, with: controller)

            #expect(first != nil)
            #expect(first === second)
            #expect(controller.documents.filter { $0.fileURL == url }.count == 1)
        }

        @Test
        func `a new document is a Markdown document`() throws {
            let (controller, _) = refusing()

            #expect(controller.defaultType == ScrollDocument.typeName)
            #expect(controller.documentClass(forType: ScrollDocument.typeName) == ScrollDocument.self)
            #expect(try controller.typeForContents(of: given("a.txt")) == ScrollDocument.typeName)
        }
    }
#endif
