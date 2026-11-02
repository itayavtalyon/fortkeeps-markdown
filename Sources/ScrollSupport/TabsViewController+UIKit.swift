#if os(iOS)
    import MarkdownViews
    import UIKit
    import UniformTypeIdentifiers

    /// The iPad documents (screens §3.19): a tab strip under the nav bar and
    /// the selected document below it.
    @MainActor
    final class TabsViewController: UIViewController {
        let session: DocumentSession
        let strip = UIStackView()
        private let content = UIView()
        private(set) var tabs: [DocumentViewController] = []
        private(set) var selected: DocumentViewController?
        /// Browse, or the last tab closed: back to the document browser.
        var showBrowser: (() -> Void)?

        init(session: DocumentSession) {
            self.session = session
            super.init(nibName: nil, bundle: nil)
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: ScrollStrings.browse,
                primaryAction: UIAction { [weak self] _ in self?.showBrowser?() }
            )
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func loadView() {
            view = UIView()
            view.backgroundColor = .systemBackground
            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            strip.spacing = 4
            for subview in [scroll, strip, content] {
                subview.translatesAutoresizingMaskIntoConstraints = false
            }
            scroll.addSubview(strip)
            view.addSubview(scroll)
            view.addSubview(content)
            let guide = view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: guide.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                scroll.heightAnchor.constraint(equalTo: strip.heightAnchor),
                strip.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                strip.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                strip.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
                strip.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
                content.topAnchor.constraint(equalTo: scroll.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        /// A file already in a tab selects that tab.
        func open(_ url: URL) async {
            guard let screen = await session.open(url) else { return }
            if !tabs.contains(where: { $0 === screen }) {
                tabs.append(screen)
                let tab = TabView(screen: screen, tabs: self)
                strip.addArrangedSubview(tab)
                // A rename (screens §3.12) renames the tab; the bar shows the selected one.
                screen.onUpdate = { [weak self, weak tab] in
                    tab?.showName()
                    self?.showTitle()
                }
            }
            select(screen)
        }

        func select(_ screen: DocumentViewController?) {
            selected?.willMove(toParent: nil)
            selected?.view.removeFromSuperview()
            selected?.removeFromParent()
            selected = screen
            if let screen {
                addChild(screen)
                screen.view.frame = content.bounds
                screen.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                content.addSubview(screen.view)
                screen.didMove(toParent: self)
            }
            showTitle()
            for case let tab as TabView in strip.arrangedSubviews {
                tab.isSelected = tab.screen === screen
            }
        }

        /// The bar shows the selected document's title block and ⋯ menu.
        private func showTitle() {
            navigationItem.title = selected?.title
            navigationItem.showStatus(selected?.statusText)
            navigationItem.rightBarButtonItem = selected?.navigationItem.rightBarButtonItem
        }

        func close(at index: Int) async {
            let screen = tabs.remove(at: index)
            strip.arrangedSubviews[index].removeFromSuperview()
            if screen === selected {
                select(tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)])
            }
            if tabs.isEmpty {
                showBrowser?()
            }
            await session.close(screen.document.fileURL)
        }

        /// Close on the deleted strip closes the file's tab.
        func close(_ url: URL) async {
            let screen = session.screen(for: url)
            guard let index = tabs.firstIndex(where: { $0 === screen }) else { return }
            await close(at: index)
        }

        // MARK: shortcuts (log 001 › Windows and chrome)

        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(
                    title: ScrollStrings.closeTabCommand, action: #selector(closeTab), input: "w",
                    modifierFlags: .command
                ),
                UIKeyCommand(
                    title: ScrollStrings.previousTab, action: #selector(previousTab), input: "[",
                    modifierFlags: [.command, .shift]
                ),
                UIKeyCommand(
                    title: ScrollStrings.nextTab, action: #selector(nextTab), input: "]",
                    modifierFlags: [.command, .shift]
                )
            ] + (1 ... 9).map { number in
                UIKeyCommand(
                    title: tabs.indices.contains(number - 1) ? tabs[number - 1].document.fileName : "",
                    action: #selector(selectTab),
                    input: String(number),
                    modifierFlags: .command
                )
            }
        }

        @objc func closeTab() {
            guard let index = tabs.firstIndex(where: { $0 === selected }) else { return }
            Task { await close(at: index) }
        }

        @objc func previousTab() {
            step(-1)
        }

        @objc func nextTab() {
            step(1)
        }

        private func step(_ offset: Int) {
            guard let index = tabs.firstIndex(where: { $0 === selected }) else { return }
            select(tabs[(index + offset + tabs.count) % tabs.count])
        }

        /// Command-1 to Command-9: the tab of that number.
        @objc func selectTab(_ command: UIKeyCommand) {
            guard let index = command.input.flatMap(Int.init).map({ $0 - 1 }), tabs.indices.contains(index)
            else { return }
            select(tabs[index])
        }
    }

    /// One tab: the file name and a close control labelled "Close {name}".
    @MainActor
    final class TabView: UIStackView {
        let screen: DocumentViewController
        let nameButton: UIButton
        let closeButton: UIButton

        var isSelected = false {
            didSet {
                nameButton.configuration?.baseForegroundColor = isSelected ? .label : .secondaryLabel
                nameButton.accessibilityTraits = isSelected ? [.button, .selected] : .button
            }
        }

        init(screen: DocumentViewController, tabs: TabsViewController) {
            self.screen = screen
            nameButton = UIButton(configuration: .plain(), primaryAction: UIAction { [weak tabs, weak screen] _ in
                tabs?.select(screen)
            })
            var close = UIButton.Configuration.plain()
            close.image = UIImage(systemName: "xmark")
            closeButton = UIButton(configuration: close, primaryAction: UIAction { [weak tabs, weak screen] _ in
                guard let tabs, let index = tabs.tabs.firstIndex(where: { $0 === screen }) else { return }
                Task { await tabs.close(at: index) }
            })
            super.init(frame: .zero)
            showName()
            addArrangedSubview(nameButton)
            addArrangedSubview(closeButton)
            NSLayoutConstraint.activate([
                closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
                heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
        }

        @available(*, unavailable)
        required init(coder _: NSCoder) {
            fatalError("unused") // coverage:ignore - never made from a nib
        }

        func showName() {
            let name = screen.document.fileName
            nameButton.configuration?.title = name
            closeButton.accessibilityLabel = ScrollStrings.closeTab(name)
        }
    }

    /// The iPad launch screen: the system document browser (log 001 ›
    /// Windows and chrome). It shows the tabs over itself.
    @MainActor
    final class BrowserViewController: UIDocumentBrowserViewController {
        let session: DocumentSession
        let tabs: TabsViewController
        private var showsTabs = false

        init(session: DocumentSession) {
            self.session = session
            tabs = TabsViewController(session: session)
            super.init(forOpening: [UTType("net.daringfireball.markdown"), .plainText].compactMap(\.self))
            delegate = self
            allowsDocumentCreation = true
            allowsPickingMultipleItems = true
            session.alertHost = self
            tabs.showBrowser = { [weak self] in
                guard let self else { return }
                showsTabs = false
                session.alertHost = self
                dismiss(animated: true)
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        func open(_ urls: [URL], typing: Bool) async {
            for url in urls {
                await tabs.open(url)
            }
            tabs.selected?.startsTyping = typing
            guard tabs.selected != nil, !showsTabs else { return }
            showsTabs = true
            session.alertHost = tabs
            let shown = UINavigationController(rootViewController: tabs)
            shown.modalPresentationStyle = .fullScreen
            session.environment.present(shown, self)
        }
    }

    extension BrowserViewController: @preconcurrency UIDocumentBrowserViewControllerDelegate {
        func documentBrowser(_: UIDocumentBrowserViewController, didPickDocumentsAt urls: [URL]) {
            Task { await open(urls, typing: false) }
        }

        /// New: an empty `Untitled.md` that the browser moves into its current folder.
        func documentBrowser(
            _: UIDocumentBrowserViewController,
            didRequestDocumentCreationWithHandler handler: @escaping (URL?, ImportMode) -> Void
        ) {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let url = folder.appending(path: DocumentFile.untitledName(taken: []))
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data().write(to: url)
                handler(url, .move)
            } catch {
                handler(nil, .none) // coverage:ignore - the app's temporary folder is always writable
            }
        }

        func documentBrowser(
            _: UIDocumentBrowserViewController,
            didImportDocumentAt _: URL,
            toDestinationURL destination: URL
        ) {
            Task { await open([destination], typing: true) }
        }

        func documentBrowser(
            _: UIDocumentBrowserViewController,
            failedToImportDocumentAt url: URL,
            error: (any Error)?
        ) {
            session.refuse(url, error?.localizedDescription)
        }
    }
#endif
