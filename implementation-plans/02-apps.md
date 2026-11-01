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
| 2a | Document policy | Built, self-reviewed (step-wide review pending) | — |
| 2b | Image loader and cache | Built, self-reviewed (step-wide review pending) | — |
| 2c | Mac app | Not started | WAIT-3 (string tests), WAIT-6 (signing) |
| 2d | iOS and iPadOS app | Not started | WAIT-3 (string tests), WAIT-4 (icon asset), WAIT-6 (signing) |
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
8. Return `.remoteNotLoaded` until the person loads the image.
9. Build the cache in the sandboxed Caches folder, with `isExcludedFromBackup`, keyed by URL.
10. Expire an entry 3 days after its last view.
11. Purge at launch and on entering the background.
12. Build Reload Image and Clear Image Cache.

Must-pass tests:

- The loader tests use a fake transport for the size, the host list, the cookie ban, and the redirect cap.
- A symlink out of the directory is refused.
- An SVG and an undecodable byte stream give `.failed(unsupported)`.
- Opening a document with a remote image makes zero requests.
- A loaded image is cached. A relaunch draws it with zero requests.
- With a fake clock, an entry expires after 3 days without a view. A view resets the clock.
- Every cache file has `isExcludedFromBackup`.
- A failed Reload Image keeps the old copy.
- Clear Image Cache empties the cache.

### 2c — Mac app

1. Create the Mac app target `Fortkeeps Scroll` on macOS 15, with the bundle ID `<V1-43 prefix>.scroll`. Until WAIT-6 is answered, build unsigned for tests only.
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

Done when the stage definition of done holds.
Then run this manual check:
1. Open a CRLF file and quit without an edit. Confirm the disk bytes are unchanged.
2. Toggle a checkbox. Confirm the file is LF and the checkbox byte changed.
3. Undo. Confirm the file has the old checkbox byte.

### 2d — iOS and iPadOS app

1. Create the iOS app target on iOS 18. Set `CFBundleDisplayName` to `FK Scroll`. Use the bundle ID `<V1-43 prefix>.scroll`. Use the Interface icon (WAIT-4). Until the icon exists, use a blank placeholder asset and record that in Implementation Notes.
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

Plan 02 flow (Itay, 2026-10-31, `decision:fortkeeps-markdown-plan02-flow-2026-10-31`): each stage is built, deep-reviewed in-session, and committed, and the next stage starts without `.claude/REVIEW_REQUEST`. After 2f the implementer writes `.claude/WHOLE_PLAN_REVIEW` and stops. This replaces the Handover above for plan 02.

## Implementation Notes

### 2a — Document policy

Branch `stage/2a-document-policy` from `main` at 64a7708.

**Decisions.** Itay answered four grill questions (`decision:fortkeeps-markdown-2a-save-policy-2026-10-31`), recorded in design log 004 Round 1:

1. `TextChange` gains `groupReason`: for `undo` and `redo`, the reason of the undo group (`edit` or `checkbox`); for any other reason, the reason itself. The controller's `UndoGroup` keeps the reason of the change that opened it, and its inverse keeps the same reason, so a redo carries it too.
2. Every save writes the normalized text (CRLF and lone CR to LF, a final newline).
3. An empty or BOM-only text stays empty.
4. `TextChange` moved from `MarkdownViews/MarkdownHost.swift` to `MarkdownCore/TextChange.swift`. `MarkdownViews` re-exports `MarkdownCore` (`@_exported import` in `MarkdownViews.swift`).

**Files.** `Sources/MarkdownCore/DocumentFile.swift` (`acceptedExtensions`, `accepts(_:)`, `text(from:)`, `data(for:)`, `normalized(_:)`, `SaveAction`, `saveAction(for:)`), `Sources/MarkdownCore/TextChange.swift`. `LinkRules` now calls `DocumentFile.accepts(_:)`; `LinkRules.acceptedExtensions` moved to `DocumentFile` (no release tag exists, so no consumer breaks). `MarkdownTextController` passes `groupReason`. Tests: `Tests/MarkdownCoreTests/DocumentFileTests.swift` (16 tests), two tests in `MarkdownTextControllerCheckboxTests`, and two literal `TextChange` values updated in `MarkdownTextControllerTests`.

