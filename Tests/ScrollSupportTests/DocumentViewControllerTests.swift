#if os(iOS)
    import Foundation
    @testable import MarkdownViews
    @testable import ScrollSupport
    import Testing
    import UIKit

    /// Screens §3.20 (iPhone document) and §3.13 (Lock), log 001 › Links.
    @MainActor
    final class DocumentViewControllerTests {
        let folder = FileManager.default.temporaryDirectory.appending(path: "DocumentVC-\(UUID().uuidString)")
        var opened: [URL] = []
        var presented: [UIViewController] = []
        var closed: [URL] = []
        var printed: [UIPrintInteractionController] = []
        let transport = FakeTransport([:])
        /// Windows a test puts a screen in, kept until the test ends.
        var windows: [UIWindow] = []

        lazy var environment = ScrollEnvironment(
            transport: transport,
            access: FakeAccess(),
            openURL: { [weak self] in self?.opened.append($0) },
            openFile: { [weak self] in self?.opened.append($0) },
            closeFile: { [weak self] in self?.closed.append($0) },
            present: { [weak self] controller, _ in self?.presented.append(controller) },
            appFolder: folder.appending(path: "App"),
            runPrint: { [weak self] controller, _ in self?.printed.append(controller) },
            defaults: UserDefaults(suiteName: "Scroll-\(UUID().uuidString)") ?? .standard,
            pasteboard: .withUniqueName(),
            cache: ImageCache(directory: folder.appending(path: "Cache"))
        )

        func screen(_ text: String = "# A\n", name: String = "a.md") async throws -> DocumentViewController {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try Data(text.utf8).write(to: url)
            let document = ScrollDocument(fileURL: url)
            _ = await document.open()
            let controller = DocumentViewController(document: document, environment: environment)
            controller.loadViewIfNeeded()
            return controller
        }

        func menuTitles(_ controller: DocumentViewController) -> [String] {
            controller.navigationItem.rightBarButtonItem?.menu?.children.map(\.title) ?? []
        }

        /// An item of the ⋯ menu, or of its Export submenu.
        func perform(_ title: String, _ controller: DocumentViewController) {
            let items = controller.navigationItem.rightBarButtonItem?.menu?.children ?? []
            let action = (items + items.compactMap { $0 as? UIMenu }.flatMap(\.children))
                .compactMap { $0 as? UIAction }.first { $0.title == title }
            action?.performWithSender(nil, target: nil)
        }

        @Test
        func `the title block shows the name, then the folder and the save state`() async throws {
            let controller = try await screen()

            #expect(controller.title == "a.md")
            #expect(controller.markdownView.accessibilityLabel == "a.md")
            #expect(controller.statusText == folder.lastPathComponent + " · Saved")
            if #available(iOS 26, *) {
                #expect(controller.navigationItem.subtitle == controller.statusText)
            }
        }

        @Test
        func `an edit shows Saving until the document saves`() async throws {
            let controller = try await screen()

            controller.textDidChange(TextChange(
                reason: .edit, groupReason: .edit, range: NSRange(), replacement: "", text: "# AB\n"
            ))

            #expect(controller.document.text == "# AB\n")
            #expect(controller.statusText == folder.lastPathComponent + " · Saving…")
        }

        @Test
        func `the more menu has Find, Lock, Export, and Settings, and Lock toggles with its title`() async throws {
            let controller = try await screen()
            #expect(menuTitles(controller) == ["Find", "Lock", "Export", "Settings"])

            perform("Lock", controller)

            #expect(controller.markdownView.mode == .editorLocked)
            #expect(controller.statusText == folder.lastPathComponent + " · Locked")
            #expect(menuTitles(controller) == ["Find", "Unlock", "Export", "Settings"])
            controller.toggleLock()
            #expect(controller.markdownView.mode == .editor)
        }

        @Test
        func `a new file puts the caret in the text once it shows`() async throws {
            let controller = try await screen()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            window.addSubview(controller.view)
            controller.startsTyping = true

            controller.viewDidAppear(false)
            controller.viewDidAppear(false)

            #expect(controller.markdownView.textView.isFirstResponder)
            #expect(!controller.startsTyping)
        }

        @Test
        func `the Lock shortcut is Option-Command-L`() async throws {
            let controller = try await screen()

            let command = try #require(controller.keyCommands?.first)

            #expect(command.input == "l")
            #expect(command.modifierFlags == [.command, .alternate])
            #expect(command.action == #selector(DocumentViewController.toggleLock))
            #expect(command.title == "Lock")
        }

        @Test
        func `the Settings item opens a sheet whose Done closes it`() async throws {
            let controller = try await screen()

            perform("Settings", controller)

            let sheet = try #require(presented.first as? UINavigationController)
            let settings = try #require(sheet.topViewController)
            #expect(settings.title == "Settings")
            let done = try #require(settings.navigationItem.rightBarButtonItem)
            #expect(done.style == .done)
            done.primaryAction?.performWithSender(nil, target: nil)
        }

        @Test
        func `a file it cannot write opens locked, and Lock stays`() async throws {
            let controller = try await screen()
            let url = controller.document.fileURL
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path())
            let document = ScrollDocument(fileURL: url)
            _ = await document.open()

            let readOnly = DocumentViewController(document: document, environment: environment)
            readOnly.loadViewIfNeeded()
            readOnly.toggleLock()

            #expect(readOnly.markdownView.mode == .editorLocked)
            #expect(menuTitles(readOnly) == ["Find", "Export", "Settings"])
        }

        @Test(arguments: [
            ("https://example.com", "https://example.com"),
            ("mailto:a@example.com", "mailto:a@example.com")
        ])
        func `a web or mail link opens outside`(destination: String, opened url: String) async throws {
            let controller = try await screen()

            controller.open(Self.link(destination, controller))

            #expect(opened == [URL(string: url)])
        }

        @Test(.timeLimit(.minutes(1)))
        func `a sibling file opens in the app; a missing one shows a note`() async throws {
            let controller = try await screen()
            try Data("b".utf8).write(to: folder.appending(path: "b.md"))

            controller.open(Self.link("b.md", controller))
            while opened.isEmpty {
                try await Task.sleep(for: .milliseconds(10))
            }
            await controller.openSibling(folder.appending(path: "gone.md"))

            #expect(opened.map(\.lastPathComponent) == ["b.md"])
            let alert = try #require(presented.first as? UIAlertController)
            #expect(alert.title == "“gone.md” isn’t in this folder.")
        }

        @Test(arguments: [false, true])
        func `a sibling file in a folder it cannot read asks for the folder first`(grant: Bool) async throws {
            let controller = try await screen()
            try Data("b".utf8).write(to: folder.appending(path: "b.md"))
            let access = FakeAccess()
            access.readable = []
            access.grantOnRequest = grant
            environment.access = access
            let blocked = DocumentViewController(document: controller.document, environment: environment)

            await blocked.openSibling(folder.appending(path: "b.md"))

            #expect(access.requested.map(\.standardizedFileURL) == [folder.standardizedFileURL])
            #expect(opened.map(\.lastPathComponent) == (grant ? ["b.md"] : []))
        }

        @Test
        func `a fragment link moves to its heading; any other link does nothing`() async throws {
            let controller = try await screen("# A\n\ntext\n\n## Far\n")

            controller.open(Self.link("#far", controller))
            controller.open(Self.link("ftp://x", controller))

            #expect(controller.markdownView.anchor.block == 11)
            #expect(opened.isEmpty)
        }

        @Test
        func `the image methods reach the document images`() async throws {
            let controller = try await screen()
            let request = ImageRequest(destination: "x.png", documentURL: nil, maxPixelSize: .zero)

            #expect(await controller.image(for: request) == .refused(reason: DocumentImages.saveToShow))
            controller.activateImage(ImageActivation(destination: "x.png", documentURL: nil, card: .loading))
            controller.reloadImage(request)
            controller.loadAllImages()
        }

        static func link(_ destination: String, _ controller: DocumentViewController) -> LinkActivation {
            LinkActivation(
                destination: destination,
                resolvedURL: nil,
                documentURL: controller.document.fileURL,
                modifiers: [],
                source: .markdown
            )
        }
    }
#endif
