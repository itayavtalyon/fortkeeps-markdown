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
| 2c | Mac app | Built, self-reviewed (step-wide review pending) | WAIT-3 (string tests pending) |
| 2d | iOS and iPadOS app | Built, self-reviewed (step-wide review pending) | WAIT-3 (string tests pending), WAIT-6 (simulator only: no team ID) |
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


### 2c — Mac app

Branch `stage/2c-mac-app` from the 2b tip (a9143d9).

**Decisions.** Itay answered five grill questions (design log 004 Round 3; the remember writes are held, see Handover):

1. XcodeGen: `project.yml` is checked in; `just project` generates `FortkeepsScroll.xcodeproj`, which git ignores.
2. An ad-hoc signature (`CODE_SIGN_IDENTITY` `-`), no team ID, sandbox on. This is the WAIT-6 fallback: it runs on this Mac only.
3. 2c builds the menu commands whose features exist in 2c, plus per-document zoom and `#fragment` links. Export, Print, Open Folder, the sidebar, the Outline, Settings, and Copy as Rich Text come with 2f.
4. `just check` runs the keyboard and accessibility-audit UI tests (`mac-app-test`).
5. The empty window's create button reads `New File`.

Choices made in code, not asked (flag them in the step-wide review):

- `LSHandlerRank` is `Default`, and the role is `Editor`.
- The image cache purges at launch and when the app resigns active (the Mac has no background state).
- The word count counts the whole text on each change (`ponytail:` comment in `update()`); move it off the main thread if a large file lags.
- `MarkdownView.documentURL` is fixed when the view is made. A rename updates the title (`presentedItemDidMove`) but not the base of relative links; 2e owns outside changes.
- The Help menu is empty (2f has no help book in the plan).
- On Mac the format bar shows on a non-empty selection (log 001), not always.
- Spell check underlines words inside link syntax; the system checker sees the raw text.
- The strip buttons use target/action: Save As and Duplicate go to `NSDocument.saveAs(_:)` and `duplicate(_:)`.

