#if os(iOS)
    import Foundation
    import MarkdownCore
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Log 002 › iPhone home screen: a Recent file that is gone.
    extension HomeViewControllerTests {
        @Test
        func `a missing file is dimmed, says why, and offers Find File`() async throws {
            let url = try given("a.md")
            session.store.closed(url, at: .now)
            try FileManager.default.removeItem(at: url)
            session = DocumentSession(
                store: FileListStore(defaults: defaults), environment: session.environment
            )
            home = HomeViewController(session: session)
            home.loadViewIfNeeded()

            let row = try #require(content(0, 0))
            #expect(row.secondaryText == "Can’t find this file. It may have been moved or deleted.")
            #expect(row.textProperties.color == .secondaryLabel)
            #expect(cell(0, 0).accessibilityLabel == "a.md, can’t find this file")

            await home.select(IndexPath(row: 0, section: 0))
            let sheet = try #require(presented.last as? UIAlertController)
            #expect(sheet.title == "Can’t find “a.md”")
            #expect(sheet.actions.map(\.title) == ["Find File…", "Remove from Recent", "Cancel"])

            tap(sheet.actions[0])
            #expect(presented.last is UIDocumentPickerViewController)
            tap(sheet.actions[1])
            #expect(session.store.lists.recent.isEmpty)
        }

        @Test
        func `the Find File action points the row at the picked file and keeps its place`() async throws {
            let url = try given("a.md")
            session.store.closed(url, at: .now)
            try session.store.closed(given("b.md"), at: .now)
            try FileManager.default.removeItem(at: url)
            session = DocumentSession(
                store: FileListStore(defaults: defaults), environment: session.environment
            )
            home = HomeViewController(session: session)
            home.loadViewIfNeeded()
            home.find(session.store.lists.recent[1].url)
            let picker = try #require(presented.last as? UIDocumentPickerViewController)

            try await home.picked(given("moved.md", in: "Moved"), by: picker)

            #expect(session.store.lists.recent.map(\.url.lastPathComponent) == ["b.md", "moved.md"])
            #expect(session.store.missing.isEmpty)
        }
    }
#endif
