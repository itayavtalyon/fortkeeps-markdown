#if os(macOS)
    import AppKit

    /// Settings (screens §3.17; log 004 Round 6): one pane, 420 pt wide. Each
    /// change is kept at once, and every window follows.
    @MainActor
    final class SettingsWindowController: NSWindowController {
        let settings: ScrollSettings
        let bookmarks: FolderBookmarks
        let cache: ImageCache
        let lineWidth = NSPopUpButton()
        let wordCount = NSButton(checkboxWithTitle: ScrollStrings.showWordCount, target: nil, action: nil)
        /// One row per folder with access, or the empty line.
        let folders = NSStackView()
        let clearCache = NSButton(title: "", target: nil, action: nil)
        /// VoiceOver says that the cache is cleared.
        var announce: (String) -> Void = { text in
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                .announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue
            ])
        }

        init(settings: ScrollSettings, bookmarks: FolderBookmarks, cache: ImageCache) {
            self.settings = settings
            self.bookmarks = bookmarks
            self.cache = cache
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 420, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: true
            )
            window.title = ScrollStrings.settings
            super.init(window: window)
            lineWidth.addItems(withTitles: ScrollSettings.LineWidth.allCases.map(\.title))
            lineWidth.selectItem(withTitle: settings.lineWidth.title)
            lineWidth.target = self
            lineWidth.action = #selector(chooseLineWidth)
            wordCount.state = settings.showsWordCount ? .on : .off
            wordCount.target = self
            wordCount.action = #selector(toggleWordCount)
            clearCache.target = self
            clearCache.action = #selector(clearImageCache)
            layOut(window)
            showFolders()
            showCacheSize()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private func layOut(_ window: NSWindow) {
            let note = NSTextField(wrappingLabelWithString: ScrollStrings.imageCacheNote)
            note.textColor = .secondaryLabelColor
            note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            folders.orientation = .vertical
            folders.alignment = .leading
            let stack = NSStackView(views: [
                NSStackView(views: [NSTextField(labelWithString: ScrollStrings.lineWidth), lineWidth]),
                wordCount,
                NSTextField(labelWithString: ScrollStrings.foldersTitle),
                folders,
                clearCache,
                note
            ])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            note.widthAnchor.constraint(equalToConstant: 380).isActive = true
            window.contentView = stack
            window.setContentSize(CGSize(width: 420, height: stack.fittingSize.height))
        }

        private func showFolders() {
            let rows = bookmarks.folders.map { folder in
                let remove = NSButton(title: ScrollStrings.removeFolder, target: self, action: #selector(removeFolder))
                remove.identifier = NSUserInterfaceItemIdentifier(folder.path(percentEncoded: false))
                let path = (folder.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
                return NSStackView(views: [NSTextField(labelWithString: path), remove])
            }
            folders.setViews(rows.isEmpty ? [NSTextField(labelWithString: ScrollStrings.noFolders)] : rows, in: .top)
        }

        private func showCacheSize() {
            let size = cache.size()
            clearCache.title = ScrollStrings.clearImageCache(bytes: size)
            clearCache.isEnabled = size > 0
        }

        @objc private func chooseLineWidth() {
            settings.lineWidth = ScrollSettings.LineWidth.allCases[lineWidth.indexOfSelectedItem]
        }

        @objc private func toggleWordCount() {
            settings.showsWordCount = wordCount.state == .on
        }

        @objc private func removeFolder(_ sender: NSButton) {
            guard let folder = bookmarks.folders.first(where: {
                $0.path(percentEncoded: false) == sender.identifier?.rawValue
            }) else { return } // coverage:ignore - each button names a folder in the list
            bookmarks.remove(folder)
            showFolders()
        }

        /// The cache can be made again, so it clears with no question.
        @objc private func clearImageCache() {
            cache.clear()
            showCacheSize()
            announce(ScrollStrings.imageCacheCleared)
        }
    }
#endif
