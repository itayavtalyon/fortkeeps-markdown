#if os(iOS)
    import MarkdownViews
    import UIKit

    /// The sidebar on iOS (screens §3.4, §3.5; log 004 Round 6): the Outline,
    /// then the folder once the app can read it. A sheet from ☰ on iPhone, the
    /// split view's sidebar on iPad.
    @MainActor
    final class SidebarViewController: UICollectionViewController {
        let environment: ScrollEnvironment
        /// Move to Trash closes the file's screen through it.
        weak var session: DocumentSession?
        let outlineSection = SidebarRow(.section(ScrollStrings.outlineTitle), [])
        private(set) var folderSection: SidebarRow?
        /// The subfolders open in the tree, kept across a reload.
        private var expanded: Set<[String]> = []
        /// The folder: the document's, or the one Open Folder chose.
        var folder: URL? {
            didSet { reloadFolder() }
        }

        /// The screen whose Outline shows.
        private(set) weak var screen: DocumentViewController?
        /// A heading or a file was chosen: the iPhone sheet goes.
        var onChoose: (() -> Void)?
        private(set) var renaming: SidebarRow?
        private(set) var renameField: RenameField?
        private(set) lazy var dataSource = makeDataSource()

        init(environment: ScrollEnvironment) {
            self.environment = environment
            var list = UICollectionLayoutListConfiguration(appearance: .sidebar)
            list.headerMode = .firstItemInSection
            super.init(collectionViewLayout: UICollectionViewCompositionalLayout.list(using: list))
            title = ScrollStrings.outlineTitle
            NotificationCenter.default.addObserver(
                self, selector: #selector(reloadFolder), name: FileTrash.folderDidChange, object: nil
            )
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            collectionView.dataSource = dataSource
            applyOutline()
            applyFolder()
        }

        /// The Outline loads only while it shows.
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            screen?.refreshOutline()
        }

        override var undoManager: UndoManager? {
            FileTrash.undoManager
        }

        // MARK: the Outline (screens §3.4)

        /// The screen's Outline, and its folder when the app can read it.
        func show(_ screen: DocumentViewController?) {
            if self.screen !== screen {
                self.screen?.sidebar = nil
            }
            self.screen = screen
            screen?.sidebar = self
            if let screen {
                screen.refreshOutline()
            } else {
                showOutline([])
            }
            let place = screen?.document.fileURL.deletingLastPathComponent()
            if let place, environment.access.canRead(place) {
                folder = place
            }
        }

        func showOutline(_ items: [MarkdownDocument.OutlineItem]) {
            outlineSection.children = SidebarRow.outline(items)
            applyOutline()
        }

        /// The heading at the top of the text, or the one that holds it when it is folded.
        func follow(_ index: Int?) {
            let top = outlineSection.list.last { row in
                guard case let .heading(first, _) = row.kind, let index else { return false }
                return first <= index
            }
            let child = top?.list.last { row in
                guard case let .heading(first, _) = row.kind, let index else { return false }
                return first <= index
            }
            let shown = [child, top].compactMap(\.self).compactMap(dataSource.indexPath(for:)).first
            collectionView.indexPathsForSelectedItems?.filter { $0 != shown }.forEach {
                collectionView.deselectItem(at: $0, animated: false)
            }
            collectionView.selectItem(at: shown, animated: false, scrollPosition: [])
        }

        // MARK: the folder (screens §3.5)

        @objc func reloadFolder() {
            folderSection = folder.map { SidebarRow(.section($0.lastPathComponent), SidebarRow.rows(in: $0)) }
            applyFolder()
        }

        /// The Outline alone, so a folder change keeps its open headings.
        private func applyOutline() {
            guard isViewLoaded else { return }
            var outline = NSDiffableDataSourceSectionSnapshot<SidebarRow>()
            outline.append([outlineSection])
            outline.append(outlineSection.list, to: outlineSection)
            for row in outlineSection.list where !row.list.isEmpty {
                outline.append(row.list, to: row)
            }
            outline.expand([outlineSection])
            dataSource.apply(outline, to: 0, animatingDifferences: false)
        }

        private func applyFolder() {
            guard isViewLoaded else { return }
            guard let folderSection else {
                var sections = dataSource.snapshot()
                sections.deleteSections(sections.sectionIdentifiers.filter { $0 == 1 })
                dataSource.apply(sections, animatingDifferences: false)
                return
            }
            var files = NSDiffableDataSourceSectionSnapshot<SidebarRow>()
            files.append([folderSection])
            add(folderSection.list, to: folderSection, &files)
            files.expand([folderSection])
            dataSource.apply(files, to: 1, animatingDifferences: false)
        }

        /// An open subfolder lists its files; a closed one waits to be opened.
        private func add(
            _ rows: [SidebarRow], to parent: SidebarRow, _ files: inout NSDiffableDataSourceSectionSnapshot<SidebarRow>
        ) {
            files.append(rows, to: parent)
            for row in rows where row.isFolder && expanded.contains(SidebarRow.key(row.url)) {
                if row.children == nil, let url = row.url {
                    row.children = SidebarRow.rows(in: url)
                }
                add(row.list, to: row, &files)
                files.expand([row])
            }
        }

        /// The disclosure of a subfolder opens or closes it.
        func toggler(_ row: SidebarRow) -> () -> Void {
            { [weak self] in self?.toggle(row) }
        }

        private func toggle(_ row: SidebarRow) {
            let key = SidebarRow.key(row.url)
            if expanded.remove(key) == nil {
                expanded.insert(key)
            }
            applyFolder()
        }

        private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, SidebarRow> {
            let registration = UICollectionView.CellRegistration<UICollectionViewListCell, SidebarRow> { [weak self] in
                self?.configure($0, $2)
            }
            return UICollectionViewDiffableDataSource(collectionView: collectionView) { view, path, row in
                view.dequeueConfiguredReusableCell(using: registration, for: path, item: row)
            }
        }

        private func configure(_ cell: UICollectionViewListCell, _ row: SidebarRow) {
            var content: UIListContentConfiguration = .cell()
            content.text = row.title
            cell.accessories = []
            switch row.kind {
            case .section:
                content = .header()
                content.text = row.title
                cell.accessories = [.outlineDisclosure()]
            case let .heading(_, heading):
                content.directionalLayoutMargins.leading += CGFloat(max(heading.level - 1, 0) * 12)
                cell.accessories = row.list.isEmpty ? [] : [.outlineDisclosure()]
            case let .entry(entry) where entry.isFolder:
                content.image = UIImage(systemName: "folder")
                cell.accessories = [.outlineDisclosure(options: .init(style: .cell), actionHandler: toggler(row))]
            case .entry:
                content.image = UIImage(systemName: "doc.text")
            case .empty:
                content.textProperties.color = .secondaryLabel
            }
            cell.contentConfiguration = row === renaming ? RenameConfiguration(sidebar: self, name: row.title) : content
        }

        // MARK: choosing

        override func collectionView(_: UICollectionView, shouldSelectItemAt path: IndexPath) -> Bool {
            switch dataSource.itemIdentifier(for: path)?.kind {
            case .heading, .entry: true
            default: false
            }
        }

        /// A heading shows in the text, a file opens, a folder opens or closes.
        override func collectionView(_ view: UICollectionView, didSelectItemAt path: IndexPath) {
            guard let row = dataSource.itemIdentifier(for: path) else { return } // coverage:ignore - a shown row
            switch row.kind {
            case let .heading(_, item):
                screen?.markdownView.showOutlineItem(item)
                onChoose?()
            case let .entry(entry) where entry.isFolder:
                view.deselectItem(at: path, animated: false)
                toggle(row)
            case let .entry(entry):
                onChoose?()
                environment.openFile(entry.url)
            default:
                break // coverage:ignore - only headings and entries can be chosen
            }
        }
    }

    extension DocumentViewController {
        /// The Outline loads only while the sidebar shows (log 004 Round 6): the
        /// text is parsed off the main thread, and a newer change starts again.
        func refreshOutline(after pause: Duration = .zero) {
            outlineTask?.cancel()
            outlineTask = nil
            guard let sidebar, sidebar.viewIfLoaded?.window != nil else { return }
            outlineTask = Task { [weak sidebar] in
                do {
                    try await Task.sleep(for: pause)
                } catch {
                    return
                }
                let outline = await markdownView.loadOutline()
                guard !Task.isCancelled else { return }
                sidebar?.showOutline(outline)
                sidebar?.follow(markdownView.currentOutlineIndex)
            }
        }
    }

    // MARK: New file, Rename, Move to Trash

    extension SidebarViewController {
        override func collectionView(
            _: UICollectionView, contextMenuConfigurationForItemsAt paths: [IndexPath], point _: CGPoint
        ) -> UIContextMenuConfiguration? {
            guard let path = paths.first, let menu = menu(for: path) else { return nil }
            return UIContextMenuConfiguration(actionProvider: { _ in menu })
        }

        /// New file on the folder's rows; Rename and Move to Trash on a file or subfolder.
        func menu(for path: IndexPath) -> UIMenu? {
            guard let row = dataSource.itemIdentifier(for: path),
                  dataSource.snapshot().sectionIdentifier(containingItem: row) == 1 else { return nil }
            var items = [UIAction(title: ScrollStrings.newFile) { [weak self] _ in self?.newFile(at: row) }]
            if let url = row.url {
                items.append(UIAction(title: ScrollStrings.rename) { [weak self] _ in self?.rename(row) })
                items.append(UIAction(title: ScrollStrings.moveToTrash, attributes: .destructive) { [weak self] _ in
                    self?.trash(url)
                })
            }
            return UIMenu(children: items)
        }

        /// In the folder of the row, or the folder itself, or else the top folder.
        private func newFile(at row: SidebarRow) {
            guard var place = folder else { return } // coverage:ignore - the menu needs a folder
            if let url = row.url {
                place = row.isFolder ? url : url.deletingLastPathComponent()
            }
            guard let url = try? FolderFiles.newFile(in: place) else { return }
            expanded.insert(SidebarRow.key(place))
            NotificationCenter.default.post(name: FileTrash.folderDidChange, object: nil)
            let rows = dataSource.snapshot().itemIdentifiers
            guard let new = rows.first(where: { SidebarRow.key($0.url) == SidebarRow.key(url) })
            else { return } // coverage:ignore - the new file is listed
            rename(new)
        }

        /// Inline: Return commits, Escape cancels.
        private func rename(_ row: SidebarRow) {
            renaming = row
            reconfigure(row)
        }

        private func reconfigure(_ row: SidebarRow) {
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems([row])
            dataSource.apply(snapshot, animatingDifferences: false)
        }

        func editing(_ field: RenameField) {
            renameField = field
            _ = field.becomeFirstResponder()
        }

        /// Return or a tap away commits; Escape keeps the old name.
        func endRename(_ name: String?) {
            guard let row = renaming, let url = row.url else { return }
            renaming = nil
            renameField = nil
            reconfigure(row)
            guard let name else { return }
            do {
                _ = try FolderFiles.rename(url, to: name)
                NotificationCenter.default.post(name: FileTrash.folderDidChange, object: nil)
            } catch let FolderFiles.RenameError.nameTaken(taken) {
                let title = ScrollStrings.nameTaken(taken)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: ScrollStrings.ok, style: .default))
                environment.present(alert, self)
            } catch {
                return // an empty name, or one the folder refuses: the old name stays
            }
        }

        /// Into the app's own Trash folder: iOS has no Trash (log 004 Round 6). The
        /// open screen of the file goes, and Undo brings it back.
        private func trash(_ url: URL) {
            FileTrash.trash(
                url,
                into: environment.appFolder.appending(path: "Trash"),
                close: { [weak self] in try self?.session?.closeForTrash($0) },
                openFile: { [environment] in environment.openFile($0) },
                beep: {}
            )
        }
    }

    /// The name field of a row being renamed.
    struct RenameConfiguration: UIContentConfiguration {
        weak var sidebar: SidebarViewController?
        let name: String

        func makeContentView() -> any UIView & UIContentView {
            RenameField(configuration: self)
        }

        func updated(for _: any UIConfigurationState) -> RenameConfiguration {
            self
        }
    }

    final class RenameField: UITextField, UIContentView, UITextFieldDelegate {
        var configuration: any UIContentConfiguration
        private var isDone = false

        init(configuration: RenameConfiguration) {
            self.configuration = configuration
            super.init(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
            text = configuration.name
            borderStyle = .roundedRect
            returnKeyType = .done
            delegate = self
            configuration.sidebar?.editing(self)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: 36)
        }

        override var keyCommands: [UIKeyCommand]? {
            let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancel))
            escape.wantsPriorityOverSystemBehavior = true
            return [escape]
        }

        @objc func cancel() {
            finish(nil)
        }

        func textFieldShouldReturn(_: UITextField) -> Bool {
            finish(text)
            return false
        }

        func textFieldDidEndEditing(_: UITextField) {
            finish(text)
        }

        private func finish(_ name: String?) {
            guard !isDone else { return }
            isDone = true
            (configuration as? RenameConfiguration)?.sidebar?.endRename(name)
        }
    }
#endif
