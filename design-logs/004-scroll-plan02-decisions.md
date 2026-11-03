# 004 - Fortkeeps Scroll plan 02 decisions

Revision 4, 2026-11-03 (Round 7 added by the plan 02 whole-plan review). Revision 3, 2026-11-01 (Round 3 added for stage 2c). Revision 2, 2026-11-01 (Round 2 added for stage 2b). Revision 1, 2026-10-31. Written by the plan 02 implementer from Itay's answers to the plan 02 grill questions. Status: Design.
Logs 001, 002, and 003 stay as written. This log amends them. Each decision names the section it amends. Where this log and an earlier log differ, this log wins.
Each stage of plan 02 (`implementation-plans/02-apps.md`) adds its answers here as a new round.

## Background

Plan 02 builds the apps on the library of plan 01. Some plan 02 steps need a rule that logs 001 to 003 do not state.

## Problem

Stage 2a must save a checkbox change at once, also when Undo or Redo replays it. `TextChange` does not say which change an undo replays. Design also does not say what later saves write, whether an empty file gets a final newline, or where the save policy lives.

Stage 2b loads images. Logs 001 and 002 differ on the card of an SVG, on which failed cards show Try Again, and on how a failed reload reaches the view. They do not say where the app's image code lives or how a missing local file shows.

## Questions and Answers

### Round 1 (2026-10-31: Itay, stage 2a)

- **Q: How does the app know that an undo or redo reverses a checkbox change?**
  A: `TextChange` gets a field that carries the reason of the undo group.
- **Q: What do later saves write, when the person deletes the last newline or pastes a CR?**
  A: Every save writes the normalized text.
- **Q: Does an empty or BOM-only file get a final newline in the buffer?**
  A: No. An empty text stays empty.
- **Q: Where does the dirty and save-now policy live?**
  A: `TextChange` moves to `MarkdownCore`. `MarkdownViews` re-exports `MarkdownCore`. The policy is in `MarkdownCore`.

### Round 2 (2026-10-31: Itay, stage 2b)

- **Q: Plan 03 stage 3c holds log 002 view items that plan 01 did not build. When are they built?**
  A: Each plan 02 stage builds the 3c items it needs. Stage 2b builds `activateImage(_:)`, the final image strings, the refused reason line, and the reload status line. Nothing in 3c stays unbuilt after 2f.
- **Q: Where does app code with file or network I/O live?**
  A: In a package target `ScrollSupport` that is not a product. `swift test` and the coverage gate test it. Fortkeeps does not build it. The app targets link it.
- **Q: Which card does each load failure give?**
  A: Over 5,000,000 bytes, remote or local: `.failed(tooLarge)`. A redirect to http or to a blocked host: `.refused`. A 4th redirect, a status that is not 2xx, or a DNS or connection error: `.failed(network)`. A timeout: `.failed(timedOut)`.
- **Q: How does the host learn about Reload Image and Load All Images?**
  A: `MarkdownHost` gets two required methods, `reloadImage(_:)` and `loadAllImages()`.
- **Q: Log 001 gives an SVG `.failed(unsupported)`. Log 002 gives it `.refused`. Which wins?**
  A: `.failed(unsupported)`. The loader reads the bytes, not the name.
- **Q: Which failed cards show Try Again?**
  A: Only `timedOut` and `network`, as in the log 001 table.
- **Q: How does a failed reload reach the view?**
  A: As a payload of the result: `.image(Data, reloadFailure: ImageFailure?)`. The next good reload clears it.
- **Q: What does a missing, folder, or unreadable local file show?**
  A: `.refused`.
- **Q: Where does the hint "Shows the image from this file." go?**
  A: On the folder-access card. A remote card keeps "Loads the image from {host}."
- **Q: How does the card of an untitled document say why a local image does not show?**
  A: `.refused` carries an optional reason from the host: `.refused(reason: String?)`. The app passes "Save the document to show local images."

### Round 3 (2026-11-01: Itay, stage 2c)

