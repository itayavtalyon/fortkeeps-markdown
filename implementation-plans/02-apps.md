# 02 — Apps

**Design:** [`design-logs/001-markdown-library.md`](../design-logs/001-markdown-library.md) revision 3: Images (loader and cache), Links, Files, Outside changes, Windows and chrome, Accessibility, and Copy. Also [`001-markdown-library-screens.md`](../design-logs/001-markdown-library-screens.md) §3 and §4 and `001-wireframes/`, where the log names them.
**Requires:** plan 01 merged.

## Goal

Ship Fortkeeps Scroll for Mac, iPad, and iPhone.
The apps own documents, image bytes, the image cache, and link opening.
The apps call `MarkdownCore` for every decision that Design already made.

## Rules

Read Design before a stage.
Do not put a file or network call in `MarkdownCore`.
Do not add a Save command for a named document.
Do not download a font or a package that Design does not name.
When Design leaves a choice, stop.
Ask Itay with a structured question.
Use the final Story Weaver strings (WAIT-3) for the exact-string tests. Until they exist, use the DRAFT strings in Design and mark those tests pending in Implementation Notes.

## Quality bar

Use the same warning, formatter, and `MarkdownCore` coverage gate as plan 01.
Keep new pure policy in `MarkdownCore` when it has no I/O.
Test that policy in the plan 01 test target.

## Design tasks (Interface)

- WAIT-4: design the `FK Scroll` app icon in the Fortkeeps theme, for macOS and iOS, at every required size. Resolved: delivered to `design/icon/`. Plan 02 stage 2d step 1 uses it.

## Stages

| Stage | Name | Status | Blocked by |
|---|---|---|---|
| 2a | Document policy | Not started | — |
| 2b | Image loader and cache | Not started | — |
| 2c | Mac app | Not started | WAIT-3 (string tests). Signing deferred until the Apple Developer membership (V1-43). |
| 2d | iOS and iPadOS app | Not started | WAIT-3 (string tests), WAIT-4 (icon asset). Signing deferred until the Apple Developer membership (V1-43). |
| 2e | Outside changes and Resolve | Not started | — |
| 2f | Sidebar, export, settings, relaunch | Not started | — |

### 2a — Document policy

1. Add pure helpers for the extension test, the UTF-8 and NUL test, and the LF normalization.
2. Keep a leading BOM.
3. Mark the document clean when normalization is the only difference from disk.
4. Mark the document dirty on the first `edit` or `checkbox`.
5. Save immediately on `checkbox`, and on `undo` or `redo` of a checkbox change.

Must-pass tests:

- Each accepted extension and its uppercase form are accepted.
- Any other extension is refused.
- Invalid UTF-8 and a NUL byte are refused and produce no output bytes.
- A CRLF, a lone-CR, and a mixed buffer become LF in memory and stay clean until an edit.
- The output of the first edit ends with a newline and contains no CR.
- A BOM remains.
- An empty file opens.

### 2b — Image loader and cache

1. Add the loader behind the plan 01 classifier.
2. Stop a load at 10 seconds, 5,000,000 bytes, no cookies, and 3 redirects.
3. Check the host of each hop.
4. Decode png, jpeg, gif, and webp only.
5. Refuse an image wider or taller than 8192 pixels, from the header, before decode.
6. Refuse a symlink whose target leaves the document directory.
7. Return `.needsAccess` when the sandbox has no folder access.
8. Return `.remoteNotLoaded` until the view calls `activateImage(_:)` for that card, or the person chooses Load All Images in This Document. Fetch only after that call.
9. Build the cache in the sandboxed Caches folder, with `isExcludedFromBackup`, keyed by URL.
10. Expire an entry 3 days after its last view.
11. Purge at launch and on entering the background.
12. Build Reload Image and Clear Image Cache.

Must-pass tests:

- The loader tests use a fake transport for the size, the host list, the cookie ban, and the redirect cap.
- A symlink out of the directory is refused.
- An SVG and an undecodable byte stream give `.failed(unsupported)`.
- Opening a document with a remote image makes zero requests.
- `activateImage(_:)` on a remote card starts exactly one fetch; `image(for:)` alone starts none.
- A loaded image is cached. A relaunch draws it with zero requests.
- With a fake clock, an entry expires after 3 days without a view. A view resets the clock.
- Every cache file has `isExcludedFromBackup`.
- A failed Reload Image keeps the old copy.
- Clear Image Cache empties the cache.

### 2c — Mac app