**Files.** App: `project.yml`, `Apps/Mac` (`main.swift`, `LiveEnvironment.swift`, `Info.plist`, entitlements, assets), `Apps/MacUITests/FortkeepsScrollUITests.swift`. `ScrollSupport`: `ScrollDocument`, `ScrollDocumentController`, `ScrollAppDelegate`, `DocumentWindow+AppKit` (also `ScrollEnvironment`), `DocumentHost+AppKit` (the `MarkdownHost` side), `EmptyWindow+AppKit`, `StripView+AppKit`, `MainMenu+AppKit`, `FolderBookmarks+AppKit`, `Acknowledgements+AppKit`, `ScrollStrings`. `MarkdownCore`: `DocumentWindowRules.swift` (`WordCount`, `Zoom`, `MarkdownDocument.needsFolder`). `MarkdownViews`: public `zoom` and `perform(_:)`, the view hands first responder to its text view, a host set late gets the near images, Bold over Select All leaves the last line break outside. Gate: `scripts/mac-app-test.sh` and `just mac-app-test`; the iOS steps pass `-workspace .` so a generated project in the root does not hide the package.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| The document type list equals the accepted extensions. | `the document type list equals the accepted extensions`, `the Markdown type declares every accepted extension but txt` (Info.plist) |
| A second open of the same path selects the open document. | `a second open of the same path gives the open document` |
| The refusal strings equal the final strings. | **Pending (WAIT-3).** `another extension is refused with its alert and not opened` and `a file that is not UTF-8 is refused with its alert` check the DRAFT strings of screens §3; swap in the final strings when Story Weaver delivers them. |
| A checkbox path calls save immediately. An `edit` change does not call save directly. | `a checkbox change saves at once`, `an edit marks the document dirty and does not save` |
| A failed save shows the strip and keeps the text. | `a failed save shows the strip and keeps the text` (read-only folder and file; the strip's Save As goes to the document; the system error sheet is suppressed) |
| Option-Command-L toggles Lock, and Lock disables the checkboxes. | `the Lock item, Option-Command-L, toggles Lock and Lock disables the checkboxes`; UI test `testOptionCommandLLocksAndUnlocksTheText` |
| `performAccessibilityAudit()` passes on the document window and the empty window. | UI tests `testTheDocumentWindowPassesTheAccessibilityAudit`, `testTheEmptyWindowPassesTheAccessibilityAudit`. The empty-window audit ignores "Label not human-readable" only on a recent-file button whose title ends in `.md`: the title is the person's file name. |

Manual check (CRLF, checkbox, Undo): now a UI test, `testACRLFFileKeepsItsBytesAndACheckboxAndItsUndoSaveAtOnce`. It opens `- [ ] one\r\n- [ ] two\r\n`, quits with Command-Q and reads the same bytes, clicks the first checkbox and reads `- [x] one\n- [ ] two\n`, then presses Command-Z and reads `- [ ] one\n- [ ] two\n`. Mutant: with `undo(_:)` emptied it fails at the Undo read.

**Self-review (deep review, in session).**

- Test harness: under `swift test` an AppKit call that stops the main run loop (`performClose` on a document window, ending a Save panel sheet) ends the whole run with exit 0 and no summary, so later suites never ran. Found by checking for the `Test run with` line of `ScrollSupportTests`, then bisecting with `--skip`. Close Window is tested with a window subclass that counts `performClose`; the strip buttons became target/action, so the tests check the target and selector instead of opening the Save panel. File-presenter calls go on `presentedItemOperationQueue` (on main they hang). Each tab test sets its own `tabbingIdentifier`, because AppKit tabs a new window into another test's group.
- Bugs found by running the app: an image card stuck on "Loading…" (the host was set after the first viewport pass); a second Open Recent menu (AppKit adds one); the empty window had no title (a blank Window menu row, a contrast-audit failure) and grew to 853 pt with a long folder; Bold over Select All wrapped the final line break.
- Lint fixes: `MarkdownView+AppKit.swift` over 400 lines (`formatAction(for:)` moved to `FormatBar+AppKit.swift`, `zoom` and `perform(_:)` to an extension); the Find submenu moved out of `editMenu()`; `unowned` captures became `weak`.
- Mutations: 3 runs of 39, 6, and 1 one-clause mutants with `scratchpad/mutate.py` over `ScrollDocument`, `DocumentWindowController`, `ScrollAppDelegate`, `ScrollDocumentController`, `FolderBookmarks`, `EmptyWindowController`, `DocumentWindowRules`, the Select All fix, and the late-host fix.
  - Run 1 (39): 31 caught, 1 skipped (its pattern had changed), 7 survived. The survivors led to these changes:
    - The deleted-file test now waits for an autosave and sees no file. It then saves, and sees the file back with no deleted strip (`a deleted file shows its strip and pauses autosave until a save`).
    - The read-only test now calls Lock and sees it stay on.
    - The Lock test checks the toolbar label.
    - The Remove from Recent test checks that the empty window no longer lists the file.
  - Removed, not tested:
    - `saveOperation != .autosaveElsewhereOperation`: an autosave elsewhere of a deleted document fails with Cocoa error 512 (probe run in the test), so the clause could not matter.
    - `tabGroup?.selectedWindow =` in Command-number: a menu key equivalent reaches only an active app, where `makeKeyAndOrderFront` selects the tab.
  - Accepted: the `!isStale` check in `FolderBookmarks.restore()`; a test cannot make a stale bookmark. The test is now named `a broken bookmark is dropped`.
  - Runs 2–3 (7): every mutant caught, including the late-host re-request and `isDeleted = false` after a save.
- Gate: `just test` now fails unless every bundle under `Tests` reports a passed run. Proof: an empty `Tests/ZZProbe` folder made it fail with `4 of 5 test bundles reported a passed run`.
- Undo was broken on Mac: Edit › Undo stayed disabled and Command-Z did nothing, after typing or a checkbox click. The text view turns `allowsUndo` off, and the window answered `undo:` with its own, empty manager. `MarkdownNSTextView` now handles `undo:` and `redo:` and validates them against the controller's manager (`the window's Undo and Redo reach the view's undo groups`, red before the fix). An `undoManager` override alone did not help; the window does not ask the first responder. `MainMenu` builds the two selectors with `NSSelectorFromString`, because `#selector` cannot see the internal methods and `Selector(("undo:"))` now warns.
- UI test harness: `XCUIApplication.open(_:)` starts its own copy of the app. After `launch()` it started a second copy, and the first copy's empty window stayed on screen. XCUITest reported it as an interrupting 560×412 window, and every test after the first failed. Found with `CGWindowListCopyWindowInfo` and an `NSLog` of the app's windows in the test run, both since removed. The tests now open files without `launch()`, and `tearDown` quits the app, which XCUITest leaves running after `open`. `mac-app-test.sh` ignores XCTest's `[Internal]` priority-inversion warnings about its own threads; app build warnings still fail it.
- Gate fixes:
  - The iOS steps pass `-workspace .`. With `FortkeepsScroll.xcodeproj` in the root, `xcodebuild` picked the project and could not find the package scheme.
  - Coverage of `DocumentImages.image(for:)` dropped the three lines after an `await` in 2 of 5 runs. The test that runs those lines passed each time. The lines moved to a synchronous helper; 5 runs since, all at 100%.
- Known flake: `testTabMovesToALinkAndReturnOpensIt` failed once in about 6 runs ("Failed to … application"), then passed 4 times, including alone. Not explained; rerun `mac-app-test` once and look if it repeats.
- Gate: `just check` green with 0 warnings (2026-11-02): Swift Testing on macOS ran 128 ScrollSupport, 136 MarkdownViews, 310 MarkdownCore, and 17 FortkeepsCards tests; coverage 100% for the three gated modules; the iPhone 18 Pro run; 7 Mac UI tests; lint and format clean.


### 2d — iOS and iPadOS app

Branch `stage/2d-ios-app` from the 2c tip (fafc43e).

**Decisions.** Itay answered six grill questions (design log 004 Round 4; the remember writes are held, see Handover):

1. UIKit, like the AppKit Mac app and the UIKit `MarkdownView`.
2. Settings: the ⋯ menu entry and an empty sheet with Done. 2f fills it on both platforms.
3. New File on iPhone writes `Untitled.md` (then `Untitled 2.md`) into the app's own folder (On My iPhone › FK Scroll) and opens it with the keyboard up, with no picker. On iPad, New is the document browser's create button, which writes into the browser's current folder.
4. The iPhone home screen's title is `Open Files`, the same as the document screen's back button.
5. 2d builds the iOS strips (save failed, read-only, deleted) with the screens §3 copy, as on the Mac. Asked during the deep review: a failed save on iOS showed nothing, and the title said "Saving…" for good.
6. The read-only strip's Duplicate writes `{name} copy` (then `{name} copy 2`), keeping the extension, into the app's folder and opens it. Save as uses the Files export sheet.

Fallback: WAIT-6 (signing) is open, so the iOS app has no team ID and the shared ad-hoc settings of `project.yml`; it builds and runs on the simulator only.

Choices made in code, not asked (flag them in the step-wide review):

- iPhone launches into `Open Files` (log 002 › iPhone home screen), not the document browser; plan step 3's browser is the iPad launch screen and the iPhone Browse button.
- The app has one scene; Stage Manager multiwindow (screens §3.19) is not built.
- Close on the deleted strip, after its confirmation, pops the iPhone screen without animation (the alert's dismissal is the transition).
- Save as exports a copy and opens it; the old screen stays open until the person closes it (iOS has no Save As that moves a `UIDocument`).
- A deleted document stays deleted until it closes: iOS has no plain Save that writes it back, as the Mac's does.
- The tab strip has no drag to reorder, and the iPhone and iPad screens have no Find, Outline, Share, or Export (2f).
- The folder-access strip is not built on iOS: a sibling link with no access opens the Files folder picker at once.
- The UI-test hooks live in the app shell: `FK_SCROLL_UI_TEST` clears the lists and the app folder at launch, and on iPad writes `UI test.md` and reveals it, so the browser starts in the app's folder (Recents has no folder to create in).

**Files.** App: `project.yml` (targets `Fortkeeps Scroll iOS` and `Fortkeeps Scroll iOS UI Tests`, iOS 18, bundle `app.fortkeeps.scroll`, display name `FK Scroll`), `Apps/iOS` (`AppDelegate`, `SceneDelegate`, `LiveEnvironment`, `Info.plist`, the icon from `design/icon`), `Apps/iOSUITests/FortkeepsScrollIOSUITests.swift`. `MarkdownCore`: `FileLists.swift` (`FileLists`, `DocumentFile.untitledName(taken:)`, `copyName(of:taken:)`). `ScrollSupport`: `OpenRefusal` (shared by both apps), `FileListStore` (bookmarks in `UserDefaults`), `FolderBookmarks` (was `+AppKit`, now both platforms), `ScrollDocument+UIKit`, `DocumentSession+UIKit`, `DocumentViewController+UIKit` (also the iOS `ScrollEnvironment`), `HomeViewController+UIKit`, `TabsViewController+UIKit` (also `TabView` and `BrowserViewController`), `StripView+UIKit`, `ScrollStrings+UIKit`. `MarkdownViews`: `MarkdownView` hands first responder and its accessibility label to its text view; two fixes in `MarkdownUITextView` (below). Gate: `scripts/check-document-types.py`, `scripts/check-ios-coverage.py`, `scripts/ios-app-test.sh`, `just ios-app-test`; `ios-test.sh` now runs the `ScrollSupport` tests with coverage on the simulator; `check-coverage.py` leaves `*+UIKit.swift` to the iOS gate.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| The iOS document types match the Mac types. | `scripts/check-document-types.py` in `ios-app-test`: `CFBundleDocumentTypes` (without `NSDocumentClass`) and `UTImportedTypeDeclarations` of both plists are equal. |
| The iPad tab shows the file name and the close control. | UI test `testIPadNewOpensATabWithItsCloseControl` (iPad Air 11-inch (M4)); `each tab shows the file name and a close control named for it`, `a renamed file renames its tab` |
| The iPhone back button shows `Open Files`. | UI test `testIPhoneNewFileOpensUntitledAndGoesBackToOpenFiles` (iPhone 18 Pro); `the title and the back button say Open Files` |
| New creates `Untitled.md` in the current folder. | iPhone: `a new file is Untitled, then Untitled 2, in the app's folder` and the iPhone UI test. iPad: `the browser's New makes an empty Untitled.md for it to move` and the iPad UI test (the browser's current folder). |
| The iOS checkbox path saves immediately. | `a checkbox change saves at once, and a reload stays clean`; `an edit marks the document dirty and does not save` |
| `performAccessibilityAudit()` passes on the document screen. | UI test `testTheDocumentScreenPassesTheAccessibilityAudit` on iPhone and iPad, with a heading, a link, and a checkbox. It ignores "Label not human-readable" only on an element whose label ends in `.md`: the title is the person's file name. |

Also: the strips (`a deleted file shows its strip, and Close asks first`, `a failed save shows its strip, and Save As exports the text and opens the copy`, `a read-only file shows its strip, and Duplicate opens a copy in the app's folder`, and the document tests `a deleted file pauses the checkbox save and autosave, and keeps the text`, `a failed save marks the document failed and keeps the text`); the lists across a relaunch (`the lists come back after a relaunch`, `a file that is gone comes back missing at its old path`); the iPad shortcuts (`the tab shortcuts: Command-W, Shift-Command-brackets, Command-1 to 9`). The format bar docks above the keyboard through `MarkdownView`'s `inputAccessoryView` (plan 01).

**Self-review (deep review, in session).**

- Library bugs found by the accessibility audit, both from one cause: `UITextView(usingTextLayoutManager:)` does not run a Swift subclass's stored-property initializers, so `MarkdownUITextView`'s stored properties start as zero bits.
  - Copy wrote to a null pasteboard: the stored `UIPasteboard` was a zero pointer, so Copy on iOS did nothing. The view now keeps an optional test pasteboard and falls back to `.general` (`copy with no test pasteboard writes the general pasteboard`).
  - The checkbox accessibility elements were made new on each read, and accessibility holds elements weakly, so the audit found elements with no description. The view now keeps them in an optional dictionary (a non-optional one crashed on its zero storage).
- Other bugs found by running the app: the empty text view had no accessibility label (now the file name); `MarkdownView` did not pass first responder to its text view, so New File had no keyboard; bookmarks resolve to `/private/var/…` where the picker gives `/var/…`, so the lists kept two rows for one file (`FileListStore.key`); a checkbox save through `autosave` hung once, so it now calls `save(to:for:)`.
- Deep-review fixes, each with a test that failed first:
  - Two quick taps on a row opened the file twice: both calls passed the screen check before the first `await`, and one `UIDocument` leaked. Opens of one file now share one task (`two quick opens of a file give one screen`).
  - A row's swipe, VoiceOver, and menu action kept the index path, so after the list changed it acted on another file. It now keeps the file (`a row's action acts on its own file after the list changes`).
  - A rename did not rename the iPad tab or its "Close {name}" label (screens §3.12). Each tab's screen now reports its updates to the tabs (`a renamed file renames its tab`).
  - `DocumentSession.close` stopped the security scope on the URL it was given, not the one that started it; the session now keeps that URL (a file outside the sandbox cannot be picked in a unit test).
  - A failed save showed nothing, a deleted file was written back by the next autosave or by Close, and a read-only file had no strip: the three strips (decision 5).
  - The iOS-only strings sat in the shared `ScrollStrings` and failed the Mac coverage gate; they moved to `ScrollStrings+UIKit.swift`, which the iOS gate covers.
- Saves pause while deleted at `save(to:for:completionHandler:)`, the one call every save passes through: `close()` writes without calling `autosave(completionHandler:)`, found by a test that saw the file come back after Close.
- Concurrency: `UIDocument` is not main-actor isolated, so the file-presenter calls hop to main through `onMain(_:)` with a `nonisolated(unsafe)` local; an `@unchecked Sendable` conformance did not satisfy region isolation.
- Mutations: one-clause mutants with `scratchpad/mutate.py` (macOS, `swift test`) and its iOS twin `ios-mutate.py` (`xcodebuild test` on iPhone 18 Pro, `-only-testing` per suite). Every mutant of the final code is caught.
  - macOS run (12, `FileListStore`, `FileLists`, `copyName`): 10 caught. `missing.remove` in `removeRecent` survived and is deleted: the row is gone, and `remember` clears the flag on any later open. `missing.remove` in `remember` survived; a test now covers it (`a missing file that is back and opens is no longer missing`).
  - iOS run 1 (32, the session, document, screens, tabs, browser, and the two `MarkdownViews` fixes): 23 caught (2 by a crash), 2 skipped (ambiguous pattern), 3 did not build (an unused value; warnings are errors), 4 survived:
    - `show` re-pushed the screen on top: same stack, so a counting navigation controller now sees it (`showing the file on screen again keeps one screen of it`).
    - Closing the selected tab always selected the first tab: `closing the selected tab selects the one after it, or else the last`.
    - The `isDeleted` guard in `noteDeleted` and `finding = nil` after Find File did nothing a person sees; both are deleted.
  - iOS run 2 (10: the skipped and non-building ones in valid forms, the survivors again, the tab rename, the open task): 7 caught, 1 did not build, 2 survived. Without `defer { opening[key] = nil }` a file reopened after Close got its closed screen back: `a closed file opens again on a new screen`. The selected-tab check before `showTitle()` was redundant and is deleted.
  - iOS run 3 (2): both caught.
- Known gaps (not 2d scope): the Open and Recent rows and the session's screen key still use the old path after a rename (2e owns outside changes); the checkbox VoiceOver value says "checked/unchecked" only from plan 03; the home screen's search field has a text-clipped audit issue (the home screen audit is not a 2d test); the format bar's `.tabBar` trait makes unlabeled container elements (the audit passes).
- Lint fixes: 17 test names that began with a capital now begin lowercase; three test types over 250 lines lost tests to extension files (the strips, a missing Recent file, the hosted view); the browser's delegate conformance moved to an extension, because SwiftFormat wrapped its 122-column declaration and SwiftLint refused the brace on its own line; `check-document-types.py` writes to the streams instead of calling `print`.
- Gate (2026-11-02): every step of `just check` but the two UI-test steps passed on the committed tree with 0 warnings: Swift Testing on macOS ran 318 MarkdownCore, 136 MarkdownViews, 135 ScrollSupport, and 17 FortkeepsCards tests; coverage 100% for the three gated modules and for the iOS-only `ScrollSupport` files; the iPhone 18 Pro simulator ran 263 MarkdownViews and ScrollSupport tests (1 skipped: the timing test, which runs only with `FORTKEEPS_TIMING`); lint and format clean. `mac-app-test` and `ios-app-test` did not run on this tree: the screen was locked, and Itay chose to commit without them. Their last run passed before the strips, the deep-review fixes, and the lint fixes (all 3 iOS UI tests on iPhone 18 Pro and iPad Air 11-inch (M4), 7 Mac UI tests). Run `just mac-app-test ios-app-test` first in 2e.
