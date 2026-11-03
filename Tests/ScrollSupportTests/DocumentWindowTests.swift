#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// Design › Windows and chrome, Files, Outside changes (strips): the document window.
    @MainActor
    struct DocumentWindowTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "DocumentWindowTests-\(UUID().uuidString)")
        let spy = EnvironmentSpy()

        init() {
            _ = TestApp.controller
        }

        func given(_ name: String = "a.md", _ text: String = "- [ ] one two\n") throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data(text.utf8).write(to: url)
            return url
        }

        func open(_ url: URL) throws -> (ScrollDocument, DocumentWindowController) {
            let document = try ScrollDocument(contentsOf: url, ofType: ScrollDocument.typeName)
            document.environment = spy.environment
            // The controller holds the document, as in the app; a window controller does not.
            TestApp.controller.addDocument(document)
            document.makeWindowControllers()
            let controller = try #require(document.windowControllers.first as? DocumentWindowController)
            controller.window?.layoutIfNeeded()
            return (document, controller)
        }

        static func texts(_ controller: DocumentWindowController) -> [String] {
            texts(in: controller.contentStack)
        }

        static func texts(in view: NSView?) -> [String] {
            (view?.subviews ?? []).flatMap { subview -> [String] in
                switch subview {
                case let button as NSButton: [button.title]
                case let field as NSTextField: [field.stringValue]
                case is MarkdownView: []
                default: texts(in: subview)
                }
            }
        }

        @Test
        func `the window shows the file name, the folder, and system tabs`() throws {
            let (_, controller) = try open(given("trip.md"))
            let window = try #require(controller.window)

            #expect(window.title == "trip.md")
            #expect(window.subtitle == (folder.path as NSString).abbreviatingWithTildeInPath)
            #expect(window.tabbingMode == .preferred)
            #expect(controller.markdownView.mode == .editor)
        }

        @Test
        func `the status bar shows Saved and the word count`() throws {
            let (_, controller) = try open(given())

            #expect(Self.texts(controller).contains("Saved · 2 words"))
        }

        /// Settings (screens §3.17): every window follows at once.
        @Test
        func `the text column and the word count follow Settings`() throws {
            let settings = ScrollSettings(defaults: spy.defaults)
            let (_, controller) = try open(given())
            #expect(controller.markdownView.maxLineWidth == 680)

            settings.lineWidth = .narrow
            settings.showsWordCount = false

            #expect(controller.markdownView.maxLineWidth == 560)
            #expect(Self.texts(controller).contains("Saved"))
        }

        @Test
        func `the Lock item, Option-Command-L, toggles Lock and Lock disables the checkboxes`() throws {
            let (_, controller) = try open(given())
            let menu = MainMenu.make()
            let item = try #require(menu.item(withTitle: "View")?.submenu?.items.first { $0.title == "Lock" })
            #expect(item.keyEquivalent == "l")
            #expect(item.keyEquivalentModifierMask == [.command, .option])
            #expect(item.action == #selector(DocumentWindowController.toggleLock))

            controller.toggleLock(nil)
            #expect(controller.markdownView.mode == .editorLocked)
            #expect(controller.lockItem.label == "Unlock")
            #expect(!controller.markdownView.controller.checkboxAccessibility(0).isEnabled)
            #expect(Self.texts(controller).contains("Locked · 2 words"))
            controller.toggleLock(nil)
            #expect(controller.markdownView.mode == .editor)
            #expect(controller.markdownView.controller.checkboxAccessibility(0).isEnabled)
        }

        @Test(.timeLimit(.minutes(2)))
        func `a failed save shows the strip and keeps the text`() async throws {
            let url = try given()
            let (document, controller) = try open(url)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path)
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            }

            controller.markdownView.reload(text: "- [ ] one two\n")
            document.apply(TextChange(
                reason: .checkbox, groupReason: .checkbox, range: NSRange(), replacement: "", text: "- [x] one two\n"
            ))
            let failed = "Couldn’t save “a.md”. Fortkeeps Scroll will keep trying."
            while !Self.texts(controller).contains(failed) {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(document.text == "- [x] one two\n")
            let saveAs = try #require(Self.button("Save As…", in: controller.window?.contentView))
            #expect(saveAs.target === document && saveAs.action == #selector(NSDocument.saveAs(_:)))
            let window = try #require(controller.window)
            window.orderFront(nil)
            defer { window.orderOut(nil) }
            document.presentError(
                CocoaError(.fileWriteNoPermission),
                modalFor: window,
                delegate: nil,
                didPresent: nil,
                contextInfo: nil
            )
            try await Task.sleep(for: .milliseconds(200))
            #expect(window.attachedSheet == nil)
            #expect(try Data(contentsOf: url) == Data("- [ ] one two\n".utf8))
        }

        @Test(.timeLimit(.minutes(2)))
        func `another error keeps the system sheet`() async throws {
            let (document, controller) = try open(given())
            let window = try #require(controller.window)
            window.orderFront(nil)
            defer { window.orderOut(nil) }

            document.presentError(
                CocoaError(.fileWriteNoPermission),
                modalFor: window,
                delegate: nil,
                didPresent: nil,
                contextInfo: nil
            )
            while window.attachedSheet == nil {
                try await Task.sleep(for: .milliseconds(10))
            }

            window.attachedSheet.map { window.endSheet($0) }
        }

        @Test
        func `a read-only file opens locked with its strip, and Lock stays on`() throws {
            let url = try given()
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }

            let (_, controller) = try open(url)
            controller.toggleLock(nil)

            #expect(controller.markdownView.mode == .editorLocked)
            let texts = Self.texts(controller)
            #expect(texts.contains("You can read this file but not change it."))
            #expect(texts.contains("Duplicate"))
            let item = NSMenuItem(
                title: "Lock",
                action: #selector(DocumentWindowController.toggleLock),
                keyEquivalent: ""
            )
            #expect(!controller.validateMenuItem(item))
        }

        @Test
        func `the deleted strip sends Save As to the document`() throws {
            let url = try given()
            let (document, controller) = try open(url)
            try FileManager.default.removeItem(at: url)
            document.apply(TextChange(
                reason: .checkbox, groupReason: .checkbox, range: NSRange(), replacement: "", text: "- [x] one two\n"
            ))

            let saveAs = try #require(Self.button("Save As…", in: controller.window?.contentView))

            #expect(saveAs.target === document && saveAs.action == #selector(NSDocument.saveAs(_:)))
        }

        @Test
        func `the read-only strip’s Duplicate opens a copy`() throws {
            let url = try given()
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
            let (document, controller) = try open(url)
            let before = TestApp.controller.documents

            try #require(Self.button("Duplicate", in: controller.window?.contentView)).performClick(nil)

            let copy = try #require(TestApp.controller.documents.first { !before.contains($0) } as? ScrollDocument)
            #expect(copy.text == document.text)
            copy.close()
        }

        @Test(.timeLimit(.minutes(2)))
        func `the file presenter notes a rename and a deletion`() async throws {
            let (document, _) = try open(given())
            var changes = 0
            document.onStateChange = { changes += 1 }

            // The system calls a file presenter on the presenter's queue.
            nonisolated(unsafe) let presenter = document
            let queue = document.presentedItemOperationQueue
            let moved = folder.appending(path: "b.md")
            queue.addOperation { presenter.presentedItemDidMove(to: moved) }
            while changes == 0 {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(!document.isDeleted)
            queue.addOperation { presenter.accommodatePresentedItemDeletion { _ in } }
            while !document.isDeleted {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test(.timeLimit(.minutes(2)))
        func `a deleted file shows its strip and pauses autosave until a save`() async throws {
            let url = try given()
            let (document, controller) = try open(url)
            try FileManager.default.removeItem(at: url)

            document.apply(TextChange(
                reason: .checkbox, groupReason: .checkbox, range: NSRange(), replacement: "", text: "- [x] one two\n"
            ))

            let texts = Self.texts(controller)
            #expect(texts.contains("“a.md” was deleted. Your text is still here."))
            #expect(texts.contains("Save As…"))
            #expect(texts.contains("Close"))
            #expect(document.text == "- [x] one two\n")
            await withCheckedContinuation { done in
                document.autosave(withImplicitCancellability: false) { _ in done.resume() }
            }
            #expect(!FileManager.default.fileExists(atPath: url.path))

            // A save writes the file back and ends the deleted state.
            let error = await withCheckedContinuation { done in
                document.save(to: url, ofType: ScrollDocument.typeName, for: .saveOperation) {
                    done.resume(returning: $0 as NSError?)
                }
            }
            #expect(error == nil)
            #expect(!document.isDeleted)
            #expect(try Data(contentsOf: url) == Data("- [x] one two\n".utf8))
            #expect(!Self.texts(controller).contains("“a.md” was deleted. Your text is still here."))
        }

        @Test
        func `a file moved to the Trash shows the deleted strip`() throws {
            let (_, controller) = try open(given())

            controller.document.map { ($0 as? ScrollDocument)?.noteMoved(to: URL(filePath: "/Users/x/.Trash/a.md")) }

            #expect(Self.texts(controller).contains("“a.md” was deleted. Your text is still here."))
        }

        @Test
        func `zoom steps the view and Actual Size resets it`() throws {
            let (_, controller) = try open(given())

            controller.zoomIn(nil)
            controller.zoomIn(nil)
            #expect(controller.markdownView.zoom == 1.2)
            controller.zoomOut(nil)
            #expect(controller.markdownView.zoom == 1.1)
            controller.actualSize(nil)
            #expect(controller.markdownView.zoom == 1)
            let item = NSMenuItem(title: "", action: #selector(DocumentWindowController.zoomIn), keyEquivalent: "")
            #expect(controller.validateMenuItem(item))
        }
    }

    /// Records what the window asks of the system.
    @MainActor
    final class EnvironmentSpy {
        var opened: [URL] = []
        var files: [URL] = []
        var beeps = 0
        var alerts: [String] = []
        /// The last alert and its handler, to answer it later.
        var alert: NSAlert?
        var answer: ((NSApplication.ModalResponse) -> Void)?
        var popovers: [String] = []
        /// The button an alert answers with; nil leaves it open.
        var response: NSApplication.ModalResponse?
        let access = FakeAccess()
        let defaults = UserDefaults(suiteName: "EnvironmentSpy-\(UUID().uuidString)") ?? .standard
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("EnvironmentSpy-\(UUID().uuidString)"))
        /// Where Export writes; nil cancels the panel.
        var exportURL: URL?
        var exportNames: [String] = []
        var printed: [NSPrintOperation] = []

        /// No answer: a request waits, logged.
        let transport = FakeTransport([:])

        var environment: ScrollEnvironment {
            ScrollEnvironment(
                transport: transport,
                access: access,
                openURL: { [weak self] in self?.opened.append($0) },
                openFile: { [weak self] in self?.files.append($0) },
                beep: { [weak self] in self?.beeps += 1 },
                presentAlert: { [weak self] alert, _, handler in
                    self?.alerts.append(alert.messageText)
                    self?.alert = alert
                    self?.answer = handler
                    if let response = self?.response {
                        handler(response)
                    }
                },
                showPopover: { [weak self] text, _ in self?.popovers.append(text) },
                chooseExportURL: { [weak self] name, _ in
                    self?.exportNames.append(name)
                    return self?.exportURL
                },
                runPrint: { [weak self] operation, _ in self?.printed.append(operation) },
                defaults: defaults,
                pasteboard: pasteboard
            )
        }
    }
#endif
