import Foundation
import MarkdownViews
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// What the window or screen shows about another app's change (design log
/// 004 › Outside changes, Round 7).
@MainActor
struct OutsideChange {
    /// The disk text the dialog or the compare view is about.
    var disk: String?
    /// Another app wrote bytes that are not text: the strip is up and saves pause.
    var isUnreadable = false
    var showsNote = false
    var noteDuration = Duration.seconds(4)
    var noteTask: Task<Void, Never>?
    /// Keep My Changes: the next save is the kept one (Mac: until it starts).
    var keepsMine = false
    /// The status says the save went over the other version.
    var keptMine = false
    /// The compare view, in place of the text.
    var resolveView: ResolveView?
    #if os(macOS)
        var isPointerOver: (NSView) -> Bool = { view in
            guard let window = view.window else { return false }
            return view.bounds.contains(view.convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }
    #else
        /// The iPad pointer is over the note: it stays.
        var isPointerOver = false
        var compare: UIViewController?
    #endif
}

/// The outside-change flow of both apps. Each app supplies its document,
/// its dialog, its compare screen, and how the note leaves.
@MainActor
protocol OutsideChangeHost: AnyObject {
    var markdownView: MarkdownView { get }
    var outside: OutsideChange { get set }
    /// The document has edits that no save has written yet.
    var hasUnsavedEdits: Bool { get }
    /// Saves pause while the dialog, the compare view, or the unreadable strip is up.
    func pauseSaves(_ paused: Bool)
    /// Use Version on Disk: the document matches the disk again.
    func markClean()
    /// Keep My Changes over unreadable bytes: the next save writes the text.
    func markEdited()
    func noteKeptMine()
    func askAboutOutsideChange()
    func announce(_ text: String)
    func isPointerOverNote() -> Bool
    /// The note fades, unless Reduce Motion is on.
    func fadeNote() async
    func update()
}

extension OutsideChangeHost {
    /// No unsaved edits: an undoable reload and the note. Unsaved edits: the
    /// dialog, with the text paused. Bytes that are not text: the strip.
    func outsideChange(_ change: DiskWatch.Change) {
        switch change {
        case .unreadable:
            // ponytail: a dialog already up keeps its disk text; the strip waits for the next change.
            guard outside.disk == nil else { return }
            outside.isUnreadable = true
            pause()
            update()
        case let .text(disk):
            if outside.isUnreadable {
                outside.isUnreadable = false
                resume()
            }
            guard hasUnsavedEdits else {
                reloadQuietly(disk)
                return
            }
            let asking = outside.disk != nil
            // ponytail: a second change while asking updates the disk text; the changed-again banner waits (Round 5).
            outside.disk = disk
            if !asking {
                pause()
                askAboutOutsideChange()
            }
        }
    }

    private func pause() {
        markdownView.isEditable = false
        pauseSaves(true)
    }

    private func resume() {
        markdownView.isEditable = true
        pauseSaves(false)
    }

    private func reloadQuietly(_ disk: String) {
        markdownView.reload(text: disk, undoActionName: ScrollStrings.reloadAction)
        outside.showsNote = true
        update()
        announce(ScrollStrings.reloadNote)
        outside.noteTask?.cancel()
        outside.noteTask = Task { [weak self] in await self?.hideNoteLater() }
    }

    /// The note stays while the pointer is over it, then fades.
    private func hideNoteLater() async {
        var waits = true
        while waits {
            try? await Task.sleep(for: outside.noteDuration)
            waits = !Task.isCancelled && isPointerOverNote()
        }
        guard !Task.isCancelled else { return } // coverage:ignore - a newer note replaced this one
        await fadeNote()
        outside.showsNote = false
        update()
    }

    func endOutsideChange() {
        outside.disk = nil
        resume()
    }

    /// Plan 01's `reload(text:)`: the disk text, and Undo cleared.
    func useDisk() {
        guard let disk = outside.disk else { return } // coverage:ignore - the dialog is up only with a disk text
        endOutsideChange()
        markdownView.reload(text: disk)
        markClean()
        update()
    }

    /// The document keeps its unsaved changes, so the next autosave writes the local text.
    func keepMine() {
        endOutsideChange()
        noteKeptMine()
        update()
    }

    /// The unreadable strip's Keep My Changes: the text goes back to disk.
    func keepMineOverUnreadable() {
        outside.isUnreadable = false
        resume()
        markEdited()
        noteKeptMine()
        update()
    }

    /// One undo group with reason `edit`; autosave writes it once.
    func applyResolved(_ merged: String) {
        endOutsideChange()
        markdownView.replaceText(merged, undoActionName: ScrollStrings.resolveAction)
    }
}
