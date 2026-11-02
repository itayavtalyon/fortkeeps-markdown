#if os(iOS)
    import Foundation
    import MarkdownCore
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Runs an alert button's handler, as a tap does.
    @MainActor
    func tap(_ action: UIAlertAction) {
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        let handler = unsafeBitCast(action.value(forKey: "handler") as AnyObject, to: Handler.self)
        handler(action)
    }

    /// Design › iPhone home screen (log 002), Round 4 (log 004).
    @MainActor
    final class HomeViewControllerTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Home-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "HomeTests-\(UUID().uuidString)") ?? .standard
        var presented: [UIViewController] = []

        lazy var session = DocumentSession(
            store: FileListStore(defaults: defaults),
            environment: ScrollEnvironment(
                transport: FakeTransport([:]),
                access: FakeAccess(),
                openURL: { _ in },
                openFile: { _ in },
                closeFile: { _ in },
                present: { [weak self] controller, _ in self?.presented.append(controller) },
                appFolder: folder.appending(path: "Documents")
            )
        )
        lazy var home = HomeViewController(session: session)
        lazy var navigation = CountingNavigation(rootViewController: home)

        /// Counts the screens pushed, so a re-push of the screen on top shows.
        final class CountingNavigation: UINavigationController {
            var pushes = 0

            override func pushViewController(_ controller: UIViewController, animated: Bool) {
                pushes += 1
                super.pushViewController(controller, animated: animated)
            }
        }

        init() {
            navigation.loadViewIfNeeded()
            home.loadViewIfNeeded()
        }

        func given(_ name: String, in subfolder: String = "Notes") throws -> URL {
            let parent = folder.appending(path: subfolder)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let url = parent.appending(path: name)
            try Data("a\n".utf8).write(to: url)
            return url
        }

        var table: UITableView {
            home.tableView
        }

        func cell(_ row: Int, _ section: Int) -> UITableViewCell {
            home.tableView(table, cellForRowAt: IndexPath(row: row, section: section))
        }

        func content(_ row: Int, _ section: Int) -> UIListContentConfiguration? {
            cell(row, section).contentConfiguration as? UIListContentConfiguration
        }

        func headers() -> [String?] {
            (0 ..< home.numberOfSections(in: table)).map { home.tableView(table, titleForHeaderInSection: $0) }
        }

        @Test
        func `the title and the back button say Open Files`() {
            #expect(home.title == "Open Files")
            #expect(home.navigationItem.backButtonTitle == "Open Files")
        }

        @Test
        func `with no files the list says so and offers Browse`() throws {
            #expect(home.numberOfSections(in: table) == 0)
            let empty = try #require(table.backgroundView as? UIStackView)
            let label = try #require(empty.arrangedSubviews.first as? UILabel)
            #expect(label.text == "Files you open will show up here.")
            #expect((empty.arrangedSubviews[1] as? UIButton)?.configuration?.title == "Browse")
            #expect(empty.arrangedSubviews.count == 3)
        }

        @Test(.timeLimit(.minutes(1)))
        func `the toolbar has Browse and New File, and the empty list has Browse`() async throws {
            let titles = home.toolbarItems?.compactMap(\.title)
            #expect(titles == ["Browse", "New file"])

            home.toolbarItems?.first?.primaryAction?.performWithSender(nil, target: nil)
            let browse = try #require((table.backgroundView as? UIStackView)?.arrangedSubviews[1] as? UIButton)
            browse.sendActions(for: .primaryActionTriggered)
            #expect(presented.count == 2)
            #expect(presented.allSatisfy { $0 is UIDocumentPickerViewController })

            home.toolbarItems?.last?.primaryAction?.performWithSender(nil, target: nil)
            while navigation.viewControllers.count < 2 {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(navigation.topViewController?.title == "Untitled.md")
        }

        @Test
        func `the Open section comes first, Recent after; Open hides when nothing is open`() throws {
            let first = try given("a.md")
            try session.store.closed(given("b.md"), at: .now)
            #expect(headers() == ["Recent"])

            session.store.opened(first, at: .now)

            #expect(headers() == ["Open", "Recent"])
            #expect(table.backgroundView == nil)
        }

        @Test
        func `a row shows the name, the folder, and the time`() throws {
            let today = try #require(Calendar.current.date(bySettingHour: 9, minute: 15, second: 0, of: .now))
            try session.store.closed(given("Trip.md"), at: today)

            let row = try #require(content(0, 0))

            #expect(row.text == "Trip.md")
            #expect(row.secondaryText?.hasPrefix("Notes\n") == true)
            #expect(row.secondaryText?.hasSuffix(today.formatted(date: .omitted, time: .shortened)) == true)
            #expect(row.secondaryText?.contains("Today") == true)
            #expect(row.secondaryTextProperties.numberOfLines == 0)
        }

        @Test
        func `search filters both sections, and no match says so`() throws {
            try session.store.opened(given("Trip.md"), at: .now)
            try session.store.closed(given("Notes.md"), at: .now)

            home.updateSearchResults(for: Self.search("trip"))
            #expect(headers() == ["Open"])

            home.updateSearchResults(for: Self.search(nil))
            #expect(headers() == ["Open", "Recent"])
            home.updateSearchResults(for: Self.search("zzz"))
            #expect(home.numberOfSections(in: table) == 0)
            let empty = try #require(table.backgroundView as? UIStackView)
            #expect((empty.arrangedSubviews.first as? UILabel)?.text == "No files match “zzz”.")
            #expect(!empty.arrangedSubviews.contains { $0 is UIButton })
        }

        static func search(_ text: String?) -> UISearchController {
            let search = UISearchController()
            search.searchBar.text = text
            return search
        }

        @Test
        func `an Open row swipes to Close and a Recent row to Remove from Recent, in every menu`() throws {
            try session.store.opened(given("a.md"), at: .now)
            try session.store.closed(given("b.md"), at: .now)

            for (section, title) in [(0, "Close"), (1, "Remove from Recent")] {
                let path = IndexPath(row: 0, section: section)
                let swipe = home.tableView(table, trailingSwipeActionsConfigurationForRowAt: path)
                #expect(swipe?.actions.map(\.title) == [title])
                #expect(cell(0, section).accessibilityCustomActions?.map(\.name) == [title])
                let configuration = home.tableView(table, contextMenuConfigurationForRowAt: path, point: .zero)
                typealias Provider = @convention(block) ([UIMenuElement]) -> UIMenu?
                let provider = try #require(configuration?.value(forKey: "actionProvider") as AnyObject?)
                let menu = unsafeBitCast(provider, to: Provider.self)([])
                #expect(menu?.children.map(\.title) == [title])
            }
        }

        @Test
        func `removing a Recent row never removes the file`() throws {
            let url = try given("b.md")
            session.store.closed(url, at: .now)
            let path = IndexPath(row: 0, section: 0)

            let action = try #require(home.tableView(table, trailingSwipeActionsConfigurationForRowAt: path)?
                .actions.first)
            action.handler(action, UIView()) { _ in }

            #expect(session.store.lists.recent.isEmpty)
            #expect(FileManager.default.fileExists(atPath: url.path()))
        }

        @Test
        func `a row's action acts on its own file after the list changes`() throws {
            try session.store.closed(given("a.md"), at: .now)
            let path = IndexPath(row: 0, section: 0)
            let action = try #require(home.tableView(table, trailingSwipeActionsConfigurationForRowAt: path)?
                .actions.first)

            try session.store.closed(given("b.md"), at: .now)
            action.handler(action, UIView()) { _ in }

            #expect(session.store.lists.recent.map(\.url.lastPathComponent) == ["b.md"])
        }

        @Test(.timeLimit(.minutes(1)))
        func `the VoiceOver action closes an open file`() async throws {
            let screen = try #require(try await session.open(given("a.md")))
            let action = try #require(cell(0, 0).accessibilityCustomActions?.first)

            #expect(action.actionHandler?(action) == true)
            while session.store.lists.recent.isEmpty {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(session.screen(for: screen.document.fileURL) == nil)
        }

        @Test
        func `the long-press menu has the row's action`() throws {
            try session.store.closed(given("b.md"), at: .now)

            let menu = home.menu(for: IndexPath(row: 0, section: 0))

            #expect(menu.children.map(\.title) == ["Remove from Recent"])
            (menu.children.first as? UIAction)?.performWithSender(nil, target: nil)
            #expect(session.store.lists.recent.isEmpty)
        }

        @Test(.timeLimit(.minutes(1)))
        func `tapping a row pushes its file`() async throws {
            try session.store.closed(given("a.md"), at: .now)

            home.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
            while navigation.viewControllers.count < 2 {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(navigation.viewControllers.count == 2)
            #expect(navigation.topViewController?.title == "a.md")
            #expect(headers() == ["Open"])
        }

        @Test
        func `showing the file on screen again keeps one screen of it`() async throws {
            let url = try given("a.md")
            await home.show(url)
            try await home.show(given("b.md"))
            let pushes = navigation.pushes

            await home.show(url)
            await home.show(url)

            #expect(navigation.viewControllers.map(\.title) == ["Open Files", "a.md"])
            #expect(navigation.pushes == pushes + 1)
        }

        @Test
        func `closing the shown file goes back to Open Files and moves it to Recent`() async throws {
            let url = try given("a.md")
            await home.show(url)

            await home.close(url)
            try await home.close(given("b.md"))

            #expect(navigation.viewControllers.count == 1)
            #expect(session.store.lists.recent.map(\.url.lastPathComponent) == ["a.md"])
        }

        @Test
        func `the New file button pushes Untitled with the keyboard up`() async throws {
            await home.newFile()

            let screen = try #require(navigation.topViewController as? DocumentViewController)
            #expect(screen.title == "Untitled.md")
            #expect(screen.startsTyping)
        }

        @Test(.timeLimit(.minutes(1)))
        func `the Browse button opens the Files picker, and a picked file opens`() async throws {
            let url = try given("a.md")
            home.browse()
            let picker = try #require(presented.first as? UIDocumentPickerViewController)

            home.documentPicker(picker, didPickDocumentsAt: [])
            home.documentPicker(picker, didPickDocumentsAt: [url])
            while navigation.viewControllers.count < 2 {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(navigation.topViewController?.title == "a.md")
        }
    }
#endif
