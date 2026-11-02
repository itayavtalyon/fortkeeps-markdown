#if os(iOS)
    import Foundation
    import MarkdownCore
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Screens §3.19 (iPad), log 001 › Windows and chrome: the tab strip
    /// under the nav bar, its shortcuts, and the document browser.
    @MainActor
    final class TabsViewControllerTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Tabs-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "TabsTests-\(UUID().uuidString)") ?? .standard
        var presented: [UIViewController] = []
        var emptied = 0

        lazy var session = DocumentSession(
            store: FileListStore(defaults: defaults),
            environment: ScrollEnvironment(
                transport: FakeTransport([:]),
                access: FakeAccess(),
                openURL: { _ in },
                openFile: { _ in },
                closeFile: { _ in },
                present: { [weak self] controller, _ in self?.presented.append(controller) },
                appFolder: folder
            )
        )
        lazy var tabs: TabsViewController = {
            let tabs = TabsViewController(session: session)
            tabs.showBrowser = { [weak self] in self?.emptied += 1 }
            tabs.loadViewIfNeeded()
            return tabs
        }()

        func given(_ name: String) throws -> URL {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data("# \(name)\n".utf8).write(to: url)
            return url
        }

        func opened(_ names: String...) async throws {
            for name in names {
                try await tabs.open(given(name))
            }
        }

        var tabTitles: [String?] {
            tabs.strip.arrangedSubviews.map { ($0 as? TabView)?.nameButton.configuration?.title }
        }

        @Test
        func `each tab shows the file name and a close control named for it`() async throws {
            try await opened("a.md", "b.md")

            #expect(tabTitles == ["a.md", "b.md"])
            let tab = try #require(tabs.strip.arrangedSubviews.first as? TabView)
            #expect(tab.closeButton.accessibilityLabel == "Close a.md")
        }

        @Test
        func `the opened tab is selected and fills the content`() async throws {
            try await opened("a.md", "b.md")

            #expect(tabs.selected?.title == "b.md")
            #expect(tabs.children.map(\.title) == ["b.md"])
            #expect(tabs.navigationItem.title == "b.md")
            #expect(tabs.navigationItem.rightBarButtonItem === tabs.selected?.navigationItem.rightBarButtonItem)
            let tab = try #require(tabs.strip.arrangedSubviews.last as? TabView)
            #expect(tab.nameButton.accessibilityTraits.contains(.selected))
        }

        @Test
        func `opening an open file selects its tab`() async throws {
            try await opened("a.md", "b.md", "a.md")

            #expect(tabTitles == ["a.md", "b.md"])
            #expect(tabs.selected?.title == "a.md")
        }

        @Test(.timeLimit(.minutes(1)))
        func `tapping a tab selects it; its close control closes it`() async throws {
            try await opened("a.md", "b.md")
            let first = try #require(tabs.strip.arrangedSubviews.first as? TabView)

            first.nameButton.sendActions(for: .primaryActionTriggered)
            #expect(tabs.selected?.title == "a.md")
            await tabs.close(at: 0)

            #expect(tabTitles == ["b.md"])
            #expect(tabs.selected?.title == "b.md")
            #expect(session.store.lists.recent.map(\.url.lastPathComponent) == ["a.md"])
            first.closeButton.sendActions(for: .primaryActionTriggered)
            #expect(tabTitles == ["b.md"])

            let last = try #require(tabs.strip.arrangedSubviews.first as? TabView)
            last.closeButton.sendActions(for: .primaryActionTriggered)
            while !tabTitles.isEmpty {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `a renamed file renames its tab`() async throws {
            try await opened("a.md", "b.md")
            let first = try #require(tabs.tabs.first)
            let renamed = folder.appending(path: "c.md")
            try FileManager.default.moveItem(at: folder.appending(path: "a.md"), to: renamed)

            first.document.presentedItemDidMove(to: renamed)
            while tabTitles != ["c.md", "b.md"] {
                try await Task.sleep(for: .milliseconds(10))
            }

            let tab = try #require(tabs.strip.arrangedSubviews.first as? TabView)
            #expect(tab.closeButton.accessibilityLabel == "Close c.md")
            #expect(tabs.navigationItem.title == "b.md")
        }

        @Test
        func `closing a file closes its tab`() async throws {
            try await opened("a.md", "b.md")

            await tabs.close(folder.appending(path: "a.md"))
            await tabs.close(folder.appending(path: "c.md"))

            #expect(tabTitles == ["b.md"])
        }

        @Test
        func `closing the selected tab selects the one after it, or else the last`() async throws {
            try await opened("a.md", "b.md", "c.md")
            tabs.previousTab()

            await tabs.close(at: 1)
            #expect(tabs.selected?.title == "c.md")
            await tabs.close(at: 1)
            #expect(tabs.selected?.title == "a.md")
        }

        @Test
        func `closing the last tab goes back to the browser`() async throws {
            try await opened("a.md")

            await tabs.close(at: 0)

            #expect(tabs.selected == nil)
            #expect(tabs.children.isEmpty)
            #expect(emptied == 1)
        }

        @Test
        func `the tab shortcuts: Command-W, Shift-Command-brackets, Command-1 to 9`() async throws {
            try await opened("a.md", "b.md", "c.md")
            let commands = try #require(tabs.keyCommands)
            let inputs = commands.map { ($0.input ?? "") + ($0.modifierFlags == [.command, .shift] ? "⇧" : "") }
            #expect(inputs == ["w", "[⇧", "]⇧"] + (1 ... 9).map(String.init))

            tabs.previousTab()
            #expect(tabs.selected?.title == "b.md")
            tabs.nextTab()
            tabs.nextTab()
            #expect(tabs.selected?.title == "a.md")
            tabs.previousTab()
            #expect(tabs.selected?.title == "c.md")
            tabs.selectTab(commands[4])
            #expect(tabs.selected?.title == "b.md")
            tabs.selectTab(commands[11])
            #expect(tabs.selected?.title == "b.md")
            tabs.closeTab()
            try await Task.sleep(for: .milliseconds(100))
            #expect(tabTitles == ["a.md", "c.md"])
        }

        @Test
        func `the Browse button goes back to the browser and keeps the tabs`() async throws {
            try await opened("a.md")

            tabs.navigationItem.leftBarButtonItem?.primaryAction?.performWithSender(nil, target: nil)

            #expect(emptied == 1)
            #expect(tabTitles == ["a.md"])
        }

        @Test
        func `the tab bar follows the selected document`() async throws {
            try await opened("a.md")

            tabs.selected?.toggleLock()

            if #available(iOS 26, *) {
                #expect(tabs.navigationItem.subtitle == tabs.selected?.statusText)
            }
        }

        // MARK: document browser

        @Test
        func `the browser opens picked files in tabs and shows them`() async throws {
            let browser = BrowserViewController(session: session)
            let url = try given("a.md")

            await browser.open([url], typing: false)
            try await browser.open([given("b.md")], typing: false)

            #expect(browser.tabs.strip.arrangedSubviews.count == 2)
            #expect(presented.count == 1)
            let shown = try #require(presented.first as? UINavigationController)
            #expect(shown.topViewController === browser.tabs)
            #expect(shown.modalPresentationStyle == .fullScreen)
            #expect(session.alertHost === browser.tabs)
            browser.tabs.showBrowser?()
            #expect(session.alertHost === browser)
        }

        @Test
        func `the browser's New makes an empty Untitled.md for it to move`() throws {
            let browser = BrowserViewController(session: session)
            var made: (URL?, UIDocumentBrowserViewController.ImportMode)?

            browser.documentBrowser(browser) { made = ($0, $1) }

            let url = try #require(made?.0)
            #expect(url.lastPathComponent == "Untitled.md")
            #expect(made?.1 == .move)
            #expect(try Data(contentsOf: url).isEmpty)
        }

        @Test
        func `an imported new file opens with the keyboard up`() async throws {
            let browser = BrowserViewController(session: session)
            let url = try given("Untitled.md")

            browser.documentBrowser(browser, didImportDocumentAt: url, toDestinationURL: url)
            browser.documentBrowser(browser, didPickDocumentsAt: [])
            while browser.tabs.selected == nil {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(browser.tabs.selected?.startsTyping == true)
        }

        @Test
        func `a failed import shows the alert`() throws {
            let browser = BrowserViewController(session: session)

            try browser.documentBrowser(
                browser, failedToImportDocumentAt: given("a.md"), error: CocoaError(.fileWriteNoPermission)
            )

            #expect((presented.first as? UIAlertController)?.title == "Can’t open “a.md”")
        }

        @Test
        func `a refused file opens no tab`() async throws {
            session.alertHost = tabs
            try await tabs.open(given("a.png"))

            #expect(tabs.strip.arrangedSubviews.isEmpty)
            #expect(presented.count == 1)
        }
    }
#endif
