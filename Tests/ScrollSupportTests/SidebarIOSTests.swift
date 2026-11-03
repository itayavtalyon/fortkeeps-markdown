#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// The iOS sidebar (screens §3.4, §3.5; log 004 Round 6): a sheet from ☰ on
    /// iPhone, with the Outline and then the folder.
    extension DocumentViewControllerTests {
        /// The sheet on screen, with its Outline loaded.
        func sidebarSheet(_ controller: DocumentViewController) async throws -> SidebarViewController {
            let button = try #require(controller.navigationItem.rightBarButtonItems?[2])
            #expect(button.accessibilityLabel == "Outline")
            button.primaryAction?.performWithSender(nil, target: nil)
            let sheet = try #require(presented.last as? UINavigationController)
            #expect(sheet.sheetPresentationController?.detents.count == 2)
            let sidebar = try #require(sheet.topViewController as? SidebarViewController)
            // On screen, so a row being renamed gets its field.
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
            window.rootViewController = sheet
            window.makeKeyAndVisible()
            windows.append(window)
            window.layoutIfNeeded()
            sidebar.viewDidAppear(false)
            await controller.outlineTask?.value
            return sidebar
        }

        static func visible(_ sidebar: SidebarViewController) -> [String] {
            sidebar.dataSource.snapshot().sectionIdentifiers.flatMap {
                sidebar.dataSource.snapshot(for: $0).visibleItems.map(\.title)
            }
        }

        static func path(_ title: String, _ sidebar: SidebarViewController) throws -> IndexPath {
            let row = try #require(sidebar.dataSource.snapshot().itemIdentifiers.first { $0.title == title })
            return try #require(sidebar.dataSource.indexPath(for: row))
        }

        static func choose(_ title: String, _ sidebar: SidebarViewController) throws {
            try sidebar.collectionView(sidebar.collectionView, didSelectItemAt: path(title, sidebar))
        }

        /// A context menu item of the row.
        static func menu(_ title: String, on row: String, _ sidebar: SidebarViewController) throws {
            let path = try path(row, sidebar)
            let configuration = sidebar.collectionView(
                sidebar.collectionView, contextMenuConfigurationForItemsAt: [path], point: .zero
            )
            typealias Provider = @convention(block) ([UIMenuElement]) -> UIMenu?
            let provider = try #require(configuration?.value(forKey: "actionProvider") as AnyObject?)
            let menu = try #require(unsafeBitCast(provider, to: Provider.self)([]))
            let action = try #require(menu.children.compactMap { $0 as? UIAction }.first { $0.title == title })
            action.performWithSender(nil, target: nil)
            sidebar.collectionView.layoutIfNeeded()
        }

        @Test
        func `the Outline lists the headings, the deeper ones under a disclosure, and a choice shows one`(
        ) async throws {
            let controller = try await screen("# Trip\n\n## Day 1\n\n#### Detail\n\n## Day 2\n")
            let sidebar = try await sidebarSheet(controller)

            #expect(Self.visible(sidebar).prefix(4) == ["Outline", "Trip", "Day 1", "Day 2"])
            let day = try #require(sidebar.dataSource.snapshot().itemIdentifiers.first { $0.title == "Day 1" })
            var outline = sidebar.dataSource.snapshot(for: 0)
            outline.expand([day])
            await sidebar.dataSource.apply(outline, to: 0, animatingDifferences: false)
            #expect(Self.visible(sidebar).prefix(5) == ["Outline", "Trip", "Day 1", "Detail", "Day 2"])
            let header = try Self.path("Outline", sidebar)
            #expect(!sidebar.collectionView(sidebar.collectionView, shouldSelectItemAt: header))

            try Self.choose("Day 2", sidebar)

            let start = (controller.markdownView.text as NSString).range(of: "## Day 2").location
            #expect(controller.markdownView.controller.selection == start ..< start)
        }

        @Test
        func `with no heading the Outline says so, and it follows the text`() async throws {
            let controller = try await screen("Plain\n")
            let sidebar = try await sidebarSheet(controller)

            #expect(Self.visible(sidebar).prefix(2) == ["Outline", "No headings yet."])
            controller.markdownView.replaceText("# New\n")
            #expect(Self.visible(sidebar).prefix(2) == ["Outline", "No headings yet."])
            #expect(controller.markdownView.controller.cachedDocument == nil)
            await controller.outlineTask?.value
            #expect(Self.visible(sidebar).prefix(2) == ["Outline", "New"])
        }

        @Test
        func `the scroll marks the heading at the top of the text`() async throws {
            let lines = (1 ... 80).map { "line \($0)" }.joined(separator: "\n\n")
            let controller = try await screen("# One\n\n\(lines)\n\n# Two\n")
            let sidebar = try await sidebarSheet(controller)

            sidebar.follow(1)
            #expect(try sidebar.collectionView.indexPathsForSelectedItems == [Self.path("Two", sidebar)])
            controller.markdownView.onScroll?()
            #expect(try sidebar.collectionView.indexPathsForSelectedItems == [Self.path("One", sidebar)])
            sidebar.follow(nil)
            #expect(sidebar.collectionView.indexPathsForSelectedItems?.isEmpty == true)
        }

        @Test
        func `the folder lists its Markdown files and subfolders; a file opens and a folder expands`(
        ) async throws {
            let sub = folder.appending(path: "Sub")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data().write(to: sub.appending(path: "inner.md"))
            try Data().write(to: folder.appending(path: "notes.txt"))
            try Data().write(to: folder.appending(path: "photo.png"))
            let sidebar = try await sidebarSheet(screen())

            #expect(Self.visible(sidebar).suffix(4) == [folder.lastPathComponent, "a.md", "notes.txt", "Sub"])
            try Self.choose("Sub", sidebar)
            #expect(Self.visible(sidebar).suffix(2) == ["Sub", "inner.md"])
            try Self.choose("Sub", sidebar)
            #expect(Self.visible(sidebar).last == "Sub")
            try Self.choose("notes.txt", sidebar)
            #expect(opened.map(\.lastPathComponent) == ["notes.txt"])
        }

        @Test
        func `the disclosure of a subfolder opens and closes it`() async throws {
            let sub = folder.appending(path: "Sub")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data().write(to: sub.appending(path: "inner.md"))
            let sidebar = try await sidebarSheet(screen())
            let row = try #require(sidebar.dataSource.snapshot().itemIdentifiers.first { $0.title == "Sub" })

            sidebar.toggler(row)()
            #expect(Self.visible(sidebar).suffix(2) == ["Sub", "inner.md"])
            sidebar.toggler(row)()
            #expect(Self.visible(sidebar).last == "Sub")
        }

        @Test
        func `with no folder access there is no folder section`() async throws {
            let access = FakeAccess()
            access.readable = []
            environment.access = access
            let sidebar = try await sidebarSheet(screen())

            #expect(sidebar.dataSource.snapshot().numberOfSections == 1)
        }

        @Test
        func `the New file item makes Untitled and starts its rename; Return commits the name`() async throws {
            let sidebar = try await sidebarSheet(screen())

            try Self.menu("New file", on: "a.md", sidebar)

            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "Untitled.md").path()))
            let field = try #require(sidebar.renameField)
            #expect(field.text == "Untitled.md")
            #expect(field.intrinsicContentSize.height == 36)
            field.text = "Plan.md"
            _ = field.delegate?.textFieldShouldReturn?(field)
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "Plan.md").path()))
            #expect(Self.visible(sidebar).contains("Plan.md"))
            #expect(sidebar.renameField == nil)
        }

        @Test
        func `a new file in a closed subfolder opens it and starts the rename there`() async throws {
            try FileManager.default.createDirectory(
                at: folder.appending(path: "Sub"),
                withIntermediateDirectories: true
            )
            let sidebar = try await sidebarSheet(screen())

            try Self.menu("New file", on: "Sub", sidebar)

            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "Sub/Untitled.md").path()))
            #expect(Self.visible(sidebar).suffix(2) == ["Sub", "Untitled.md"])
            #expect(sidebar.renameField?.text == "Untitled.md")
        }

        @Test(.timeLimit(.minutes(1)))
        func `a reload refreshes the Outline at once`() async throws {
            let controller = try await screen("Plain\n")
            let sidebar = try await sidebarSheet(controller)
            controller.outlinePause = .seconds(3600)

            controller.markdownView.reload(text: "# Reloaded\n")
            await controller.outlineTask?.value

            #expect(Self.visible(sidebar).prefix(2) == ["Outline", "Reloaded"])
        }

        @Test
        func `a name another file has shows the alert, and Escape keeps the old name`() async throws {
            let controller = try await screen()
            try Data().write(to: folder.appending(path: "b.md"))
            let sidebar = try await sidebarSheet(controller)

            try Self.menu("Rename", on: "b.md", sidebar)
            let field = try #require(sidebar.renameField)
            field.text = "A.md"
            _ = field.delegate?.textFieldShouldReturn?(field)
            let alert = try #require(presented.last as? UIAlertController)
            #expect(alert.title == "“A.md” already exists. Choose another name.")

            try Self.menu("Rename", on: "b.md", sidebar)
            let again = try #require(sidebar.renameField)
            again.text = "c.md"
            again.cancel()
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "b.md").path()))
            #expect(again.keyCommands?.first?.input == UIKeyCommand.inputEscape)
        }

        @Test
        func `an empty name keeps the old one`() async throws {
            let sidebar = try await sidebarSheet(screen())

            try Self.menu("Rename", on: "a.md", sidebar)
            let field = try #require(sidebar.renameField)
            field.text = ""
            _ = field.delegate?.textFieldShouldReturn?(field)

            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "a.md").path()))
            #expect(presented.last as? UIAlertController == nil)
        }

        @Test
        func `a file gone since the list moves nothing on Move to Trash`() async throws {
            let controller = try await screen()
            try Data().write(to: folder.appending(path: "b.md"))
            let sidebar = try await sidebarSheet(controller)
            try FileManager.default.removeItem(at: folder.appending(path: "b.md"))

            try Self.menu("Move to Trash", on: "b.md", sidebar)

            let trash = environment.appFolder.appending(path: "Trash/b.md")
            #expect(!FileManager.default.fileExists(atPath: trash.path()))
            #expect(!Self.visible(sidebar).contains("b.md"))
        }

        @Test
        func `the Move to Trash item closes the open file; Undo puts it back and opens it again`() async throws {
            let controller = try await screen()
            let store = FileListStore(defaults: environment.defaults)
            let session = DocumentSession(store: store, environment: environment)
            let open = try #require(await session.open(controller.document.fileURL))
            open.markdownView.replaceText("Unsaved\n")
            let sidebar = try await sidebarSheet(controller)
            sidebar.session = session
            let url = controller.document.fileURL

            try Self.menu("Move to Trash", on: "a.md", sidebar)

            #expect(!FileManager.default.fileExists(atPath: url.path()))
            let trash = environment.appFolder.appending(path: "Trash")
            // The unsaved text went into the file first, so Undo brings it back.
            #expect(try String(contentsOf: trash.appending(path: "a.md"), encoding: .utf8) == "Unsaved\n")
            #expect(closed.map(\.lastPathComponent) == ["a.md"])
            #expect(!Self.visible(sidebar).contains("a.md"))
            #expect(sidebar.undoManager === FileTrash.undoManager)
            FileTrash.undoManager.undo()
            #expect(FileManager.default.fileExists(atPath: url.path()))
            #expect(opened.map(\.lastPathComponent) == ["a.md"])
        }
    }
#endif
