#if os(macOS)
    import AppKit
    @testable import ScrollSupport
    import Testing

    /// Design › Windows and chrome: the empty window (screens §3.1).
    @MainActor
    struct EmptyWindowTests {
        final class Actions: EmptyWindowActions {
            var calls: [String] = []
            func open(_ url: URL) {
                calls.append(url.lastPathComponent)
            }

            func removeRecent(_ url: URL) {
                calls.append("remove " + url.lastPathComponent)
            }
        }

        let folder = FileManager.default.temporaryDirectory.appending(path: "EmptyWindowTests-\(UUID().uuidString)")

        func file(_ name: String) throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data().write(to: url)
            return url
        }

        static func texts(in view: NSView) -> [String] {
            view.subviews.flatMap { subview -> [String] in
                switch subview {
                case let button as NSButton: [button.title]
                case let field as NSTextField: [field.stringValue]
                default: texts(in: subview)
                }
            }
        }

        static func button(_ title: String, in view: NSView) -> NSButton? {
            for subview in view.subviews {
                if let button = subview as? NSButton, button.title == title {
                    return button
                }
                if let found = button(title, in: subview) {
                    return found
                }
            }
            return nil
        }

        @Test
        func `the empty window shows the line, the two buttons, and Open has focus`() throws {
            let controller = EmptyWindowController(recent: [], actions: Actions())
            let window = try #require(controller.window)

            #expect(window.contentView.map(Self.texts) == [
                "Open a Markdown file, or create one.", "Open…", "New File"
            ])
            #expect(try window.initialFirstResponder === Self.button("Open…", in: #require(window.contentView)))
            #expect(window.frame.size == window.frameRect(forContentRect: CGRect(x: 0, y: 0, width: 560, height: 380))
                .size)
        }

        @Test
        func `the window is named for the app and a long folder does not widen it`() throws {
            let deep = folder.appending(path: String(repeating: "folder/", count: 30))
            try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
            let url = deep.appending(path: "a.md")
            try Data().write(to: url)
            let controller = EmptyWindowController(recent: [url], actions: Actions())
            let window = try #require(controller.window)

            window.layoutIfNeeded()

            #expect(window.title == "Fortkeeps Scroll")
            #expect(window.frame.width == window.frameRect(forContentRect: CGRect(x: 0, y: 0, width: 560, height: 380))
                .width)
        }

        @Test
        func `the Open… and New File buttons go to the document controller`() throws {
            let controller = EmptyWindowController(recent: [], actions: Actions())
            let content = try #require(controller.window?.contentView)
            let open = try #require(Self.button("Open…", in: content))
            let create = try #require(Self.button("New File", in: content))

            #expect(open.target == nil && open.action == #selector(NSDocumentController.openDocument(_:)))
            #expect(create.target == nil && create.action == #selector(NSDocumentController.newDocument(_:)))
        }

        @Test
        func `the recent list shows up to 8 files, and a click opens one`() throws {
            let urls = try (1 ... 9).map { try file("\($0).md") }
            let actions = Actions()
            let controller = EmptyWindowController(recent: urls, actions: actions)
            let content = try #require(controller.window?.contentView)

            let texts = Self.texts(in: content)
            #expect(texts.contains("Recent"))
            #expect(texts.contains("8.md"))
            #expect(!texts.contains("9.md"))
            Self.button("2.md", in: content)?.performClick(nil)
            #expect(actions.calls == ["2.md"])
        }

        @Test
        func `a missing recent file is dimmed, reads Not found, and can be removed`() throws {
            let actions = Actions()
            let missing = folder.appending(path: "gone.md")
            let controller = EmptyWindowController(recent: [missing], actions: actions)
            let content = try #require(controller.window?.contentView)

            let row = try #require(Self.button("gone.md", in: content))
            #expect(!row.isEnabled)
            #expect(Self.texts(in: content).contains("Not found"))
            Self.button("Remove from Recent", in: content)?.performClick(nil)
            #expect(actions.calls == ["remove gone.md"])
        }
    }
#endif
