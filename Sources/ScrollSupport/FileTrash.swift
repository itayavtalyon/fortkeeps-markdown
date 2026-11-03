import Foundation

/// Move to Trash and its Undo for every window (screens §3.5). The Undo
/// outlives the tab of the file it trashed.
@MainActor
enum FileTrash {
    static let undoManager: UndoManager = {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }()

    /// A file was added, renamed, or trashed: every sidebar lists its folder again.
    static let folderDidChange = Notification.Name("ScrollFolderDidChange")

    /// `close` readies an open document of the file and gives what closes it
    /// after the move, or nil when the file is not open. iOS gives the app's
    /// own Trash folder.
    static func trash(
        _ url: URL,
        into folder: URL? = nil,
        close: @escaping (URL) throws -> (() -> Void)?,
        openFile: @escaping (URL) -> Void,
        beep: @escaping () -> Void
    ) {
        do {
            let closeOpen = try close(url)
            let trashed = try FolderFiles.trash(url, into: folder)
            closeOpen?()
            undoManager.beginUndoGrouping()
            undoManager.registerUndo(withTarget: undoManager) { _ in
                restore(trashed, to: url, reopen: closeOpen.map { _ in { openFile(url) } }, beep: beep) {
                    trash(url, into: folder, close: close, openFile: openFile, beep: beep)
                }
            }
            undoManager.setActionName(ScrollStrings.moveToTrash)
            undoManager.endUndoGrouping()
        } catch {
            beep()
        }
        NotificationCenter.default.post(name: folderDidChange, object: nil)
    }

    /// A file that took the name since, or a Trash emptied since, leaves the
    /// file where it is: a beep, and nothing to redo.
    private static func restore(
        _ trashed: URL, to url: URL, reopen: (() -> Void)?, beep: () -> Void, redo: @escaping () -> Void
    ) {
        do {
            try FolderFiles.restore(trashed, to: url)
        } catch {
            beep()
            return
        }
        reopen?()
        undoManager.registerUndo(withTarget: undoManager) { _ in redo() }
        NotificationCenter.default.post(name: folderDidChange, object: nil)
    }
}