**Consumers.** A host that builds a `TextChange` (a test double) passes `groupReason`. A host that imports only `MarkdownViews` still sees `TextChange` and `DocumentFile`. Proof: a probe test that imports only `MarkdownViews` and builds a `TextChange` compiled with the re-export and failed with `cannot find type 'TextChange' in scope` without it.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| Each accepted extension and its uppercase form are accepted. | `each accepted extension and its uppercase form are accepted` (11) |
| Any other extension is refused. | `any other extension is refused` (7, with `a.md.zip`, `.md`, `a.mdx`) |
| Invalid UTF-8 and a NUL byte are refused and produce no output bytes. | `invalid UTF-8 is refused and gives no text` (6: lone continuation, `FF`, truncated, overlong, surrogate, past U+10FFFF), `a NUL byte is refused and gives no text` (4). `text(from:)` throws `Refusal.notUTF8`, so no text exists. |
| A CRLF, a lone-CR, and a mixed buffer become LF in memory and stay clean until an edit. | `CRLF, a lone CR, and mixed endings become LF in the buffer` (7); `a reload leaves the document clean`, `an edit marks the document dirty and leaves the save to autosave`. Opening makes no `TextChange`, so nothing marks the document dirty before the first change. The `NSDocument` check (`isDocumentEdited` false after open) belongs to 2c. |
| The output of the first edit ends with a newline and contains no CR. | `the saved bytes end with a newline and contain no CR` (4), `the saved bytes keep the BOM and the text` |
| A BOM remains. | `a leading BOM stays in the buffer`, `the saved bytes keep the BOM and the text` |
| An empty file opens. | `an empty file opens and stays empty` (2: empty, BOM only), `an empty text saves as no bytes` |

Also (steps 4–5): `a checkbox change saves immediately`, `undo or redo of a checkbox change saves immediately` (2), `undo or redo of an edit leaves the save to autosave` (2), `undo and redo of a checkbox click carry the checkbox group reason`, `undo and redo of a typed edit carry the edit group reason`.

**Self-review (deep review, in session).**

- Mutations: 21 one-clause mutants over `DocumentFile`, the `LinkRules` call, and the controller's group reason (runner in the session scratchpad: restores the file in `finally`, counts a mutant red only with a named failing test). M5 survived first: skipping a LF after a CR without resetting the flag ate the next LF, so `a\r\n\nb` lost its blank line. Tests now include `a\r\n\nb\n` and `a\r\r\n\r\nb\n`; M5 is red. Two mutants did not build (an unused constant) and were run again in a valid form (`byte == carriageReturn + 1`, `count > min(bomLength, 0)`); both red. One survivor is equivalent and stays: `groupReason == .edit ? .autosave : .saveNow` gives the same actions, because the controller reports only `edit` or `checkbox` as the group reason of an undo or redo (`undo and redo of ... carry the ... group reason`).
- Probes: a BOM followed by U+0301 is one grapheme, so `hasPrefix` does not see the BOM; `normalized` still adds the newline (test argument added). The same grapheme rule makes `MarkdownDocument` and the controller treat that BOM as text; both use `hasPrefix`, so their offsets agree. Not changed (plan 01 code, a text that starts with a combining mark).
- Timing (release, M1 Max, probe test removed after the run): open (`text(from:)`) 2 MB 15 ms, 20 MB 143 ms; save (`data(for:)`) 2 MB 5 ms, 20 MB 54 ms. Neither runs per keystroke; autosave calls `data(for:)` once per save.
- Lint: SwiftLint `optional_data_string_conversion` refused `String(decoding: [UInt8], as: UTF8.self)`; `normalized` writes into `String(unsafeUninitializedCapacity:)` instead, which also drops the array copy.
- Auto-fixed: `SaveAction.none` renamed `stayClean` (it shadowed `Optional.none` in a pattern). A pre-existing warning in `MarkdownDisplayTests` (a captured `var` mutated in a `@Sendable` observer) now uses `Mutex`; `just check` printed it on `main` too.
- Simplify: (1) `data(for:)` is one line over `normalized`; kept, because both apps call it as the save entry point. (2) The extension set and test had two copies (`LinkRules` and the new rule); now one. (3) `apply`'s `groupReason` defaults to `reason`, so only `reverse` passes it; no other call site changed.
- Gate infrastructure: during this stage a background CoreSimulator update (framework 1174.21, 20:44) unmounted the iOS 27.0 image ("Unusable - Cryptex Mount Preferred"), and a new iOS 27.1 runtime supports only an "iPhone Duo" device type that Xcode 27.2 does not list. The step passed once the 27.0 image remounted, on the unchanged tree.
- Gate: `just check` passes on the committed tree: 122 MarkdownViews, 305 MarkdownCore, and 17 FortkeepsCards tests on macOS, coverage 100% for both pure modules, the module trace, the iOS build, the MarkdownViews tests on iPhone 18 Pro, lint, and format, with zero warnings.

### 2b — Image loader and cache

Branch `stage/2b-image-loader` from the 2a tip (c02c16c).

