#if os(macOS)
    import AppKit
    @testable import ScrollSupport
    import Testing

    /// Design › Windows and chrome: launch, the empty window, and the menu bar.
    @MainActor
    struct ScrollAppDelegateTests {
        let clock = FakeClock()
        let cache: ImageCache

        init() {
            _ = TestApp.controller
            cache = ImageCache(
                directory: FileManager.default.temporaryDirectory.appending(path: "AppCache-\(UUID().uuidString)"),
                now: clock.now
            )
        }

        /// The shared controller; `hasDocuments` stands for the list AppKit
        /// shares with the other tests.
        func given(documents: Bool = false) -> ScrollAppDelegate {
            let delegate = ScrollAppDelegate(documents: TestApp.controller, cache: cache)
            delegate.hasDocuments = { documents }
            return delegate
        }

        @Test
        func `with no document the app shows the empty window, not an untitled one`() {
            let delegate = given()

            #expect(!delegate.applicationShouldOpenUntitledFile(NSApplication.shared))
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

            #expect(delegate.emptyWindow != nil)
            delegate.emptyWindow?.close()
        }

        @Test
        func `a document closes the empty window, and closing the last shows it`() throws {
            var open = false
            let delegate = given()
            delegate.hasDocuments = { open }
            delegate.showEmptyWindowIfNeeded()
            let document = ScrollDocument()

            let shown = try #require(delegate.emptyWindow)

            open = true
            TestApp.controller.addDocument(document)
            // One controller for the app's life; it rebuilds for the current recent files.
            #expect(delegate.emptyWindow === shown)
            #expect(shown.window?.isVisible == false)
            open = false
            TestApp.controller.removeDocument(document)
            #expect(delegate.emptyWindow === shown)
            #expect(shown.window?.isVisible == true)
            shown.close()
        }

        @Test
        func `the app counts the documents of its controller`() {
            let delegate = ScrollAppDelegate(documents: TestApp.controller)
            let document = ScrollDocument()
            TestApp.controller.addDocument(document)
            defer { TestApp.controller.removeDocument(document) }

            #expect(delegate.hasDocuments())
        }

        @Test
        func `a Dock click with no window shows the empty window`() {
            let delegate = given()

            #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
            #expect(delegate.emptyWindow != nil)
            delegate.emptyWindow?.close()
            #expect(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
        }

        @Test
        func `the launch sets the menu bar`() throws {
            let delegate = given()

            delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))

            let menu = try #require(NSApplication.shared.mainMenu)
            #expect(menu.items.map(\.title) == ["Fortkeeps Scroll", "File", "Edit", "Format", "View", "Window", "Help"])
            #expect(NSApplication.shared.windowsMenu === menu.item(withTitle: "Window")?.submenu)
            #expect(NSApplication.shared.helpMenu === menu.item(withTitle: "Help")?.submenu)
        }

        @Test
        func `the app purges its image cache at launch and when it is left`() throws {
            let delegate = given()
            let url = try #require(URL(string: "https://e.com/a.png"))
            cache.store(Data("png".utf8), for: url)
            clock.advance(by: ImageCache.lifetime + 1)

            delegate.applicationDidResignActive(Notification(name: NSApplication.didResignActiveNotification))
            #expect(cache.size() == 0)
            cache.store(Data("png".utf8), for: url)
            clock.advance(by: ImageCache.lifetime + 1)
            delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
            #expect(cache.size() == 0)
        }

        @Test
        func `the app's own init uses the shared cache in Caches`() {
            #expect(ScrollAppDelegate().cache.directory == URL.cachesDirectory.appending(path: "Images"))
        }

        @Test
        func `the Acknowledgements item opens one window`() throws {
            let delegate = given()

            delegate.showAcknowledgements(nil)
            let first = try #require(NSApplication.shared.windows.first { $0.title == "Acknowledgements" })
            delegate.showAcknowledgements(nil)

            #expect(NSApplication.shared.windows.filter { $0.title == "Acknowledgements" && $0.isVisible } == [first])
            first.close()
        }

        @Test
        func `a recent file opens its document`() async throws {
            let delegate = given()
            let documents = TestApp.controller
            let url = FileManager.default.temporaryDirectory.appending(path: "Recent-\(UUID().uuidString).md")
            try Data("a\n".utf8).write(to: url)
            delegate.open(url)
            while documents.document(for: url) == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            documents.document(for: url)?.close()
        }

        @Test
        func `the File menu leaves Open Recent to AppKit, which adds it after Open…`() throws {
            let file = try #require(MainMenu.make().item(withTitle: "File")?.submenu)

            #expect(file.items.prefix(3).map(\.title) == ["New File", "Open…", ""])
        }

        @Test
        func `the Remove from Recent item removes only that file`() throws {
            let delegate = given()
            let documents = TestApp.controller
            // The system keeps recents for files that exist, in one list per process.
            let folder = FileManager.default.temporaryDirectory.appending(path: "RecentTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let urls = try (1 ... 3).map { index in
                let url = folder.appending(path: "\(index).md")
                try Data().write(to: url)
                return url.resolvingSymlinksInPath()
            }
            urls.forEach(documents.noteNewRecentDocumentURL)
            delegate.showEmptyWindowIfNeeded()
            let window = try #require(delegate.emptyWindow?.window)
            #expect(try EmptyWindowTests.button("2.md", in: #require(window.contentView)) != nil)

            // The empty window passes a URL of the list itself.
            let listed = try #require(documents.recentDocumentURLs.first { $0.resolvingSymlinksInPath() == urls[1] })
            delegate.removeRecent(listed)

            #expect(try EmptyWindowTests.button("2.md", in: #require(window.contentView)) == nil)

            let mine = documents.recentDocumentURLs.map { $0.resolvingSymlinksInPath() }.filter(urls.contains)
            #expect(mine == [urls[2], urls[0]])
            delegate.emptyWindow?.close()
        }
    }
#endif
