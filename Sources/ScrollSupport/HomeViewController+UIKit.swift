#if os(iOS)
    import MarkdownViews
    import UIKit
    import UniformTypeIdentifiers

    /// The iPhone home screen, `Open Files` (design log 002 › iPhone home
    /// screen): the open files, then the recent ones, with search.
    @MainActor
    final class HomeViewController: UITableViewController, UISearchResultsUpdating, UIDocumentPickerDelegate {
        private enum Section {
            case open
            case recent
        }

        let session: DocumentSession
        private var query = ""
        private var sections: [(Section, [FileLists.Entry])] = []
        /// The missing Recent file that Find File… points again.
        private var finding: URL?

        init(session: DocumentSession) {
            self.session = session
            super.init(style: .insetGrouped)
            title = ScrollStrings.openFiles
            navigationItem.backButtonTitle = ScrollStrings.openFiles
            navigationItem.largeTitleDisplayMode = .always
            let search = UISearchController()
            search.searchResultsUpdater = self
            search.obscuresBackgroundDuringPresentation = false
            navigationItem.searchController = search
            toolbarItems = [
                UIBarButtonItem(title: ScrollStrings.browse, primaryAction: UIAction { [weak self] _ in
                    self?.browse()
                }),
                .flexibleSpace(),
                UIBarButtonItem(title: ScrollStrings.newFile, primaryAction: UIAction { [weak self] _ in
                    Task { await self?.newFile() }
                })
            ]
            session.alertHost = self
            session.store.onChange = { [weak self] in self?.reload() }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "file")
            reload()
        }

        private func reload() {
            let lists = session.store.lists.matching(query)
            sections = [(Section.open, lists.open), (.recent, lists.recent)].filter { !$0.1.isEmpty }
            tableView.backgroundView = sections.isEmpty ? emptyView() : nil
            tableView.reloadData()
        }

        /// No files at all, with Browse below; or a search with no match.
        private func emptyView() -> UIStackView {
            let label = UILabel()
            label.text = query.isEmpty ? ScrollStrings.homeEmpty : ScrollStrings.noMatch(query)
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 0
            let stack = UIStackView(arrangedSubviews: [label])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 12
            stack.isLayoutMarginsRelativeArrangement = true
            stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 48, leading: 32, bottom: 0, trailing: 32)
            if query.isEmpty {
                var browse = UIButton.Configuration.plain()
                browse.title = ScrollStrings.browse
                stack.addArrangedSubview(UIButton(configuration: browse, primaryAction: UIAction { [weak self] _ in
                    self?.browse()
                }))
            }
            // The table stretches its background view: the spacer keeps the text at the top.
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            for view in stack.arrangedSubviews {
                view.setContentHuggingPriority(.required, for: .vertical)
            }
            stack.addArrangedSubview(spacer)
            return stack
        }

        func updateSearchResults(for search: UISearchController) {
            // UISearchBar reads "" when its text is set to nil.
            guard let text = search.searchBar.text else { return }
            query = text
            reload()
        }

        // MARK: rows

        override func numberOfSections(in _: UITableView) -> Int {
            sections.count
        }

        override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
            sections[section].1.count
        }

        override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
            sections[section].0 == .open ? ScrollStrings.openSection : ScrollStrings.recent
        }

        override func tableView(_ tableView: UITableView, cellForRowAt path: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "file", for: path)
            let url = sections[path.section].1[path.row].url
            var content = UIListContentConfiguration.subtitleCell()
            content.text = url.lastPathComponent
            content.secondaryTextProperties.numberOfLines = 0
            if session.store.missing.contains(url) {
                content.secondaryText = ScrollStrings.missingNote
                content.textProperties.color = .secondaryLabel
                cell.accessibilityLabel = ScrollStrings.missingLabel(url.lastPathComponent)
            } else {
                let opened = sections[path.section].1[path.row].lastOpened
                content.secondaryText = url.deletingLastPathComponent().lastPathComponent + "\n"
                    + Self.timeFormat.string(from: opened)
                cell.accessibilityLabel = nil
            }
            cell.contentConfiguration = content
            let action = rowAction(path)
            cell.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: action.title) { _ in
                    action.run()
                    return true
                }
            ]
            return cell
        }

        /// `Today at 9:15`.
        private static let timeFormat: DateFormatter = {
            let format = DateFormatter()
            format.dateStyle = .medium
            format.timeStyle = .short
            format.doesRelativeDateFormatting = true
            return format
        }()

        /// Close on Open rows, Remove from Recent on Recent rows; neither deletes the file.
        /// The action keeps its file: the rows may change before it runs.
        private func rowAction(_ path: IndexPath) -> (title: String, run: () -> Void) {
            let url = sections[path.section].1[path.row].url
            let session = session
            switch sections[path.section].0 {
            case .open:
                return (ScrollStrings.close, { Task { await session.close(url) } })
            case .recent:
                return (ScrollStrings.removeRecent, { session.store.removeRecent(url) })
            }
        }

        override func tableView(
            _: UITableView,
            trailingSwipeActionsConfigurationForRowAt path: IndexPath
        ) -> UISwipeActionsConfiguration? {
            let action = rowAction(path)
            return UISwipeActionsConfiguration(actions: [
                UIContextualAction(style: .normal, title: action.title) { _, _, done in
                    action.run()
                    done(true)
                }
            ])
        }

        override func tableView(
            _: UITableView,
            contextMenuConfigurationForRowAt path: IndexPath,
            point _: CGPoint
        ) -> UIContextMenuConfiguration? {
            UIContextMenuConfiguration(actionProvider: { [weak self] _ in self?.menu(for: path) })
        }

        func menu(for path: IndexPath) -> UIMenu {
            let action = rowAction(path)
            return UIMenu(children: [UIAction(title: action.title) { _ in action.run() }])
        }

        override func tableView(_ tableView: UITableView, didSelectRowAt path: IndexPath) {
            tableView.deselectRow(at: path, animated: true)
            Task { await select(path) }
        }

        func select(_ path: IndexPath) async {
            let url = sections[path.section].1[path.row].url
            guard !session.store.missing.contains(url) else {
                showMissing(url, at: path)
                return
            }
            await show(url)
        }

        private func showMissing(_ url: URL, at path: IndexPath) {
            let sheet = UIAlertController(
                title: ScrollStrings.cannotFind(url.lastPathComponent), message: nil, preferredStyle: .actionSheet
            )
            sheet.addAction(UIAlertAction(title: ScrollStrings.findFile, style: .default) { [weak self] _ in
                self?.find(url)
            })
            sheet.addAction(UIAlertAction(title: ScrollStrings.removeRecent, style: .destructive) { [weak self] _ in
                self?.session.store.removeRecent(url)
            })
            sheet.addAction(UIAlertAction(title: ScrollStrings.cancel, style: .cancel))
            sheet.popoverPresentationController?.sourceView = tableView.cellForRow(at: path) ?? tableView
            session.environment.present(sheet, self)
        }

        // MARK: Browse, Find File…, New File

        func browse() {
            finding = nil
            presentPicker()
        }

        func find(_ url: URL) {
            finding = url
            presentPicker()
        }

        private func presentPicker() {
            let types = [UTType("net.daringfireball.markdown"), .plainText].compactMap(\.self)
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
            picker.delegate = self
            session.environment.present(picker, self)
        }

        func documentPicker(_ picker: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            Task { await picked(url, by: picker) }
        }

        /// Find File… keeps the row's place; Browse opens the file.
        func picked(_ url: URL, by _: UIDocumentPickerViewController) async {
            if let finding {
                session.store.found(finding, at: url)
                return
            }
            await show(url)
        }

        /// A file from Browse, a sibling link, or the Files app.
        func show(_ url: URL) async {
            guard let screen = await session.open(url) else { return }
            if navigationController?.topViewController !== screen {
                navigationController?.popToRootViewController(animated: false)
                navigationController?.pushViewController(screen, animated: true)
            }
        }

        /// Close on the deleted strip: back to the list when the file shows.
        func close(_ url: URL) async {
            if let screen = session.screen(for: url), navigationController?.topViewController === screen {
                navigationController?.popToRootViewController(animated: false)
            }
            await session.close(url)
        }

        /// `Untitled.md` in the app's folder, with the keyboard up (log 004, Round 4).
        func newFile() async {
            guard let screen = await session.newFile() else { return }
            screen.startsTyping = true
            navigationController?.pushViewController(screen, animated: true)
        }
    }
#endif
