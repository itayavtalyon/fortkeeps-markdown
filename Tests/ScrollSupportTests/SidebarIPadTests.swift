#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// The iPad sidebar (screens §3.4, §3.5; log 004 Round 6): a split view
    /// around the tabs, hidden at first, that keeps the last choice.
    extension TabsViewControllerTests {
        func outlineTitles() -> [String] {
            tabs.sidebar.outlineSection.list.map(\.title)
        }

        @Test
        func `the browser shows the tabs beside a hidden sidebar, and the next time follows the last choice`(
        ) async throws {
            let browser = BrowserViewController(session: session)
            try await browser.open([given("a.md")], typing: false)

            let split = try #require(presented.first as? UISplitViewController)
            #expect(split.modalPresentationStyle == .fullScreen)
            #expect(split.viewController(for: .secondary) === browser.tabs)
            #expect(split.viewController(for: .primary) === browser.tabs.sidebar)
            #expect(split.preferredDisplayMode == .secondaryOnly)
            browser.tabs.splitViewController(split, willChangeTo: .oneBesideSecondary)
            #expect(ScrollSettings(defaults: session.environment.defaults).showsSidebar)

            let next = BrowserViewController(session: session)
            try await next.open([given("b.md")], typing: false)
            #expect((presented.last as? UISplitViewController)?.preferredDisplayMode == .oneBesideSecondary)
        }

        @Test
        func `the sidebar shows the selected tab's Outline once it shows, and the bar has no Outline button`(
        ) async throws {
            try await opened("a.md", "b.md")
            #expect(tabs.tabs[1].outlineTask == nil)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
            window.rootViewController = tabs.sidebar
            window.makeKeyAndVisible()
            windows.append(window)
            tabs.sidebar.viewDidAppear(false)
            await tabs.tabs[1].outlineTask?.value
            #expect(outlineTitles() == ["b.md"])

            tabs.selectTab(UIKeyCommand(input: "1", modifierFlags: .command, action: #selector(tabs.selectTab)))
            await tabs.tabs[0].outlineTask?.value

            #expect(outlineTitles() == ["a.md"])
            tabs.tabs[1].markdownView.replaceText("# Other\n")
            #expect(tabs.tabs[1].outlineTask == nil)
            #expect(outlineTitles() == ["a.md"])
            #expect(tabs.navigationItem.rightBarButtonItems?.count == 2)
            #expect(tabs.sidebar.session === session)
        }

        @Test
        func `the Open Folder command keeps access to the chosen folder and shows it in the sidebar`() async throws {
            let chosen = folder.appending(path: "Shared")
            try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
            var environment = session.environment
            environment.access = FolderBookmarks(defaults: defaults) { _ in chosen }
            let tabs = TabsViewController(session: DocumentSession(store: session.store, environment: environment))

            let command = try #require(tabs.keyCommands?.first { $0.input == "o" })
            #expect(command.modifierFlags == [.command, .shift])
            #expect(command.title == "Open Folder…")
            await tabs.openFolder()

            #expect(tabs.sidebar.folder == chosen)
            #expect((environment.access as? FolderBookmarks)?.folders == [chosen])
        }

        @Test
        func `the Open Folder command does nothing without folder bookmarks`() async throws {
            try await opened("a.md")
            let shown = tabs.sidebar.folder

            tabs.openFolder(nil)
            await tabs.openFolder()

            #expect(tabs.sidebar.folder == shown)
        }
    }
#endif
