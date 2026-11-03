#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The sidebar's list. Undo and Redo reach Move to Trash.
    final class SidebarOutlineView: NSOutlineView {
        @objc func undo(_: Any?) {
            FileTrash.undoManager.undo()
        }

        @objc func redo(_: Any?) {
            FileTrash.undoManager.redo()
        }

        override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
            switch item.action {
            case #selector(undo):
                (item as? NSMenuItem)?.title = FileTrash.undoManager.undoMenuItemTitle
                return FileTrash.undoManager.canUndo
            case #selector(redo):
                (item as? NSMenuItem)?.title = FileTrash.undoManager.redoMenuItemTitle
                return FileTrash.undoManager.canRedo
            default:
                return super.validateUserInterfaceItem(item)
            }
        }

        /// Return opens the selected file or heading, as a click does.
        override func keyDown(with event: NSEvent) {
            guard event.keyCode == 36, let action else { return super.keyDown(with: event) }
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    /// The window's split: the sidebar, then the text.
    final class SidebarSplitController: NSSplitViewController {
        /// The sidebar was shown or hidden; new windows follow the last choice.
        var onToggle: ((Bool) -> Void)?

        override func toggleSidebar(_ sender: Any?) {
            let shows = splitViewItems[0].isCollapsed
            super.toggleSidebar(sender)
            onToggle?(shows)
        }
    }

    extension FileTrash {
        /// An open document of the file: its unsaved text goes into the file
        /// first, so Undo brings it back, and the window closes after the move.
        static func closeDocument(_ url: URL) throws -> (() -> Void)? {
            guard let document = NSDocumentController.shared.document(for: url) as? ScrollDocument else { return nil }
            if document.isDocumentEdited {
                try document.data(ofType: ScrollDocument.typeName).write(to: url)
            }
            return { document.close() }
        }
    }
#endif
