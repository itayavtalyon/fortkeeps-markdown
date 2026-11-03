#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The document window's sidebar and what a relaunch keeps of it.
    extension DocumentWindowController {
        // MARK: the sidebar (screens §3.4, §3.5)

        /// Open Folder… (log 004 Round 6): the folder shows in the sidebar.
        func showFolder(_ folder: URL) {
            sidebar.folder = folder
            if split.splitViewItems[0].isCollapsed {
                split.toggleSidebar(nil)
            }
        }

        /// View › Outline (⌥⌘O): the sidebar shows, with the focus in it.
        @objc func focusOutline(_: Any?) {
            if split.splitViewItems[0].isCollapsed {
                split.toggleSidebar(nil)
            }
            window?.makeFirstResponder(sidebar.outlineView)
        }

        func showHeading(_ item: MarkdownDocument.OutlineItem) {
            markdownView.showOutlineItem(item)
            window?.makeFirstResponder(markdownView)
        }

        /// The Outline loads only while the sidebar shows (log 004 Round 6): the
        /// text is parsed off the main thread, and a newer change starts again.
        func refreshOutline(after pause: Duration = .zero) {
            outlineTask?.cancel()
            outlineTask = nil
            guard !split.splitViewItems[0].isCollapsed else { return }
            outlineTask = Task {
                do {
                    try await Task.sleep(for: pause)
                } catch {
                    return
                }
                let outline = await markdownView.loadOutline()
                guard !Task.isCancelled else { return }
                sidebar.showOutline(outline)
                sidebar.follow(markdownView.currentOutlineIndex)
            }
        }

        func scrolled() {
            sidebar.follow(markdownView.currentOutlineIndex)
            invalidateRestorableState()
        }

        // MARK: relaunch (screens D10, §3.17; log 004 Round 6)

        /// The place, Lock, and the sidebar; the system keeps them with the window.
        override func encodeRestorableState(with coder: NSCoder) {
            super.encodeRestorableState(with: coder)
            coder.encode(try? JSONEncoder().encode(restoredAnchor ?? markdownView.anchor), forKey: "anchor")
            coder.encode(markdownView.mode == .editorLocked, forKey: "locked")
            coder.encode(!split.splitViewItems[0].isCollapsed, forKey: "showsSidebar")
        }

        /// Lock and the sidebar first: the place is set on the final layout.
        override func restoreState(with coder: NSCoder) {
            super.restoreState(with: coder)
            if coder.containsValue(forKey: "locked") {
                if coder.decodeBool(forKey: "locked") != (markdownView.mode == .editorLocked) {
                    toggleLock(nil)
                }
                split.splitViewItems[0].isCollapsed = !coder.decodeBool(forKey: "showsSidebar")
                refreshOutline()
            }
            window?.layoutIfNeeded()
            guard let data = coder.decodeObject(of: NSData.self, forKey: "anchor") as Data?,
                  let anchor = try? JSONDecoder().decode(MarkdownAnchor.self, from: data)
            else { return }
            // A large file still loading has no text to place it in yet.
            guard largeLoad == nil else {
                restoredAnchor = anchor
                return
            }
            markdownView.anchor = anchor
        }
    }
#endif
