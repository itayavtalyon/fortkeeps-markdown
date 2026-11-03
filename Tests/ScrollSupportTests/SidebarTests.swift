#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// The sidebar (screens §3.4, §3.5; log 004 Round 6): the Outline, then
    /// the folder with New File, Rename, and Move to Trash.
    @MainActor
    struct SidebarTests {
        let base = DocumentWindowTests()

        var folder: URL {
            base.folder
        }

        /// The window with its sidebar shown and its Outline loaded.
        func open(
            _ text: String = "# Trip\n",
            files: [String] = []
        ) async throws -> (ScrollDocument, DocumentWindowController) {
            for name in files {
                _ = try base.given(name, "x\n")
            }
            let (document, controller) = try base.open(base.given("a.md", text))
            controller.split.splitViewItems[0].isCollapsed = false
            controller.refreshOutline()
            await controller.outlineTask?.value
            return (document, controller)
        }

        static func rows(_ controller: DocumentWindowController) -> [String] {
            let outline = controller.sidebar.outlineView
            return (0 ..< outline.numberOfRows).compactMap { outline.item(atRow: $0) as? SidebarRow }
                .map(\.title)
        }

        static func select(_ title: String, _ controller: DocumentWindowController) throws {
            let index = try #require(rows(controller).firstIndex(of: title))
            controller.sidebar.outlineView.selectRowIndexes([index], byExtendingSelection: false)
        }

        static func field(_ controller: DocumentWindowController) throws -> NSTextField {
            let outline = controller.sidebar.outlineView
            let cell = outline.view(atColumn: 0, row: outline.selectedRow, makeIfNecessary: true) as? NSTableCellView
            return try #require(cell?.textField)
        }

        /// Return in the name field.
        static func commit(_ name: String, _ controller: DocumentWindowController) throws {
            let field = try field(controller)
            field.stringValue = name
            controller.sidebar.controlTextDidEndEditing(Notification(
                name: NSControl.textDidEndEditingNotification, object: field,
                userInfo: ["NSTextMovement": NSTextMovement.return.rawValue]
            ))
        }

        // MARK: Outline

        @Test
        func `the Outline lists the headings, with the deeper ones under a disclosure`() async throws {
            let (_, controller) = try await open("# Trip\n\n## Day 1\n\n### Morning\n\n#### Detail\n\n## Day 2\n")
            let outline = controller.sidebar.outlineView

            #expect(Self.rows(controller).prefix(5) == ["Outline", "Trip", "Day 1", "Morning", "Day 2"])
            outline.expandItem(outline.item(atRow: 3))
            #expect(Self.rows(controller).prefix(6) == ["Outline", "Trip", "Day 1", "Morning", "Detail", "Day 2"])
            #expect(!outline.isExpandable(outline.item(atRow: 1)))
            #expect(controller.sidebar.outlineView(outline, isGroupItem: outline.item(atRow: 0) as Any))
        }

        @Test
        func `with no heading the Outline says so, and it follows the text`() async throws {
            let (_, controller) = try await open("Plain\n")

            #expect(Self.rows(controller).prefix(2) == ["Outline", "No headings yet."])
            controller.markdownView.replaceText("# New\n")
            #expect(Self.rows(controller).prefix(2) == ["Outline", "No headings yet."])
            await controller.outlineTask?.value
            #expect(Self.rows(controller).prefix(2) == ["Outline", "New"])
        }

        /// Plan 01: no editor path parses the whole text after open (log 004 Round 6).
        /// A 1 h pause, so a busy main actor cannot make the pause pass.
        @Test(.timeLimit(.minutes(2)))
        func `typing parses nothing until it pauses, and a newer edit starts the pause again`() async throws {
            let (_, controller) = try await open("Plain\n")
            controller.outlinePause = .seconds(3600)

            controller.markdownView.replaceText("# One\n")
            let first = try #require(controller.outlineTask)
            controller.markdownView.replaceText("# Two\n")
            await first.value
            try await Task.sleep(for: .milliseconds(200))

            #expect(first.isCancelled)
            #expect(controller.markdownView.controller.cachedDocument == nil)
            #expect(Self.rows(controller).prefix(2) == ["Outline", "No headings yet."])
            controller.outlinePause = .milliseconds(10)
            controller.markdownView.replaceText("# Three\n")
            await controller.outlineTask?.value
            #expect(Self.rows(controller).prefix(2) == ["Outline", "Three"])
        }

        @Test
        func `a hidden sidebar parses nothing, and its Outline loads when it shows`() async throws {
            let (_, controller) = try await open("Plain\n")
            controller.split.toggleSidebar(nil)

            controller.markdownView.reload(text: "# Shown\n")
            #expect(controller.outlineTask == nil)
            #expect(controller.markdownView.controller.cachedDocument == nil)

            controller.split.toggleSidebar(nil)
            await controller.outlineTask?.value
            #expect(Self.rows(controller).prefix(2) == ["Outline", "Shown"])
        }

        @Test(.timeLimit(.minutes(2)))
        func `a reload refreshes the Outline at once`() async throws {
            let (_, controller) = try await open("Plain\n")
            controller.outlinePause = .seconds(3600)

            controller.markdownView.reload(text: "# Reloaded\n")
            await controller.outlineTask?.value

            #expect(Self.rows(controller).prefix(2) == ["Outline", "Reloaded"])
        }

        @Test
        func `a heading click shows it in the text, and the scroll marks the current heading`() async throws {
            let lines = (1 ... 80).map { "line \($0)" }.joined(separator: "\n\n")
            let (_, controller) = try await open("# One\n\n\(lines)\n\n# Two\n\n\(lines)\n")
            let outline = controller.sidebar.outlineView
            #expect(outline.selectedRow == Self.rows(controller).firstIndex(of: "One"))

            try Self.select("Two", controller)
            controller.sidebar.choose()
            let start = (controller.markdownView.text as NSString).range(of: "# Two").location
            #expect(controller.markdownView.controller.selection == start ..< start)

            outline.deselectAll(nil)
            controller.markdownView.onScroll?()
            #expect(outline.selectedRow == Self.rows(controller).firstIndex(of: "Two"))
        }

        @Test
        func `a folder change keeps the open headings and the marked one`() async throws {
            let (_, controller) = try await open("# Trip\n\n#### Detail\n\n# Next\n")
            let outline = controller.sidebar.outlineView
            outline.expandItem(outline.item(atRow: 1))
            controller.sidebar.follow(1)

            NotificationCenter.default.post(name: FileTrash.folderDidChange, object: nil)

            #expect(outline.isItemExpanded(outline.item(atRow: 1)))
            #expect(outline.selectedRow == 2)
        }

        @Test
        func `the scroll marks a folded heading's parent, and its own row when shown`() async throws {
            let (_, controller) = try await open("# Trip\n\n#### Detail\n\n# Next\n")
            let outline = controller.sidebar.outlineView

            controller.sidebar.follow(1)
            #expect(outline.selectedRow == 1)
            outline.expandItem(outline.item(atRow: 1))
            controller.sidebar.follow(1)
            #expect(outline.selectedRow == 2)
            controller.sidebar.follow(nil)
            #expect(outline.selectedRow == -1)
        }

        @Test
        func `only headings and files can be chosen, and a folder click opens nothing`() async throws {
            let sub = folder.appending(path: "Sub")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            let (_, controller) = try await open()
            let outline = controller.sidebar.outlineView
            let rows = (0 ..< outline.numberOfRows).compactMap { outline.item(atRow: $0) }

            #expect(rows.map { controller.sidebar.outlineView(outline, shouldSelectItem: $0) }
                == [false, true, false, true, true])
            try Self.select("Sub", controller)
            controller.sidebar.choose()
            #expect(base.spy.files.isEmpty)
        }

        @Test
        func `the Return key chooses the selected row, and other keys move as usual`() async throws {
            let (_, controller) = try await open()
            let outline = controller.sidebar.outlineView
            func key(_ code: UInt16) throws -> NSEvent {
                try #require(NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: controller.window?.windowNumber ?? 0, context: nil,
                    characters: code == 36 ? "\r" : "\u{F701}",
                    charactersIgnoringModifiers: code == 36 ? "\r" : "\u{F701}",
                    isARepeat: false, keyCode: code
                ))
            }

            outline.selectRowIndexes([1], byExtendingSelection: false)
            try outline.keyDown(with: key(125))
            #expect(outline.selectedRow == 3)
            try outline.keyDown(with: key(36))
            #expect(base.spy.files.map(\.lastPathComponent) == ["a.md"])
            let selectAll = NSMenuItem(title: "", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "")
            // The table answers the rest: one row at a time, so no Select All.
            #expect(!outline.validateUserInterfaceItem(selectAll))
        }

        // MARK: the window

        @Test
        func `the sidebar starts hidden, and a new window follows the last choice`() async throws {
            let (_, controller) = try base.open(base.given("a.md"))
            #expect(controller.split.splitViewItems[0].isCollapsed)

            controller.split.toggleSidebar(nil)

            #expect(ScrollSettings(defaults: base.spy.defaults).showsSidebar)
            let (_, next) = try base.open(base.given("b.md", "# Bee\n"))
            #expect(!next.split.splitViewItems[0].isCollapsed)
            await next.outlineTask?.value
            #expect(Self.rows(next).prefix(2) == ["Outline", "Bee"])
        }

        @Test
        func `the toolbar has the sidebar button, before Lock`() async throws {
            let (_, controller) = try await open()

            let items = controller.window?.toolbar?.items.map(\.itemIdentifier)

            #expect(items == [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .lock])
        }

        @Test
        func `the Outline command shows the sidebar and puts the focus in it`() async throws {
            let (_, controller) = try base.open(base.given("a.md", "# Trip\n"))
            #expect(controller.split.splitViewItems[0].isCollapsed)

            controller.focusOutline(nil)
            await controller.outlineTask?.value

            #expect(!controller.split.splitViewItems[0].isCollapsed)
            #expect(Self.rows(controller).prefix(2) == ["Outline", "Trip"])
            #expect(controller.window?.firstResponder === controller.sidebar.outlineView)
        }
    }
#endif
