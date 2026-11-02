#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Screens §3.12, §3.13, §3.21: the strips under the nav bar.
    extension DocumentViewControllerTests {
        func strips(_ controller: DocumentViewController) -> [StripView] {
            controller.strips.arrangedSubviews.compactMap { $0 as? StripView }
        }

        func tapStrip(_ title: String, _ controller: DocumentViewController) {
            strips(controller).flatMap(\.buttons).first { $0.configuration?.title == title }?
                .sendActions(for: .primaryActionTriggered)
        }

        static func change(_ reason: TextChange.Reason, _ text: String) -> TextChange {
            TextChange(reason: reason, groupReason: reason, range: NSRange(), replacement: "", text: text)
        }

        @Test
        func `no strip shows for a file that saves`() async throws {
            let controller = try await screen()
            controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
            controller.view.layoutIfNeeded()

            #expect(strips(controller).isEmpty)
            #expect(controller.additionalSafeAreaInsets.top == 0)
        }

        @Test
        func `a deleted file shows its strip, and Close asks first`() async throws {
            let controller = try await screen("- [ ] a\n")
            try FileManager.default.removeItem(at: controller.document.fileURL)

            controller.textDidChange(Self.change(.checkbox, "- [x] a\n"))

            let strip = try #require(strips(controller).first)
            #expect(strip.kind == .deleted)
            #expect(strip.accessibilityLabel == "“a.md” was deleted. Your text is still here.")
            #expect(strip.buttons.map(\.configuration?.title) == ["Save as", "Close"])
            controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
            controller.view.layoutIfNeeded()
            #expect(controller.additionalSafeAreaInsets.top == controller.strips.frame.height)
            #expect(controller.additionalSafeAreaInsets.top >= 44)

            tapStrip("Close", controller)
            let alert = try #require(presented.last as? UIAlertController)
            #expect(alert.title == "Close without saving? The text will be lost.")
            #expect(alert.actions.map(\.title) == ["Cancel", "Close"])
            #expect(closed.isEmpty)
            tap(alert.actions[1])
            #expect(closed == [controller.document.fileURL])
        }

        @Test(.timeLimit(.minutes(1)))
        func `a failed save shows its strip, and Save As exports the text and opens the copy`() async throws {
            let controller = try await screen()
            let url = controller.document.fileURL
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path())
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path())
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path())
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path())
            }

            controller.textDidChange(Self.change(.edit, "# AB"))
            _ = await ScrollDocumentIOSTests.autosaved(controller.document)
            while strips(controller).isEmpty {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(strips(controller).map(\.accessibilityLabel) == [
                "Couldn’t save “a.md”. Fortkeeps Scroll will keep trying."
            ])
            let copy = try controller.exportCopy()
            #expect(copy.lastPathComponent == "a.md")
            #expect(try Data(contentsOf: copy) == Data("# AB\n".utf8))
            tapStrip("Save as", controller)
            let picker = try #require(presented.last as? UIDocumentPickerViewController)
            let moved = folder.appending(path: "Elsewhere/a.md")
            controller.documentPicker(picker, didPickDocumentsAt: [])
            controller.documentPicker(picker, didPickDocumentsAt: [moved])
            #expect(opened == [moved])

            // A deletion replaces the failed strip.
            controller.document.noteMoved(from: controller.document.fileURL, to: folder.appending(path: ".Trash/a.md"))
            #expect(strips(controller).map(\.kind) == [.deleted])
        }

        @Test
        func `a read-only file shows its strip, and Duplicate opens a copy in the app's folder`() async throws {
            let controller = try await screen()
            let url = controller.document.fileURL
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path())
            let document = ScrollDocument(fileURL: url)
            _ = await document.open()
            let readOnly = DocumentViewController(document: document, environment: environment)
            readOnly.loadViewIfNeeded()

            #expect(strips(readOnly).map(\.accessibilityLabel) == ["You can read this file but not change it."])
            tapStrip("Duplicate", readOnly)
            tapStrip("Duplicate", readOnly)

            let app = folder.appending(path: "App")
            #expect(opened.map(\.lastPathComponent) == ["a copy.md", "a copy 2.md"])
            #expect(try Data(contentsOf: app.appending(path: "a copy.md")) == Data("# A\n".utf8))
            #expect(presented.isEmpty)
        }

        @Test
        func `a Duplicate that cannot be written shows why`() async throws {
            environment.appFolder = URL(filePath: "/System/none")
            let controller = try await screen()

            controller.duplicate()

            #expect(opened.isEmpty)
            #expect((presented.last as? UIAlertController)?.actions.map(\.title) == ["OK"])
        }
    }
#endif
