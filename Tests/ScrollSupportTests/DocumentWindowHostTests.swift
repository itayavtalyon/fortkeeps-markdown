#if os(macOS)
    import AppKit
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing

    /// Design › Links, Folder access, and the commands of the document window.
    extension DocumentWindowTests {
        func link(_ destination: String, in url: URL) -> LinkActivation {
            LinkActivation(
                destination: destination,
                resolvedURL: nil,
                documentURL: url,
                modifiers: [],
                source: .markdown
            )
        }

        @Test
        func `links open in the browser, the mail app, a tab, or the heading; others beep`() throws {
            let url = try given("a.md", "# Big Title\n")
            try Data().write(to: folder.appending(path: "b.md"))
            let (_, controller) = try open(url)

            controller.open(link("https://e.com", in: url))
            controller.open(link("mailto:a@e.com", in: url))
            controller.open(link("b.md", in: url))
            controller.open(link("#big-title", in: url))
            controller.open(link("ftp://e.com", in: url))
            controller.open(link("#nope", in: url))

            #expect(spy.opened.map(\.absoluteString) == ["https://e.com", "mailto:a@e.com"])
            #expect(spy.files.map(\.lastPathComponent) == ["b.md"])
            #expect(spy.beeps == 1)
            #expect(controller.markdownView.anchor.selection == 0 ..< 0)
        }

        @Test
        func `a link to a missing sibling shows the popover`() throws {
            let url = try given()
            let (_, controller) = try open(url)

            controller.open(link("gone.md", in: url))

            #expect(spy.popovers == ["“gone.md” isn’t in this folder."])
            #expect(spy.files.isEmpty)
        }

        @Test
        func `a sibling link with no folder access shows the folder-access strip`() throws {
            let url = try given()
            spy.access.readable = []
            let (_, controller) = try open(url)
            #expect(!Self.texts(controller).contains(where: { $0.hasPrefix("Allow access") }))

            controller.open(link("b.md", in: url))

            #expect(Self.texts(controller)
                .contains("Allow access to “\(folder.lastPathComponent)” to show its images and open linked files."))
            #expect(spy.files.isEmpty)
        }

        @Test(.timeLimit(.minutes(1)))
        func `a document with a relative image asks for its folder once, and Allow Access grants it`() async throws {
            let url = try given("a.md", "![a](a.png)\n")
            spy.access.readable = []
            spy.access.grantOnRequest = true
            let (_, controller) = try open(url)
            #expect(Self.texts(controller).contains("Allow Access…"))

            try #require(Self.button("Allow Access…", in: controller.window?.contentView)).performClick(nil)
            while Self.texts(controller).contains("Allow Access…") {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(spy.access.requested.map(\.lastPathComponent) == [folder.lastPathComponent])
        }

        @Test
        func `the folder-access strip can be dismissed`() throws {
            let url = try given("a.md", "![a](a.png)\n")
            spy.access.readable = []
            let (_, controller) = try open(url)

            try #require(Self.button("", in: controller.window?.contentView)).performClick(nil)

            #expect(!Self.texts(controller).contains("Allow Access…"))
        }

        @Test
        func `the deleted strip’s Close asks first, and Cancel keeps the document`() throws {
            let url = try given()
            let (document, controller) = try open(url)
            try FileManager.default.removeItem(at: url)
            document.autosave(withImplicitCancellability: false) { _ in }
            spy.response = .alertFirstButtonReturn

            try #require(Self.button("Close", in: controller.window?.contentView)).performClick(nil)

            #expect(spy.alerts == ["Close without saving? The text will be lost."])
            #expect(document.windowControllers.count == 1)
        }

        @Test
        func `the deleted strip’s Close, confirmed, closes the document`() throws {
            let url = try given()
            let (document, controller) = try open(url)
            try FileManager.default.removeItem(at: url)
            document.autosave(withImplicitCancellability: false) { _ in }
            spy.response = .alertSecondButtonReturn

            try #require(Self.button("Close", in: controller.window?.contentView)).performClick(nil)

            #expect(!TestApp.controller.documents.contains(document))
        }

        @Test(.timeLimit(.minutes(1)))
        func `the Save command saves an edited document`() async throws {
            let url = try given("a.md", "a\n")
            let (document, controller) = try open(url)
            document.apply(TextChange(
                reason: .edit,
                groupReason: .edit,
                range: NSRange(),
                replacement: "",
                text: "b\n"
            ))

            controller.saveDocument(nil)
            while try Data(contentsOf: url) != Data("b\n".utf8) {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        /// Records Close instead of closing: under `swift test` a document
        /// window's close stops the run loop of the test run. The UI tests close
        /// real tabs.
        final class RecordingWindow: NSWindow {
            var closes = 0

            convenience init(group: String) {
                self.init(
                    contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: true
                )
                tabbingIdentifier = group
                isReleasedWhenClosed = false
            }

            override func performClose(_: Any?) {
                closes += 1
            }
        }

        @Test
        func `the Close Window command closes every tab, and Command-number selects a tab`() throws {
            let (_, controller) = try open(given())
            let group = UUID().uuidString
            let windows = [RecordingWindow(group: group), RecordingWindow(group: group)]
            defer { windows.forEach { $0.orderOut(nil) } }
            controller.window = windows[0]
            windows[0].orderFront(nil)
            let item = NSMenuItem()
            item.tag = 0
            controller.selectTab(item)
            controller.closeWindow(nil)
            #expect(windows[0].closes == 1)
            windows[0].addTabbedWindow(windows[1], ordered: .above)

            item.tag = 1
            controller.selectTab(item)
            item.tag = 9
            controller.selectTab(item)
            #expect(windows[0].tabGroup?.selectedWindow === windows[1])
            controller.closeWindow(nil)

            #expect(windows.map(\.closes) == [2, 1])
        }

        @Test(.timeLimit(.minutes(1)))
        func `the view's image calls reach the document images`() async throws {
            let url = try given("a.md", "![a](https://e.com/a.png)\n")
            let (_, controller) = try open(url)
            let other = try #require(URL(string: "https://e.com/b.png"))
            let third = try #require(URL(string: "https://e.com/c.png"))

            controller.loadAllImages()
            controller.activateImage(ImageActivation(
                destination: other.absoluteString,
                documentURL: url,
                card: .remoteNotLoaded(host: "e.com")
            ))
            controller.reloadImage(ImageRequest(
                destination: third.absoluteString,
                documentURL: url,
                maxPixelSize: .zero
            ))
            while spy.transport.requests.count < 3 {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(Set(spy.transport.requests.compactMap(\.url?.lastPathComponent)) == ["a.png", "b.png", "c.png"])
        }

        @Test
        func `a window with no document keeps the title AppKit gives`() throws {
            let (document, controller) = try open(given())
            document.removeWindowController(controller)

            #expect(controller.windowTitle(forDocumentDisplayName: "Untitled 2") == "Untitled 2")
        }

        @Test
        func `the toolbar allows only its default items`() throws {
            let (_, controller) = try open(given())
            let toolbar = try #require(controller.window?.toolbar)

            #expect(controller.toolbarAllowedItemIdentifiers(toolbar) == [.flexibleSpace, .lock])
        }

        @Test
        func `the Save… item shows only for an untitled document`() throws {
            let (_, named) = try open(given())
            let untitled = ScrollDocument()
            untitled.environment = spy.environment
            TestApp.controller.addDocument(untitled)
            untitled.makeWindowControllers()
            let controller = try #require(untitled.windowControllers.first as? DocumentWindowController)
            let item = NSMenuItem(
                title: "Save…",
                action: #selector(DocumentWindowController.saveDocument),
                keyEquivalent: "s"
            )

            #expect(!named.validateMenuItem(item))
            #expect(item.isHidden)
            #expect(controller.validateMenuItem(item))
            #expect(!item.isHidden)
            #expect(controller.window?.title == "Untitled")
        }

        @Test
        func `a Format menu item performs its command, and Lock disables it`() throws {
            let (_, controller) = try open(given("a.md", "a\n"))
            let item = NSMenuItem(
                title: "Heading 1",
                action: #selector(DocumentWindowController.format),
                keyEquivalent: ""
            )
            item.tag = try #require(FormatAction.allCases.firstIndex(of: .heading1))

            controller.format(item)
            #expect(controller.markdownView.text == "# a\n")
            #expect(controller.validateMenuItem(item))
            controller.toggleLock(nil)
            #expect(!controller.validateMenuItem(item))
        }

        @Test
        func `the status bar and the format bar follow View`() throws {
            let defaults = UserDefaults.standard
            defer {
                defaults.removeObject(forKey: DocumentWindowController.showsStatusBarKey)
                defaults.removeObject(forKey: DocumentWindowController.showsFormatBarKey)
            }
            let (_, controller) = try open(given())
            let status = NSMenuItem(
                title: "",
                action: #selector(DocumentWindowController.toggleStatusBar),
                keyEquivalent: ""
            )
            let bar = NSMenuItem(
                title: "",
                action: #selector(DocumentWindowController.toggleFormatBar),
                keyEquivalent: ""
            )

            #expect(controller.validateMenuItem(status) && status.state == .on)
            controller.toggleStatusBar(nil)
            controller.toggleFormatBar(nil)
            _ = controller.validateMenuItem(status)
            _ = controller.validateMenuItem(bar)
            #expect(status.state == .off)
            #expect(bar.state == .off)
            #expect(!controller.markdownView.showsFormatBar)
        }

        static func button(_ title: String, in view: NSView?) -> NSButton? {
            for subview in view?.subviews ?? [] {
                if let button = subview as? NSButton, button.title == title {
                    return button
                }
                if let found = button(title, in: subview) {
                    return found
                }
            }
            return nil
        }
    }
#endif
