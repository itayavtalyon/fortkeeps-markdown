#if os(iOS)
    import UIKit

    /// Settings on iOS (screens §3.17; log 004 Round 6): a sheet from the ⋯
    /// menu. Each change is kept at once, and every screen follows. The word
    /// count is the Mac status bar's, so it is not here.
    @MainActor
    final class SettingsViewController: UITableViewController {
        private enum Section: Int {
            case lineWidth
            case folders
            case cache
        }

        let settings: ScrollSettings
        let bookmarks: FolderBookmarks?
        let cache: ImageCache
        /// VoiceOver says that the cache is cleared.
        var announce: (String) -> Void = { UIAccessibility.post(notification: .announcement, argument: $0) }

        init(settings: ScrollSettings, bookmarks: FolderBookmarks?, cache: ImageCache) {
            self.settings = settings
            self.bookmarks = bookmarks
            self.cache = cache
            super.init(style: .insetGrouped)
            title = ScrollStrings.settings
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                systemItem: .done,
                primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
            )
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private var folders: [URL] {
            bookmarks?.folders ?? []
        }

        override func numberOfSections(in _: UITableView) -> Int {
            3
        }

        override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch Section(rawValue: section) {
            case .lineWidth: ScrollSettings.LineWidth.allCases.count
            case .folders: max(folders.count, 1)
            default: 1
            }
        }

        override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch Section(rawValue: section) {
            case .lineWidth: ScrollStrings.lineWidth
            case .folders: ScrollStrings.foldersTitle
            default: nil
            }
        }

        override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
            section == Section.cache.rawValue ? ScrollStrings.imageCacheNote : nil
        }

        override func tableView(_: UITableView, cellForRowAt path: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell()
            var content = UIListContentConfiguration.cell()
            switch Section(rawValue: path.section) {
            case .lineWidth:
                let width = ScrollSettings.LineWidth.allCases[path.row]
                content.text = width.title
                cell.accessoryType = width == settings.lineWidth ? .checkmark : .none
            case .folders where folders.isEmpty:
                content.text = ScrollStrings.noFolders
                content.textProperties.color = .secondaryLabel
            case .folders:
                let folder = folders[path.row]
                content.text = folder.path(percentEncoded: false)
                content.textProperties.lineBreakMode = .byTruncatingHead
                let remove = UIButton(configuration: .plain(), primaryAction: UIAction { [weak self] _ in
                    self?.bookmarks?.remove(folder)
                    self?.tableView.reloadData()
                })
                remove.configuration?.title = ScrollStrings.removeFolder
                remove.sizeToFit()
                cell.accessoryView = remove
            default:
                let size = cache.size()
                content.text = ScrollStrings.clearImageCache(bytes: size)
                content.textProperties.color = size > 0 ? .tintColor : .secondaryLabel
            }
            cell.contentConfiguration = content
            return cell
        }

        /// Only a width and a full cache can be chosen; a folder has its Remove button.
        override func tableView(_: UITableView, shouldHighlightRowAt path: IndexPath) -> Bool {
            switch Section(rawValue: path.section) {
            case .lineWidth: true
            case .folders: false
            default: cache.size() > 0
            }
        }

        /// The cache can be made again, so it clears with no question.
        override func tableView(_ tableView: UITableView, didSelectRowAt path: IndexPath) {
            tableView.deselectRow(at: path, animated: true)
            if path.section == Section.lineWidth.rawValue {
                settings.lineWidth = ScrollSettings.LineWidth.allCases[path.row]
            } else {
                cache.clear()
                announce(ScrollStrings.imageCacheCleared)
            }
            tableView.reloadData()
        }
    }
#endif
