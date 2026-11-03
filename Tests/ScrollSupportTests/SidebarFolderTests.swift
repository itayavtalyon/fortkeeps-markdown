#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// The folder section (screens §3.5; log 004 Round 6): New File, Rename,
    /// and Move to Trash with Undo.
    extension SidebarTests {
        @Test
        func `the folder shows its Markdown files and subfolders once the app can read it`() async throws {
            try FileManager.default.createDirectory(
                at: folder.appending(path: "Sub"),
                withIntermediateDirectories: true
            )
            base.spy.access.readable = []
            let (_, controller) = try await open(files: ["b.md", "photo.png"])

            #expect(Self.rows(controller) == ["Outline", "Trip"])
            controller.showFolder(folder)
            #expect(Self.rows(controller) == ["Outline", "Trip", folder.lastPathComponent, "a.md", "b.md", "Sub"])
            controller.sidebar.outlineView.expandItem(controller.sidebar.outlineView.item(atRow: 5))
            #expect(Self.rows(controller).last == "No Markdown files in this folder.")
        }

        @Test
        func `a file click opens it`() async throws {
            let (_, controller) = try await open(files: ["b.md"])

            try Self.select("b.md", controller)
            controller.sidebar.choose()

            #expect(base.spy.files.map(\.lastPathComponent) == ["b.md"])
        }

        @Test
        func `a new file is Untitled.md, then Untitled 2.md, and its rename starts`() async throws {
            let (_, controller) = try await open()

            controller.sidebar.newFile(nil)
            #expect(Self.rows(controller).contains("Untitled.md"))
            #expect(try Self.field(controller).isEditable)
            try Self.commit("Untitled.md", controller)
            controller.sidebar.newFile(nil)

            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "Untitled 2.md").path))
            #expect(try Self.field(controller).stringValue == "Untitled 2.md")
        }

        @Test
        func `a new file goes into the selected folder, or the folder of the selected file`() async throws {
            let sub = folder.appending(path: "Sub")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data("x\n".utf8).write(to: sub.appending(path: "c.md"))
            let (_, controller) = try await open()

            try Self.select("Sub", controller)
            controller.sidebar.newFile(nil)
            try Self.commit("d.md", controller)
            try Self.select("c.md", controller)
            controller.sidebar.newFile(nil)

            #expect(try FileManager.default.contentsOfDirectory(atPath: sub.path).sorted()
                == ["Untitled.md", "c.md", "d.md"])
        }

        @Test(.timeLimit(.minutes(1)))
        func `a rename commits on Return, and an open tab follows`() async throws {
            let (document, controller) = try await open()

            try Self.select("a.md", controller)
            controller.sidebar.rename(nil)
            try Self.commit("trip.md", controller)

            #expect(Self.rows(controller).contains("trip.md"))
            while document.fileURL?.lastPathComponent != "trip.md" {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test
        func `a name another file has is refused with the alert, and Esc keeps the name`() async throws {
            let (_, controller) = try await open(files: ["b.md"])
            base.spy.response = .alertFirstButtonReturn

            try Self.select("a.md", controller)
            controller.sidebar.rename(nil)
            try Self.commit("B.md", controller)
            #expect(base.spy.alerts == ["“B.md” already exists. Choose another name."])

            controller.sidebar.rename(nil)
            let field = try Self.field(controller)
            field.stringValue = "c.md"
            let editor = NSTextView()
            #expect(controller.sidebar.control(
                field,
                textView: editor,
                doCommandBy: #selector(NSResponder.cancelOperation)
            ))
            #expect(!controller.sidebar.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertTab)))

            #expect(field.stringValue == "a.md")
            #expect(!field.isEditable)
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "a.md").path))
        }

        /// Must-pass (plan 02 › 2f).
        @Test
        func `moving to the Trash moves the file there and closes its tab, and Undo restores it`() async throws {
            let (document, controller) = try await open(files: ["b.md"])
            let file = folder.appending(path: "a.md")
            controller.markdownView.replaceText("# Trip edited\n")

            try Self.select("a.md", controller)
            controller.sidebar.moveToTrash(nil)

            #expect(!FileManager.default.fileExists(atPath: file.path))
            #expect(document.windowControllers.isEmpty)
            #expect(FileTrash.undoManager.undoActionName == "Move to Trash")
            FileTrash.undoManager.undo()
            #expect(try String(contentsOf: file, encoding: .utf8) == "# Trip edited\n")
            #expect(base.spy.files.map(\.lastPathComponent) == ["a.md"])
            FileTrash.undoManager.redo()
            #expect(!FileManager.default.fileExists(atPath: file.path))
            FileTrash.undoManager.undo()
        }

        @Test
        func `the sidebar's Undo and Redo reach the trash`() async throws {
            let (_, controller) = try await open(files: ["b.md"])
            let outline = controller.sidebar.outlineView
            let undo = NSMenuItem(title: "Undo", action: #selector(SidebarOutlineView.undo), keyEquivalent: "")
            let redo = NSMenuItem(title: "Redo", action: #selector(SidebarOutlineView.redo), keyEquivalent: "")

            try Self.select("b.md", controller)
            controller.sidebar.moveToTrash(nil)
            #expect(outline.validateUserInterfaceItem(undo))
            #expect(undo.title == "Undo Move to Trash")
            outline.undo(nil)
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "b.md").path))
            #expect(outline.validateUserInterfaceItem(redo))
            outline.redo(nil)
            #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "b.md").path))
            FileTrash.undoManager.undo()
        }

        @Test
        func `the folder actions need a folder or a file`() async throws {
            base.spy.access.readable = []
            let (_, controller) = try await open()
            let item = { (action: Selector) in NSMenuItem(title: "", action: action, keyEquivalent: "") }

            #expect(!controller.sidebar.validateMenuItem(item(#selector(SidebarController.newFile))))
            controller.showFolder(folder)
            #expect(controller.sidebar.validateMenuItem(item(#selector(SidebarController.newFile))))
            #expect(!controller.sidebar.validateMenuItem(item(#selector(SidebarController.moveToTrash))))
            try Self.select("a.md", controller)
            #expect(controller.sidebar.validateMenuItem(item(#selector(SidebarController.rename))))
            #expect(controller.sidebar.outlineView.menu?.items.map(\.title) == ["New File", "Rename", "Move to Trash"])
        }

        @Test
        func `a closed subfolder stays closed when the list reloads`() async throws {
            let sub = folder.appending(path: "Sub")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data("x\n".utf8).write(to: sub.appending(path: "c.md"))
            let (_, controller) = try await open()
            let outline = controller.sidebar.outlineView

            try outline.expandItem(outline.item(atRow: #require(Self.rows(controller).firstIndex(of: "Sub"))))
            controller.sidebar.reloadFolder()
            #expect(Self.rows(controller).contains("c.md"))
            try outline.collapseItem(outline.item(atRow: #require(Self.rows(controller).firstIndex(of: "Sub"))))
            controller.sidebar.reloadFolder()
            #expect(!Self.rows(controller).contains("c.md"))
        }

        @Test
        func `a folder it cannot write, a bad name, or a file gone beeps`() async throws {
            let (_, controller) = try await open()
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path) }

            controller.sidebar.newFile(nil)
            #expect(base.spy.beeps == 1)
            try Self.select("a.md", controller)
            controller.sidebar.rename(nil)
            try Self.commit("x/y.md", controller)
            #expect(base.spy.beeps == 2)
            FileTrash.trash(
                folder.appending(path: "gone.md"), close: { _ in nil }, openFile: { _ in },
                beep: { base.spy.beeps += 1 }
            )
            #expect(base.spy.beeps == 3)
        }
    }
#endif
