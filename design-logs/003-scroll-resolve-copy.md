# 003 — Scroll Resolve copy

**Status:** Design. Reload with a note and distribution decided by Itay 2026-10-29. No open questions.
**Created:** 2026-10-29

Copy for Fortkeeps Scroll's file-conflict and missing-file states. Logs 001 and 002 are not edited.

## Design

### File changed outside Scroll

| Element | Mac | iOS |
|---|---|---|
| Title | `"<name>" changed outside Scroll` | same |
| Body | `Another app edited this file while you had unsaved changes. Choose which version to keep.` | same |
| Buttons | `Use Version on Disk` / `Keep My Changes` / `Compare…` | `Use version on disk` / `Keep my changes` / `Compare` |

- Nothing is selected by default; neither Return nor Esc picks a button.
- After Keep, the status line reads `Saved your changes over the other version.`
- Merge view title: `Compare versions of "<name>"`; columns `On Disk` and `Your Changes`.

### File deleted or moved while open

- Title: `Can't find "<name>"`
- Body: `It may have been moved or deleted. Your text is still here.`
- Buttons: `Save As…` / `Close`
- VoiceOver label: `<name>, can't find this file`

### Stale permission (Story Weaver's copy, approved by Interface)

- Recent row note: `Scroll needs your permission to open this file again.`
- Tapping the row opens a sheet titled `Allow access to "<name>"`, body `Choose the file again so Scroll can open it.`, buttons `Choose File…` / `Remove from Recent` / `Cancel`.
- Folder sidebar: title `Allow access to "<folder>"`, button `Choose Folder…`.
- VoiceOver label: `<name>, needs permission to open`
- The picker opens in the file's last known folder. Mac: set NSOpenPanel's `directoryURL` there and preselect the file where macOS allows it. iOS: set UIDocumentPicker's `directoryURL` to that folder. Preselecting the file is best effort.

### Reload with a note, no unsaved edits (decided by Itay, 2026-10-29)

With no unsaved edits, Scroll reloads a file changed on disk without a dialog and shows a note. The reload keeps the scroll position and caret, and it is undoable (`Undo Reload` on Mac).

- Note text: `Updated with changes from another app.` It appears at the top of the document for about 4 seconds.
- VoiceOver announces it politely, without moving focus.
- It stays while the pointer is over it.
- It has an `Undo` button (the same as Undo Reload).
- With Reduce Motion on, it appears and disappears without the fade.

### Sandbox and distribution

Scroll ships on the Mac App Store and as a direct-download DMG from fortkeeps.com that updates via Sparkle (details in the private Mac updates log). Both builds are sandboxed, so they behave the same. Each keeps security-scoped bookmarks for Recent, relaunch restore and the folder sidebar; when one goes stale, the stale-permission section above applies.

The App Store build leaves out `Check for Updates…` and the automatic-update settings entirely; they are not greyed out. The direct-download build keeps both. That is the only difference between the two builds, implemented with a compile-time flag (for example a `SPARKLE` build setting). (Interface's rule.)

## Known Limitations

### Open questions

| ID | Question | Status |
|---|---|---|
| OQ-1 | Reload without a dialog when the file has no unsaved edits? | **Decided by Itay 2026-10-29:** yes, with the `Updated with changes from another app.` note; see Design. |
| OQ-2 | A direct-download Mac build of Scroll? | **Decided by Itay 2026-10-29:** yes; Mac App Store plus a sandboxed direct-download DMG from fortkeeps.com that updates via Sparkle. |
