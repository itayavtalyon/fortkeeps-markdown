#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Settings on iOS (screens §3.17; log 004 Round 6): a sheet from the ⋯ menu.
    extension DocumentViewControllerTests {
        func settingsSheet(_ controller: DocumentViewController) throws -> SettingsViewController {
            perform("Settings", controller)
            let sheet = try #require(presented.last as? UINavigationController)
            return try #require(sheet.topViewController as? SettingsViewController)
        }

        func text(_ settings: SettingsViewController, _ row: Int, _ section: Int) -> String? {
            let table: UITableView = settings.tableView
            let cell = settings.tableView(table, cellForRowAt: IndexPath(row: row, section: section))
            return (cell.contentConfiguration as? UIListContentConfiguration)?.text
        }

        @Test
        func `the line width is a choice of three, and the text follows it`() async throws {
            let controller = try await screen()
            let settings = try settingsSheet(controller)
            let table: UITableView = settings.tableView

            #expect(settings.tableView(table, titleForHeaderInSection: 0) == "Line width")
            #expect((0 ..< 3).map { text(settings, $0, 0) } == ["Narrow", "Medium", "Wide"])
            let checked = (0 ..< 3).map {
                settings.tableView(table, cellForRowAt: IndexPath(row: $0, section: 0)).accessoryType
            }
            #expect(checked == [.none, .checkmark, .none])
            #expect(controller.markdownView.maxLineWidth == 680)

            settings.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
            #expect(controller.markdownView.maxLineWidth == 560)
            settings.tableView(table, didSelectRowAt: IndexPath(row: 2, section: 0))

            #expect(ScrollSettings(defaults: environment.defaults).lineWidth == .wide)
            #expect(controller.markdownView.maxLineWidth == 840)
        }

        @Test
        func `the folders with access are listed, and Remove takes one away`() async throws {
            let shared = folder.appending(path: "Shared")
            try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
            let bookmarks = FolderBookmarks(defaults: environment.defaults) { _ in nil }
            #expect(bookmarks.grant(shared))
            environment.access = bookmarks
            let settings = try await settingsSheet(screen())
            let table: UITableView = settings.tableView

            #expect(settings.tableView(table, titleForHeaderInSection: 1) == "Folders Fortkeeps Scroll can open")
            #expect(text(settings, 0, 1)?.hasSuffix("/Shared") == true)
            let cell = settings.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1))
            let remove = try #require(cell.accessoryView as? UIButton)
            #expect(remove.configuration?.title == "Remove")
            remove.sendActions(for: .primaryActionTriggered)

            #expect(bookmarks.folders.isEmpty)
            #expect(text(settings, 0, 1) == "None yet.")
        }

        @Test
        func `with no folder the list says so`() async throws {
            let settings = try await settingsSheet(screen())

            let table: UITableView = settings.tableView
            #expect(settings.tableView(table, numberOfRowsInSection: 1) == 1)
            #expect(text(settings, 0, 1) == "None yet.")
        }

        @Test
        func `clearing the image cache shows the size, clears it, and says so`() async throws {
            try environment.cache.store(Data(count: 2000), for: #require(URL(string: "https://e.com/a.png")))
            let settings = try await settingsSheet(screen())
            settings.announce("") // the system announcement, with VoiceOver off
            var announced: [String] = []
            settings.announce = { announced.append($0) }
            let table: UITableView = settings.tableView

            #expect(text(settings, 0, 2) == "Clear image cache (2 KB)")
            #expect(settings.tableView(table, titleForFooterInSection: 2) == ScrollStrings.imageCacheNote)
            settings.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 2))

            #expect(environment.cache.size() == 0)
            #expect(announced == ["Image cache cleared."])
            #expect(text(settings, 0, 2) == "Image cache is empty")
            #expect(settings.tableView(table, shouldHighlightRowAt: IndexPath(row: 0, section: 2)) == false)
            #expect(settings.tableView(table, shouldHighlightRowAt: IndexPath(row: 0, section: 0)))
        }
    }
#endif
