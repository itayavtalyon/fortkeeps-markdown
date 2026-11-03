#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The sidebar of a document window (screens §3.4, §3.5; log 004 Round 6):
    /// the Outline, then the folder once the app can read it.
    @MainActor
    final class SidebarController: NSViewController {
        let outlineView = SidebarOutlineView()
        let environment: ScrollEnvironment
        let outlineSection = SidebarRow(.section(ScrollStrings.outlineTitle), [])
        private(set) var folderSection: SidebarRow?
        /// The subfolders open in the tree, kept across a reload.
        private var expanded: Set<[String]> = []
        /// The folder: the document's, or the one Open Folder… chose.
        var folder: URL? {
            didSet { reloadFolder() }
        }

        /// A heading the person chose.
        var onHeading: ((MarkdownDocument.OutlineItem) -> Void)?

        init(environment: ScrollEnvironment) {
            self.environment = environment
            super.init(nibName: nil, bundle: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(folderChanged), name: FileTrash.folderDidChange, object: nil
            )
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func loadView() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
            outlineView.addTableColumn(column)
            outlineView.outlineTableColumn = column
            outlineView.headerView = nil
            outlineView.style = .sourceList
            outlineView.dataSource = self
            outlineView.delegate = self
            outlineView.target = self
            outlineView.action = #selector(choose)
            let menu = NSMenu()
            menu.items = [
                NSMenuItem(title: ScrollStrings.newFile, action: #selector(newFile), keyEquivalent: ""),
                NSMenuItem(title: ScrollStrings.rename, action: #selector(rename), keyEquivalent: ""),
                NSMenuItem(title: ScrollStrings.moveToTrash, action: #selector(moveToTrash), keyEquivalent: "")
            ]
            outlineView.menu = menu
            let scroll = NSScrollView(frame: CGRect(x: 0, y: 0, width: 220, height: 400))
            scroll.documentView = outlineView
            scroll.hasVerticalScroller = true
            view = scroll
            reload()
        }

        // MARK: the Outline (screens §3.4)

        func showOutline(_ items: [MarkdownDocument.OutlineItem]) {
            outlineSection.children = SidebarRow.outline(items)
            outlineView.reloadItem(outlineSection, reloadChildren: true)
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
            let shown = [child, top].compactMap(\.self).map(outlineView.row(forItem:)).first { $0 >= 0 }
            outlineView.selectRowIndexes(shown.map { [$0] } ?? [], byExtendingSelection: false)
        }

        /// A click, or Return: a heading shows in the text, a file opens.
        @objc func choose() {
            let index = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
            guard let row = outlineView.item(atRow: index) as? SidebarRow else { return }
            switch row.kind {
            case let .heading(_, item):
                onHeading?(item)
            case let .entry(entry) where !entry.isFolder:
                environment.openFile(entry.url)
            default:
                break
            }
        }

        // MARK: the folder (screens §3.5)

        func reloadFolder() {
            folderSection = folder.map { SidebarRow(.section($0.lastPathComponent), SidebarRow.rows(in: $0)) }
            reload()
        }

        @objc private func folderChanged() {
            reloadFolder()
        }

        /// The marked heading stays marked: its row outlives a folder change.
        private func reload() {
            let marked = outlineView.item(atRow: outlineView.selectedRow)
            outlineView.reloadData()
            outlineView.expandItem(outlineSection)
            if let folderSection {
                outlineView.expandItem(folderSection)
                expandKept(folderSection.list)
            }
            let row = outlineView.row(forItem: marked)
            if row >= 0 {
                outlineView.selectRowIndexes([row], byExtendingSelection: false)
            }
        }

        private func expandKept(_ rows: [SidebarRow]) {
            for row in rows where row.isFolder && expanded.contains(SidebarRow.key(row.url)) {
                outlineView.expandItem(row)
                expandKept(row.list)
            }
        }

        func row(for url: URL) -> Int? {
            (0 ..< outlineView.numberOfRows).first {
                SidebarRow.key((outlineView.item(atRow: $0) as? SidebarRow)?.url) == SidebarRow.key(url)
            }
        }

        func children(_ item: Any?) -> [SidebarRow] {
            guard let row = item as? SidebarRow else { return [outlineSection] + [folderSection].compactMap(\.self) }
            if row.children == nil, row.isFolder, let url = row.url {
                row.children = SidebarRow.rows(in: url)
            }
            return row.list
        }
    }

    extension SidebarController: NSOutlineViewDataSource, NSOutlineViewDelegate {
        func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            children(item).count
        }

        func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            children(item)[index]
        }

        func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let row = item as? SidebarRow else { return false } // coverage:ignore - every item is a row
            switch row.kind {
            case .section: return true
            case .entry: return row.isFolder
            case .heading: return row.children?.isEmpty == false
            case .empty: return false
            }
        }

        func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
            if case .section = (item as? SidebarRow)?.kind {
                true
            } else {
                false
            }
        }

        func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            switch (item as? SidebarRow)?.kind {
            case .heading, .entry: true
            default: false
            }
        }

        func outlineView(_: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
            guard let row = item as? SidebarRow else { return nil } // coverage:ignore - every item is a row
            let cell = NSTableCellView()
            let field = NSTextField(labelWithString: row.title)
            field.lineBreakMode = .byTruncatingTail
            field.delegate = self
            if case .empty = row.kind {
                field.textColor = .secondaryLabelColor
            }
            cell.textField = field
            cell.addSubview(field)
            field.translatesAutoresizingMaskIntoConstraints = false
            var indent: CGFloat = 0
            if case let .heading(_, heading) = row.kind, heading.level <= 3 {
                indent = CGFloat(heading.level - 1) * 12
            }
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: indent + 2),
                field.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            guard let row = notification.userInfo?["NSObject"] as? SidebarRow, row.isFolder else { return }
            expanded.insert(SidebarRow.key(row.url))
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            guard let row = notification.userInfo?["NSObject"] as? SidebarRow
            else { return } // coverage:ignore - as above
            expanded.remove(SidebarRow.key(row.url))
        }
    }

    // MARK: New File, Rename, Move to Trash

    extension SidebarController: NSMenuItemValidation, NSTextFieldDelegate {
        /// The row of the context menu, or else the selected row.
        private var target: SidebarRow? {
            let index = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
            return outlineView.item(atRow: index) as? SidebarRow
        }

        func validateMenuItem(_ item: NSMenuItem) -> Bool {
            switch item.action {
            case #selector(newFile): folder != nil
            default: target?.url != nil
            }
        }

        /// In the selected folder, or the folder of the selected file, or else the top folder.
        @objc func newFile(_: Any?) {
            guard var place = folder else { return } // coverage:ignore - the menu item is off with no folder
            if let row = target, let url = row.url {
                place = row.isFolder ? url : url.deletingLastPathComponent()
            }
            do {
                let url = try FolderFiles.newFile(in: place)
                expanded.insert(SidebarRow.key(place))
                NotificationCenter.default.post(name: FileTrash.folderDidChange, object: nil)
                guard let index = row(for: url) else { return } // coverage:ignore - the new file is listed
                outlineView.selectRowIndexes([index], byExtendingSelection: false)
                rename(nil)
            } catch {
                environment.beep()
            }
        }

        /// Inline: Return commits, Esc cancels.
        @objc func rename(_: Any?) {
            guard let row = target, row.url != nil else { return } // coverage:ignore - the menu item needs a file
            let index = outlineView.row(forItem: row)
            outlineView.selectRowIndexes([index], byExtendingSelection: false)
            let cell = outlineView.view(atColumn: 0, row: index, makeIfNecessary: true) as? NSTableCellView
            guard let field = cell?.textField else { return } // coverage:ignore - every row has its field
            field.isEditable = true
            view.window?.makeFirstResponder(field)
        }

        func control(_ control: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(cancelOperation), let field = control as? NSTextField else { return false }
            field.abortEditing()
            field.isEditable = false
            if let row = target {
                field.stringValue = row.title
            }
            view.window?.makeFirstResponder(outlineView)
            return true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField, field.isEditable,
                  let row = target, let url = row.url else { return } // coverage:ignore - only a rename edits
            field.isEditable = false
            let name = field.stringValue
            field.stringValue = row.title
            do {
                let renamed = try FolderFiles.rename(url, to: name)
                NotificationCenter.default.post(name: FileTrash.folderDidChange, object: nil)
                if let index = self.row(for: renamed) {
                    outlineView.selectRowIndexes([index], byExtendingSelection: false)
                }
            } catch let FolderFiles.RenameError.nameTaken(taken) {
                let alert = NSAlert()
                alert.messageText = ScrollStrings.nameTaken(taken)
                alert.addButton(withTitle: ScrollStrings.ok)
                environment.presentAlert(alert, view.window) { _ in }
            } catch {
                environment.beep()
            }
        }

        /// ⌘⌫: never a permanent delete; an open tab of the file closes, and Undo reopens it.
        @objc func moveToTrash(_: Any?) {
            guard let url = target?.url else { return } // coverage:ignore - the menu item needs a file
            FileTrash.trash(
                url, close: FileTrash.closeDocument, openFile: environment.openFile, beep: environment.beep
            )
        }
    }
#endif