**Decisions.** Itay answered ten grill questions in three rounds (`decision:fortkeeps-markdown-2b-images-2026-10-31`, `decision:fortkeeps-markdown-2b-image-cards-2026-10-31`), recorded in design log 004 Round 2:

1. Each plan 02 stage builds the plan 03 stage 3c items it needs. 2b builds `activateImage(_ activation: ImageActivation)` (replaces `imageActivated`), the final log 002 image strings, the refused reason line, and the reload status line.
2. App code with I/O lives in the package target `ScrollSupport` (depends on `MarkdownViews`, not a product). The coverage gate covers it.
3. Load failures: over 5,000,000 bytes → `.failed(tooLarge)`; a redirect to http or a blocked host → `.refused`; a 4th redirect, a status that is not 2xx, a DNS or connection error → `.failed(network)`; a timeout → `.failed(timedOut)`.
4. `MarkdownHost` gains required `reloadImage(_:)` and `loadAllImages()`.
5. An SVG gives `.failed(unsupported)`; the loader reads the bytes.
6. Try Again only on the `timedOut` and `network` cards.
7. A failed reload travels as `.image(Data, reloadFailure: ImageFailure?)`.
8. A missing, folder, or unreadable local file gives `.refused`.
9. "Shows the image from this file." is the hint of the folder-access card.
10. `.refused(reason: String?)`; the app passes "Save the document to show local images." for a local image in an untitled document (`ImageSource.localInUntitled`, new in `ImageRules`).

Choices made in code, not asked (flag them in the step-wide review):

- A reload that ends `.refused` (a redirect to a blocked host) shows the refused card. `ImageFailure` has no refused case, so the old image cannot keep a status line for it.
- A reload of a local image reads the file again through `image(for:)`. It does not keep the old copy on failure: the file on disk is the truth.
- Granting folder access refreshes every destination that returned `.needsAccess` in this session, not only the clicked card.

**Files.**

- `MarkdownViews`: `MarkdownHost.swift` (the host methods, `ImageActivation`, public `ImageRequest.init`, the two result payloads), `ImageCardContent.swift` (strings, status line, labels), `MarkdownTextController+Links.swift` (activation, menu items, announcement), the card views and editor marks (status line under a kept image), `ImageMenu+AppKit.swift` (new: the Mac context-menu items, split out of `MarkdownView+AppKit.swift` for the file-length rule), the iOS edit menu in `MarkdownView+UIKit.swift`.
- `MarkdownCore`: `ImageRules.swift` (`ImageSource.localInUntitled`, `FolderPath.decoded`).
- `ScrollSupport` (new): `ImageCheck`, `RemoteLoader` (with the `ImageTransport` port), `URLSessionTransport`, `ImageCache`, `DocumentImages` (with the `FolderAccess` port).
- Tests: `Tests/ScrollSupportTests` (61 tests, `FakeTransport`, a `URLProtocol` stub, a fake clock, a fake folder-access port), plus new and changed tests in `ImageCardContentTests`, `ImageRulesTests`, `MarkdownTextControllerImageMenuTests` (new file, split from the mode tests), `MarkdownViewMacLayoutTests`, and `MarkdownViewIOSTests`.
- Gate: `scripts/check-coverage.py` gates `ScrollSupport` and reads the summary of a module that SwiftPM's report leaves out from that module's own test bundle (SwiftPM writes the report from one bundle only). `scripts/ios-test.sh` also runs `ScrollSupportTests` on the simulator.

**Left to later stages.** Purge at launch and on entering the background (step 11) is wiring in the app delegates: 2c and 2d call `ImageCache.standard.purge()`. Clear Image Cache (step 12) is `ImageCache.clear()`; its Settings control is 2f. The real `FolderAccess` (security-scoped bookmarks and the folder picker) is 2c and 2d. The strings catalog entry `img.untitled` is added with the app's catalog in 2c.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| The loader tests use a fake transport for the size, the host list, the cookie ban, and the redirect cap. | `RemoteLoaderTests`: `a body over 5,000,000 bytes is too large` (5,000,000 passes, 5,000,001 fails), `the transport is asked for at most 5,000,000 bytes`, `a redirect to http or a blocked host is refused and not followed` (8 locations), `a request sends no cookies`, `three redirects are followed, each hop checked`, `a fourth redirect is a network failure`, plus status, transport-failure, and timeout tests. `URLSessionTransportTests`: `the session keeps no cookies and no cache`, `a redirect is returned, not followed`, `the body is read to one byte past the limit`. |
| A symlink out of the directory is refused. | `a symlink out of the document folder is refused`; `a symlink inside the document folder is followed` |
| An SVG and an undecodable byte stream give `.failed(unsupported)`. | `bytes that are not an allowed image are unsupported` (remote), `a local SVG or undecodable file is unsupported`, and the `ImageCheckTests` |
| Opening a document with a remote image makes zero requests. | `opening a document makes zero requests` |
| A loaded image is cached. A relaunch draws it with zero requests. | `activating a card fetches once and caches the image`, `a cached image shows on a later open with no request` (a new `DocumentImages` on the same cache folder), `a stored image is read back, also by a new cache on the same folder` |
| With a fake clock, an entry expires after 3 days without a view. A view resets the clock. | `an entry expires 3 days after its last view`, `an entry is still shown exactly 3 days after its last view`, `purge removes only expired entries` |
| Every cache file has `isExcludedFromBackup`. | `every cached file is excluded from backup` |
| A failed Reload Image keeps the old copy. | `a failed reload keeps the old copy with the reason`, `a failed reload keeps the copy loaded in this session`, `a reload with no old copy shows the failed card` |
| Clear Image Cache empties the cache. | `clear empties the cache and size counts the bytes` |