- **Q: How is the app project set up?**
  A: With XcodeGen. `project.yml` is checked in. `just` generates the `.xcodeproj`, and git ignores it.
- **Q: Plan 03 says to build unsigned. The sandbox and the UI tests need a code signature. Which build?**
  A: An ad-hoc signature (`CODE_SIGN_IDENTITY` `-`), with no team ID and no provisioning profile. The sandbox entitlements apply. The build runs on this Mac only.
- **Q: Which menu commands does 2c build?**
  A: Every command whose feature exists in 2c, plus per-document zoom and `#fragment` links. Export, Print, Open Folder, the sidebar, the Outline, Settings, and Copy as Rich Text come with 2f.
- **Q: Do the UI tests run in the gate?**
  A: Yes. `just check` runs the keyboard and accessibility-audit UI tests.
- **Q: What does the create button of the empty window read?**
  A: `New File`, as the File menu and the sidebar (log 002).

### Round 4 (2026-11-02: Itay, stage 2d)

- **Q: Which UI framework does the iOS app use?**
  A: UIKit, like the AppKit Mac app and the UIKit `MarkdownView`.
- **Q: What Settings does 2d build?**
  A: The ⋯ menu entry and an empty Settings sheet with Done. 2f fills Settings on iOS and Mac together.
- **Q: Where does New File on the iPhone home screen create `Untitled.md`?**
  A: In the app's own folder, shown in Files as On My iPhone › FK Scroll (`Untitled.md`, then `Untitled 2.md`). It opens with the keyboard up, with no picker.
- **Q: What is the iPhone home screen's title?**
  A: `Open Files`, the same as the document screen's back button.
- **Q: Does 2d build the iOS strips (save failed, read-only, deleted)?**
  A: Yes, all three, with the copy and buttons of screens §3, as on the Mac. Without them a failed save on iOS is silent.
- **Q: Where does the read-only strip's Duplicate put the copy on iOS?**
  A: In the app's own folder, as `{name} copy`, then `{name} copy 2`, with the file's extension. It opens at once, with no sheet, as New File does. Save As… uses the Files export sheet.

### Round 5 (2026-11-02: Itay, stage 2e)

- **Q: Logs 001 and 003 differ on an outside change with no unsaved edits. Which rule does 2e build?**
  A: Log 003: an undoable reload with the note `Updated with changes from another app.` It replaces log 001's silent reload that clears Undo, and the plan's must-pass test changes with it.
- **Q: Which copy do the outside-change dialog and the compare view use?**
  A: Log 003's copy. Log 001's Reload, Keep Mine, and Resolve… keep their behavior under log 003's names.
- **Q: How much of the Resolve view (screens §3.11) does 2e build?**
  A: The core with keyboard and VoiceOver: hunk choices, state labels, collapsed unchanged runs, the counter, Apply and Cancel, side by side or inline, the keys, and VoiceOver hunk containers. Edit in a hunk, Use Both Theirs First, Use … for the Rest, the Changes rotor, the changed-again banner, and the ⌥⌘I toggle wait.
- **Q: When is the text saved after Undo Reload?**
  A: By autosave, like a typed edit. Redo Reload is the same.
- **Q: What library API does 2e add?**
  A: `MarkdownView.reload(text:undoActionName:)` and `MarkdownView.replaceText(_:)`. Plan 01's `reload(text:)` still clears Undo.
