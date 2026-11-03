#if os(macOS)
    import AppKit
    @testable import ScrollSupport
    import Testing

    /// Settings (screens §3.17; log 004 Round 6): one pane, 420 pt wide.
    @MainActor
    struct SettingsWindowTests {
        let root = FileManager.default.temporaryDirectory.appending(path: "SettingsWindowTests-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "SettingsWindowTests-\(UUID().uuidString)") ?? .standard
        var cache: ImageCache {
            ImageCache(directory: root.appending(path: "cache"))
        }

        func make(_ bookmarks: FolderBookmarks? = nil) -> (SettingsWindowController, Box) {
            let box = Box()
            let controller = SettingsWindowController(
                settings: ScrollSettings(defaults: defaults),
                bookmarks: bookmarks ?? FolderBookmarks(defaults: defaults) { _ in nil },
                cache: cache
            )
            controller.announce = { box.announced.append($0) }
            return (controller, box)
        }

        final class Box {
            var announced: [String] = []
        }

        @Test
        func `the pane shows the settings as they are`() throws {
            let (controller, _) = make()
            let window = try #require(controller.window)

            #expect(window.title == "Settings")
            #expect(window.frame.width == 420)
            #expect(controller.lineWidth.itemTitles == ["Narrow", "Medium", "Wide"])
            #expect(controller.lineWidth.titleOfSelectedItem == "Medium")
            #expect(controller.wordCount.title == "Show word count")
            #expect(controller.wordCount.state == .on)
            #expect(DocumentWindowTests.texts(in: controller.folders) == ["None yet."])
            #expect(controller.clearCache.title == "Image cache is empty")
            #expect(!controller.clearCache.isEnabled)
            #expect(DocumentWindowTests.texts(in: window.contentView).contains(ScrollStrings.imageCacheNote))
        }

        @Test
        func `a line width and the word count are kept`() {
            let (controller, _) = make()

            controller.lineWidth.selectItem(at: 2)
            controller.lineWidth.sendAction(controller.lineWidth.action, to: controller.lineWidth.target)
            controller.wordCount.performClick(nil)

            #expect(ScrollSettings(defaults: defaults).lineWidth == .wide)
            #expect(!ScrollSettings(defaults: defaults).showsWordCount)
        }

        @Test
        func `a folder with access shows with Remove, which revokes it`() throws {
            let docs = root.appending(path: "docs")
            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            let bookmarks = FolderBookmarks(defaults: defaults) { _ in nil }
            bookmarks.grant(docs)
            let (controller, _) = make(bookmarks)

            #expect(DocumentWindowTests.texts(in: controller.folders) == [
                (docs.path as NSString).abbreviatingWithTildeInPath, "Remove"
            ])
            let remove = try #require(controller.folders.subviews.first?.subviews.last as? NSButton)
            remove.performClick(nil)

            #expect(bookmarks.folders.isEmpty)
            #expect(DocumentWindowTests.texts(in: controller.folders) == ["None yet."])
        }

        @Test
        func `the Clear Image Cache button shows the size, clears at once, and says so`() throws {
            try cache.store(Data(count: 4200), for: #require(URL(string: "https://e.com/a.png")))
            let (controller, box) = make()

            #expect(controller.clearCache.title == "Clear Image Cache (4 KB)")
            controller.clearCache.performClick(nil)

            #expect(cache.size() == 0)
            #expect(controller.clearCache.title == "Image cache is empty")
            #expect(!controller.clearCache.isEnabled)
            #expect(box.announced == ["Image cache cleared."])
        }

        @Test
        func `the app's announcement goes to VoiceOver`() {
            let controller = SettingsWindowController(
                settings: ScrollSettings(defaults: defaults),
                bookmarks: FolderBookmarks(defaults: defaults) { _ in nil },
                cache: cache
            )

            controller.announce("Image cache cleared.")
        }
    }
#endif
