# 004 - Fortkeeps Scroll plan 02 decisions

Revision 3, 2026-11-01 (Round 3 added for stage 2c). Revision 2, 2026-11-01 (Round 2 added for stage 2b). Revision 1, 2026-10-31. Written by the plan 02 implementer from Itay's answers to the plan 02 grill questions. Status: Design.
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

## Design

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