- **Q (Itay's direction, 2026-11-02): where does the compare view live?**
  A: In the library, so Fortkeeps can use it for its own conflicts: `ResolveModel` (the state) in `MarkdownCore`, `ResolveView` (the view, its keys, VoiceOver, and its strings) in `MarkdownViews`. The host gives the column titles; Scroll passes log 003's `Your Changes` and `On Disk`.
- **Q: After a rename, `MarkdownView.documentURL` keeps the old folder. Add a public setter?**
  A: Yes. `MarkdownView.documentURL` is settable; both apps set it when the file moves, so relative links and images resolve against the new folder.
- **Q: Screens §3.11 names Apply's undo group "Undo Resolve", but `replaceText(_:)` takes no name. Add one?**
  A: Yes: `replaceText(_:undoActionName:)`, with the name optional (default nil). Scroll passes `Resolve`.
- **Q: Screens §3.10 asks for a VoiceOver hint on each dialog button; log 003 has no hint copy. What does 2e build?**
  A: DRAFT hints until WAIT-3: `Replaces your changes with the other app's version and clears Undo.`, `Saves your version over the other app's.`, `Shows both versions so you can choose each change.`
- **Q: The screen is locked, so the UI tests cannot run. What then?**
  A: Itay unlocks the screen; 2e runs `just mac-app-test ios-app-test` before its commit.

### Round 6 (2026-11-02: Itay, stage 2f)

- **Q: Settings › Line width gives Medium 680 pt only. What are Narrow and Wide?**
  A: Narrow 560 pt, Medium 680 pt, Wide 840 pt.
- **Q: Which folder does the folder sidebar show, and what does Open Folder… do?**
  A: Each window shows its document's folder once the app has access to it. Open Folder… (⇧⌘O) picks a folder, stores its access, and shows it in the front window's sidebar; with no document window, it opens a new Untitled window with that folder in the sidebar. The iPad works the same.
- **Q: On iOS, do the export items go in the Share menu (screens §3.16) or in ⋯ (§3.20)?**
  A: ⋯ › Export holds Export PDF, Export HTML, Print, and Copy as rich text. The Share button stays the system share sheet for the file itself.
- **Q: What happens to raw HTML in Export as HTML?**
  A: It is escaped and shown as source text in a code block, like the in-app fallback (screens §3.9 outcome A).
- **Q: Does the iPhone get the folder list?**
  A: Yes. ☰ opens a sheet with the Outline and, once folder access exists, the Folder section with New File, Rename, and Move to Trash.
- **Q: Above 20 MB, log 001 shows "Large file: styling updates as you scroll.", but the library styles the whole text at once. What does 2f do?**
  A: 2f builds the 5 MB progress only. The 20 MB note and lazy styling wait for a library change.
- **Q: Is the Mac sidebar shown in a new window?**
  A: Hidden at first. ⌃⌘S or the toolbar button shows it, and new windows follow the last choice. A restored window keeps its own state.
- **Q: How does the folder sidebar show subfolders, and where does New File create the file?**
  A: Subfolders expand in place with a disclosure triangle. New File creates the file in the selected folder, or the folder of the selected file, or else the top folder.
- **Q: iOS has no system Trash for these files (`trashItem` fails: the volume has none). What does Move to Trash do on iOS?**
  A: It moves the file into a `Trash` folder in the app's own Files folder (On My iPhone › FK Scroll › Trash). Undo moves it back. The person empties that folder in Files, so nothing is deleted for good.
- **Q: The sidebar's Outline parsed the whole text on every keystroke, even with the sidebar hidden, against plan 01's rule that no editor path parses the whole text after open (2 MB: about 0.3 s per parse). How does the Outline stay current?** (asked 2026-11-03, during the deep review)
  A: It refreshes only while it is on screen: when it appears, on open and reload, and 1 s after typing pauses. The parse runs off the main thread on a copy of the text, and a result for a text that has changed since is dropped. A hidden sidebar costs nothing. The Outline can lag about 1 s behind typing. A library heading scanner (live, no full parse) was weighed and not chosen: it would have to match cmark's headings (setext, in lists and quotes) and render each title as drawn.
- **Q: On iPhone the Outline (☰) button narrows the title block, and the accessibility audit flags the status subtitle ("Documents · Saving…") as clippable at larger Dynamic Type. What does 2f do?** (asked 2026-11-03, during the gate)
  A: Accept it. The subtitle is UIKit's own navigation-bar label, which truncates at large sizes as system apps do, and VoiceOver reads it in full. The UI test's audit skips only the clipped-text issue on that subtitle. Not chosen: dropping the folder from the iPhone status, moving Outline into ⋯, or a custom title view.

### Round 7 (2026-11-03: Itay, the plan 02 whole-plan review)

- **Q: Both apps list `public.plain-text` in the Markdown document type at rank Default. That claims every plain-text file (source code, logs), which Scroll then refuses. What does `.txt` use?**
  A: Markdown keeps rank Default. `.txt` is a second document type at rank Alternate: on the Mac by its extension only, on iOS by `public.plain-text`, since iOS matches by type only.
- **Q: Another app writes the open file with bytes that are not UTF-8, or with a NUL. Both apps ignored it, and the next save wrote over the other app's version. What happens?**
  A: Saves and edits pause, and a strip reads `"<name>" changed outside Scroll and can't be read as text.` (DRAFT until WAIT-3), with `Keep My Changes` (iOS: `Keep my changes`), which saves the text over the other version, and `Close`.
- **Q: The Mac and iOS code repeat the outside-change flow and the document's disk check. Share them now?**
  A: Both now: one disk check (`DiskWatch`) for both documents, and one outside-change flow (`OutsideChangeHost`) that each app's controller adopts.
- **Q: When do the UI tests run on the review's fixes?**
  A: After the fixes and the gate without them; the reviewer asks Itay first, so he can step away from the Mac.

## Design

### Document types (amends log 001 › Files; Round 7)

The Markdown type (`net.daringfireball.markdown`: `.md`, `.markdown`, `.mdown`, `.mkd`) has rank Default.
`.txt` is a second type with rank Alternate. The Mac app claims it by its extension only, so Scroll never claims a source file or a log. The iOS app claims `public.plain-text`, because iOS matches documents by type only.

### Host interface (amends log 001 › Host interface)

`TextChange` is in `MarkdownCore`.
`MarkdownViews` re-exports `MarkdownCore`, so a host that imports `MarkdownViews` sees `TextChange`.
`TextChange` has `reason`, `groupReason`, `range`, `replacement`, and `text`.
`groupReason` is the reason of the change that made the undo group.
For `undo` and `redo`, `groupReason` is `edit` or `checkbox`.
For every other reason, `groupReason` equals `reason`.
This is an additive change to the public API.

### Files (amends log 001 › Files)

The app normalizes the text on every save:
- CRLF and a lone CR become LF.
- A text that has at least one character after a leading BOM ends with a newline.
An empty text stays empty. A text that is only a BOM stays only a BOM.
The app applies the same normalization to the buffer when it opens a file.

The save action of a change is:

| Change | Action |
|---|---|
| `reload` | The document stays clean. |
| `checkbox` | The document saves now, with any pending edits. |
| `undo` or `redo` with `groupReason` `checkbox` | The document saves now. |
| `edit`, and `undo` or `redo` with `groupReason` `edit` | The document is dirty. The system schedules the save. |

`MarkdownCore` holds these rules in `DocumentFile`.

### Images (amends log 001 › Images and Host interface, log 002 › Host interface and Image cards)

`MarkdownHost` has `activateImage(_ activation: ImageActivation)`, `reloadImage(_ request: ImageRequest)`, and `loadAllImages()`. All three are required.
`ImageResult` has `.image(Data, reloadFailure: ImageFailure? = nil)` and `.refused(reason: String?)`.
The view shows Reload Image on a drawn image. It shows Load All Images in This Document while a remote image of the document has no result or shows its load card.

A failed card shows Try Again only for `timedOut` and `network`.
A refused card shows the host's reason line, when there is one.
The folder-access card has the hint "Shows the image from this file."
A kept image with a failed reload shows "Couldn't reload this image. {reason}" under it. VoiceOver announces the line once.

The app code is in the package target `ScrollSupport`:

| Type | Job |
|---|---|
| `ImageCheck` | Allows png, jpeg, gif, and webp, read from the bytes. Refuses a side over 8192 pixels from the header. |
| `RemoteLoader` | 5,000,000 bytes, 3 redirects with each hop checked by `ImageRules.classify`, no cookies, 10 seconds in all. |
| `URLSessionTransport` | An ephemeral session with no cookie store and no cache. It returns a redirect and does not follow it. |
| `ImageCache` | Caches/Images. A file is named by the SHA-256 of its URL, excluded from backup, and its modification date is its last view. An entry expires 3 days after its last view. |
| `DocumentImages` | The image methods of the app's host for one document. |

`DocumentImages` fetches a remote image only after `activateImage(_:)` or Load All Images. `image(for:)` never fetches. It returns the result of this session, the cached copy, or `.remoteNotLoaded`.
A local image needs a regular file inside the document's folder after symlinks resolve.
A folder without sandbox access gives `.needsAccess`. When the person grants it, every card that showed `.needsAccess` refreshes.
A refused reload (a redirect to a blocked host) shows the refused card. It does not keep the old image.

### Outside changes (amends log 001 › Outside changes; follows log 003)

The app watches each document with a file presenter.
When the file on disk changes and the document has no unsaved edits, the app calls `reload(text:undoActionName:)` with the action name `Reload`.
That reload is one undo group. It replaces only the changed span, so the caret and the anchor stay. It reports `reload`; its undo and redo report `groupReason` `reload`, and autosave saves them.
The note `Updated with changes from another app.` shows at the top of the document for about 4 seconds, with an `Undo` button that undoes the reload. It stays while the pointer is over it. VoiceOver announces it politely. With Reduce Motion on, it does not fade.
When the document has unsaved edits, the app sets `isEditable` false and shows the dialog of log 003: title `"<name>" changed outside Scroll`, body `Another app edited this file while you had unsaved changes. Choose which version to keep.`, buttons `Use Version on Disk`, `Keep My Changes`, and `Compare…` (iOS: `Use version on disk`, `Keep my changes`, `Compare`).
No button is the default. Return and Esc do nothing. On iOS, `Use version on disk` is destructive and no button has the cancel role.
`Use Version on Disk` calls plan 01's `reload(text:)`, which clears Undo.
`Keep My Changes` closes the dialog; the next autosave writes the local text, and the status then reads `Saved your changes over the other version.`
`Compare…` opens the compare view, titled `Compare versions of "<name>"`, with the columns `Your Changes` and `On Disk`.
When the new bytes on disk are not UTF-8 text (or hold a NUL), the app pauses saves and edits and shows the strip `"<name>" changed outside Scroll and can't be read as text.` (DRAFT until WAIT-3) with `Keep My Changes` and `Close`. Keep My Changes saves the document's text over the other version, and the status then reads `Saved your changes over the other version.` Close closes the document without saving. Text written to the file later follows the rules above (Round 7).
Apply calls `replaceText(_:)` with the merged text: one undo group with reason `edit`. Cancel returns to the dialog and writes nothing.

## Trade-offs

- **Chosen:** a `groupReason` field.
  - Pros: The view already knows the undo group. The host does not guess from the bytes.
  - Cons: Every place that makes a `TextChange` passes one more value.
- **Chosen:** normalize every save.
  - Pros: One write function. A file never holds a CR or lacks its final newline.
  - Cons: A person cannot save a file without a final newline.

- **Chosen:** a `ScrollSupport` package target.
  - Pros: `swift test` and the coverage gate cover the app's I/O code without an app target.
  - Cons: The package has a target that Fortkeeps never uses.
- **Chosen:** the reload status line as a result payload.
  - Pros: One refresh path. The view draws what the host returns.
  - Cons: `ImageResult.image` has a second value that most hosts leave empty.

## Verification Criteria

1. An undo and a redo of a checkbox click report `groupReason` `checkbox`. An undo and a redo of a typed edit report `edit`.
2. A save of an edited text ends with a newline and holds no CR.
3. An empty file and a BOM-only file open with no added newline.
4. Opening a document with a remote image makes zero requests. A click makes exactly one.
5. A loaded image draws after a relaunch with zero requests, and expires 3 days after its last view.
6. A failed reload keeps the old image with the status line.
7. A symlink out of the document folder is refused. An SVG gives `.failed(unsupported)`.