Also: `activating a card fetches once and caches the image` activates twice and sees one request (`activateImage` gives exactly one fetch, `image(for:)` none). `load all fetches each remote image of the text once, and nothing else`, `load all skips an image loaded in this session`.

**Self-review (deep review, in session).**

- Mutations: 4 runs of 35, 14, 3, and 1 mutants with `scratchpad/mutate.py` (one clause each; a script restores the file). Every mutant of the final code is caught, except one harmless one and one caught by a hang (below).
  - Run 1 (35): 24 caught. Survivors led to fixes: the session config (`the session keeps no cookies and no cache`), Load All's skip (`load all skips an image loaded in this session`), the FIFO and size reads (`a FIFO is refused without a read`, the bounded read). The 10-second timeout hung the process; the timeout test now has a 1-minute time limit. Accepted: the cleanup after a failed cache write (a failed `setResourceValues` cannot be caused in a test).
  - Run 2 (14) caught 10. `old ?? cache` survived, so a new test covers a cache another document changed (`a failed reload keeps the shown copy when another document changed the cache`). `starts(with: base) → true` survived, because the symlink test's target had the same depth as the folder and the depth check refused it. The target is now deeper. The depth check (`count > base.count`) was redundant with the regular-file check and is deleted.
  - Runs 3–4: both caught (`starts(with: base.prefix(1))` and `base.dropLast()` by `a symlink out of the document folder is refused`).
  - Caught by a hang: `isRegularFile == true → != nil` blocks the FIFO test on a read that a time limit cannot cancel. The test never passes.
  - Harmless: `needAccess = []` removed. A later grant refreshes cards that already refreshed.
  - The first run 2 died with the session and left a mutant in the tree; it printed nothing because its output was buffered. The runner now caps each mutant at 7 minutes and prints each result when it ends.

- Coverage: the gate first passed with `ScrollSupport` missing from the report, because SwiftPM's JSON comes from one test bundle (the same reason `MarkdownViews` is not gated). The script now asks `llvm-cov export` for that bundle. Then 4 uncovered functions were `??` fallbacks that cannot run (`url.host() ?? ""`, `fileSize ?? 0`); they are now guards. The line after the redirect loop was covered in one run and not in the next; the loop is now `while true` and returns from inside, and the unreachable function end has a `coverage:ignore`.
- Bugs found and fixed: granting folder access refreshed only the clicked card, so the other cards of the folder kept "Needs folder access" (now every `.needsAccess` destination refreshes; test). A failed cache write was silent (now logged with `Logger`, and a half-written file is removed; test). Two tests checked `.loading` after the fake answered, which raced; the loading state has its own test against a request that never answers.
- Local reads: `Data(contentsOf:)` read the whole file before the size check, and a FIFO would block it. Now the file must be a regular file and the read stops one byte past the limit (`FileHandle.read(upToCount:)`), so one check covers both a large file and a file that grows.
- Lint fixes: `ImageCardContent.init` lost its `kind` switch to a helper; the Mac image menu moved to its own file; the mode tests and the document image tests were split into a second file each.
- Performance: `URLSessionTransport` appends the async bytes one at a time. It runs off the main actor, at most 5,000,001 bytes per image. Not measured; measure in 2c with a real image if a load feels slow.
- Gate: `just check` green with 0 warnings (2026-11-01): Swift Testing on macOS ran 306 + 132 + 62 + 17 tests; the coverage gate holds `MarkdownCore`, `FortkeepsCards`, and `ScrollSupport` at 100%; the iPhone 18 Pro simulator ran 120 `MarkdownViews` and 62 `ScrollSupport` tests; lint and format are clean. SwiftLint's `modifier_order` now puts isolation after access level, the order SwiftFormat writes (`private nonisolated`); the two tools disagreed before.