1. Create the Mac app target `Fortkeeps Scroll` on macOS 15, with the bundle ID `app.fortkeeps.scroll` (WAIT-6 resolved 2026-10-26). Build unsigned, for tests only. Signing and notarization are deferred until Itay buys the Apple Developer membership (roadmap V1-43); do not add a team ID or a provisioning profile.
2. Store each file in an `NSDocument`.
3. Use the system document tabs and the Design menus and shortcuts.
4. Open each document in `.editor`. Lock selects `.editorLocked`.
5. Set the window title to the file name and the subtitle to the folder.
6. Show the empty window, the status bar, and the folder-access strip from Design.
7. Autosave `edit`, `undo`, and `redo` changes through `NSDocument`.
8. Show Save… only for an untitled document.
9. Open links through the plan 01 link classifier: the default browser, the default mail app, or a tab.
10. Show the refusal alerts.
11. Bundle the fonts, `OFL.txt`, and the Acknowledgements window.
12. Show the strips for a deleted file, a read-only file, and a failed save.

Must-pass tests:

- The document type list equals the accepted extensions.
- A second open of the same path selects the open document.
- The refusal strings equal the final strings.
- A checkbox path calls save immediately. An `edit` change does not call save directly.
- A failed save shows the strip and keeps the text.
- Option-Command-L toggles Lock, and Lock disables the checkboxes.
- `performAccessibilityAudit()` passes on the document window and the empty window.
- Launch blockers (keyboard and VoiceOver): a UI test with Full Keyboard Access tabs through links, checkboxes, and image cards in reading order; Return opens a link; Space toggles a checkbox; Control-F6 enters the format bar and Esc returns. Each heading exposes its level.

Done when the stage definition of done holds.
Then run this manual check:
1. Open a CRLF file and quit without an edit. Confirm the disk bytes are unchanged.
2. Toggle a checkbox. Confirm the file is LF and the checkbox byte changed.
3. Undo. Confirm the file has the old checkbox byte.

### 2d — iOS and iPadOS app

1. Create the iOS app target on iOS 18. Set `CFBundleDisplayName` to `FK Scroll`. Use the bundle ID `app.fortkeeps.scroll` (WAIT-6 resolved 2026-10-26). Build unsigned, for the simulator and tests only, until the Apple Developer membership exists (roadmap V1-43). Use the Interface icon (WAIT-4). Until the icon exists, use a blank placeholder asset and record that in Implementation Notes.
2. Store each file in a `UIDocument`.
3. Use the system document browser as the launch screen.
4. Show the iPad tab strip with the file name and a close control labelled "Close {name}".
5. Show one file on iPhone, with a back button to the list `Open Files`.
6. Dock the format bar above the keyboard.
7. Use the same Lock, autosave, immediate checkbox save, and link rules as the Mac app.
8. Put Settings in an in-app sheet.

Must-pass tests:

- The iOS document types match the Mac types.
- The iPad tab shows the file name and the close control.
- The iPhone back button shows `Open Files`.
- New creates `Untitled.md` in the current folder.
- The iOS checkbox path saves immediately.
- `performAccessibilityAudit()` passes on the document screen.
- iOS typing undo (UI test): type "hello world" with a 1 s pause before "world", then shake-to-undo or the three-finger undo gesture removes "world" only, and the caret is at the end of the restored text.
- With Auto-Play Animated Images off, a gif shows frame 1 with the play action. Every link is underlined.

### 2e — Outside changes and Resolve

1. Watch each document with a file presenter.
2. With no unsaved edits, call `reload(text:)` and announce "Updated from disk.".
3. With unsaved edits, set `isEditable` false and show the dialog.
4. Give the dialog no default button, and make Return and Esc do nothing.
5. Build Reload, Keep Mine, and Resolve….
6. Build the Resolve view on the plan 01 line diff.
7. Write Apply once, as one undo group.
8. Return Cancel to the dialog.

Must-pass tests:

- An outside change with no edits reloads silently and clears Undo.
- An outside change with edits shows the dialog. Esc and Return change nothing.
- Reload loads the disk text and clears Undo.
- Keep Mine writes the local text on the next autosave.
- Resolve Apply writes once. Undo restores the pre-resolve text.
- Resolve Cancel writes nothing and shows the dialog again.
- A checkbox click while the dialog is visible changes no byte.

### 2f — Sidebar, export, settings, relaunch

1. Build the folder sidebar with New File, Rename, and Move to Trash, with Undo.
2. Build the Outline section.
3. Build Find and Replace on the system find interface.
4. Build Export as PDF, Export as HTML with embedded local images, Print, and Copy as Rich Text.
5. Build Settings: line width, word count, folders with access, and Clear Image Cache.
6. Restore every open document, its anchor, and its Lock on relaunch.
7. Open a file over 5 MB with the progress indicator.

Must-pass tests:

- Move to Trash moves the file to the Trash, and Undo restores it.
- New File creates `Untitled.md`, then `Untitled 2.md`.
- HTML export contains no script, embeds a local image as data, and fetches nothing.
- Replace All is one undo group.
- Relaunch restores two documents with their anchors and Lock.
- A file larger than 64 KiB opens. A 6 MB file shows the progress indicator.

## Handover

When the stage definition of done holds except the second review, commit the stage.
Write `.claude/REVIEW_REQUEST` with the stage name, this plan path, and the commit.
Stop.
Do not start the next stage.
