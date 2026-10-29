# 03 — Scroll decisions (log 002)

**Design:** [`design-logs/002-scroll-decisions.md`](../design-logs/002-scroll-decisions.md) revision 1, which amends [`001-markdown-library.md`](../design-logs/001-markdown-library.md). Where they differ, log 002 wins.
**Amends:** plan 01 and plan 02, which stay as written. Each stage below names the plan 01 or plan 02 stage it adds to. Build each item inside that stage, on that stage's branch, and follow that plan's Rules, Quality bar, and Handover.

## Goal

Build the decisions of log 002 in the library and the apps.

## Rules

Read log 001 and log 002 Design before a stage.
Build only what Design states.
When Design leaves a choice, stop.
Ask Itay with a structured question.
Do not build a step marked PROPOSED in log 002 until Itay approves it and a new log records it.

## Stages

| Stage | Name | Adds to | Status | Blocked by |
|---|---|---|---|---|
| 3a | Package target, pinned spec examples, MD-29, list copy | Plan 01 stages 1a, 1b, 1c | Not started | — |
| 3b | HTML spike tests | Plan 01 stage 1e step 8 | Not started | WAIT-1 (the policy only; the tests are written now) |
| 3c | Views: images, wide blocks, keyboard, VoiceOver, editor | Plan 01 stage 1f | Not started | — |
| 3d | Apps: image activation, signing deferral, copy terms, iPhone home screen | Plan 02 stages 2b, 2c, 2d, 2f | Not started | WAIT-3 (string tests), WAIT-7 (steps 1–6 of the home screen) |

### 3a — Package target, pinned spec examples, MD-29, list copy

1. (1a) Add the target `FortkeepsCards` that depends on `MarkdownCore` only. It holds the Fortkeeps card fields. `MarkdownCore` holds no Fortkeeps-specific type.
2. (1a) Add a test target for `FortkeepsCards`.
3. (1c) Build the Fortkeeps card fields in `FortkeepsCards`, on top of the `MarkdownCore` model. Keep them out of `MarkdownCore`.
4. (1c) Build the rendered-mode list copy with real Markdown markers.

Must-pass tests:

- A test fails when `MarkdownCore` imports `FortkeepsCards`, or when `FortkeepsCards` imports AppKit, UIKit, or SwiftUI.
- (1b) The GFM spec tests pass with the defaults. Examples 140, 141, 142, 145, and 147 (tag filter) and 610, 614, 616, 619, and 620 (autolink) are pinned to the `swift-markdown` extension output: the test stores that output as the expected value and fails when it changes.
- (1c) A toggle of `[ ]` gives `[x]`, and a second toggle gives `[ ]` again. A toggle of `[X]` gives `[ ]`, and a second toggle gives `[x]`, not `[X]` (MD-29). This replaces plan 01 stage 1c's "a second toggle restores the text".
- A rendered-mode copy of a bulleted list gives `- ` markers. An ordered list gives `1. `, `2. `, and so on, keeping the start number.
- A task list copies as `- [ ] milk` and `- [x] milk`.
- A nested list copies with 2 spaces per bullet level and 3 spaces per ordered level.
- `FortkeepsCards` builds its fields from a `MarkdownCore` model, and `MarkdownCore` builds with `FortkeepsCards` removed.

### 3b — HTML spike tests (plan 01 stage 1e step 8)

1. Write the spike tests below now, against a native safe-subset renderer with the tags and attributes of log 002 › HTML.
2. Policy: when they all pass, Itay records the result in a new log and `html` true renders the safe subset. Until the result is in Design, `html` true shows raw HTML as text, the same as `html` false, and the stage notes record that.
3. When a spike test cannot pass, stop and report it to Itay.

HTML spike tests (written now, run against the safe-subset renderer):

1. Allowed tags render: `<b>x</b>`, `<em>x</em>`, `<sub>2</sub>`, `<kbd>⌘</kbd>`, `<br>`, `<details><summary>s</summary>b</details>`, and a `<table>` with `<th>` each render as their native style, with no tag characters shown.
2. `<script>alert(1)</script>` shows as text (GFM tag filter). No script runs.
3. `<iframe src="https://example.com"></iframe>`, `<style>p{}</style>`, `<textarea>`, `<title>`, `<xmp>`, `<noembed>`, `<noframes>`, and `<plaintext>` show as text. Nothing loads.
4. `<object>`, `<embed>`, `<form>`, `<input>`, `<button>`, `<link>`, `<meta>`, `<base>`, `<svg>`, and `<math>`: only that tag turns into text; its allowed children still render.
5. `<a href="https://example.com" onclick="x()">a</a>` renders the link and strips `onclick`. Every `on*` attribute (`onload`, `onerror`, `onmouseover`, any case) is stripped.
6. `<a href="javascript:alert(1)">a</a>`, `JaVaScRiPt:`, `&#106;avascript:`, ` javascript:` with leading space or tab, and `vbscript:`: the link text renders and following it does nothing.
7. `<img src="javascript:x">`, `<img src="data:image/png;base64,...">`, and `<img src="http://x">` follow the image rules: refused.
8. `<img src="https://example.com/a.png" onerror="x()">` strips `onerror` and draws the remote-image card with no request.
9. `style` and `class` attributes are stripped: `<p style="color:red" class="x">a</p>` renders a plain paragraph.
10. Nested HTML: `<div><b><i>x</i></b></div>` renders bold italic. Nesting 200 levels deep renders without a crash, and depth past 64 shows the rest as text.
11. Malformed HTML: an unclosed `<b>x` closes at the end of its HTML block. A stray `</i>` is dropped. Overlapping `<b><i>x</b></i>` renders `x` bold italic with no tag characters. An attribute with no closing quote turns that tag into text.
12. Raw HTML inside a code span (`` `<b>x</b>` ``) and inside a fenced or indented code block is untouched: the tag characters show as code.
13. With `html` false, every case above shows its source as text.

### 3c — Views: images, wide blocks, keyboard, VoiceOver, editor (plan 01 stage 1f)

1. Add `activateImage(_:)` and `ImageActivation` to `MarkdownHost` from log 002 Design.
2. Build the image cards for each `ImageResult`. A `.refused` result draws the "Image can't be shown" card with `imageFallback .text`, and the `Image: {alt}` link (or `Image` with no alt) with `.link`. A card has a title and at most one reason line (one per `ImageFailure`); its accessibility label is `Image can't be shown. {reason}`, plus ` Alt text: {alt}` when there is alt text. Use the FINAL strings in log 002 › Copy › Final image strings.
3. Call `activateImage(_:)` when the person clicks a `.remoteNotLoaded`, `.failed`, or `.needsAccess` card, or presses Return or Space on it while it is focused. Never fetch from `image(for:)`. Give the remote card the action `Load Image` (Mac) / `Load image` (iOS) and the VoiceOver hint `Loads the image from {host}.`, or `Shows the image from this file.` for a local file.
4. In the editor, keep the image source line fully visible and draw the card or the loaded thumbnail under it. Never collapse the source.
5. Put a code block or table wider than the column in its own sideways-scrolling box with the 16 pt edge fade, per log 002 › Rendering › Wide blocks. Wrap prose.
6. While a wide block is focused, arrow keys scroll 40 pt and Option+arrow jumps to the start or end. Put the block in the Tab order only when it overflows. Esc returns focus to the text. Expose it to VoiceOver as a scroll area. Draw a focus ring with at least 3:1 contrast.
7. The Heading button opens a menu of Heading 1, Heading 2, Heading 3, and Body. On Mac, Control-F6 moves focus into the bar and Esc returns it to the text.
8. Expose each heading's level. Put links, checkboxes, and image cards in the Tab order in reading order. Return opens a focused link. Space toggles a focused checkbox. (Launch blockers.)
9. Set the checkbox accessibility value to "checked" or "unchecked".
10. Dim checked task text with `text3` in the editor as well as in `.rendered`.
11. After Undo or Redo, put the caret at the end of the restored text.
12. Indent list and quote content 22 pt per level.
13. On iOS, underline every link in every mode.
14. On iOS, show a gif's first frame with the play action when Auto-Play Animated Images is off.

Must-pass tests:

- With iOS Auto-Play Animated Images off, a gif reports not animating.
- A view test double records `activateImage(_:)` on a click and on Return or Space on a focused remote card, and records zero `activateImage(_:)` calls and no fetch from `image(for:)` alone.
- A `.refused` result draws the card with `.text`, and `Image: {alt}` with `.link`; an empty alt gives `Image`.
- The card accessibility label equals the title and the reason line together.
- The editor shows the full `![alt](url)` line with the thumbnail under it after `.image`.
- A 2,000 pt wide code block and table scroll sideways in their box; the page does not scroll sideways; a long paragraph wraps. The edge fade shows only on a side with hidden content.
- A focused overflowing block scrolls 40 pt per arrow key and to its start or end with Option+arrow. A block that fits is not in the Tab order. Esc returns focus to the text. VoiceOver reports a scroll area. The focus ring contrast is at least 3:1.
- Keyboard: Tab visits links, checkboxes, and image cards in reading order; Return opens a link; Space toggles a checkbox; Control-F6 focuses the Mac format bar and Esc returns to the text.
- Each Mac heading reports its level to accessibility.
- The checkbox accessibility value is "checked" or "unchecked".
- The Heading button menu lists Heading 1, Heading 2, Heading 3, and Body.
- A checked task in the editor uses `text3`, and its contrast on `pane` is at least 4.5:1 in light and dark.
- After Undo, the caret is at the end of the restored text.
- A nested list item and a nested quote indent 22 pt per level.
- On iOS, a link is underlined with no hover or focus.

### 3d — Apps: image activation, signing deferral, copy terms, iPhone home screen (plan 02)

Image loader (2b):

1. Return `.remoteNotLoaded` until the view calls `activateImage(_:)` for that card, or the person chooses Load All Images in This Document. Fetch only after that call.
2. On a failed Reload Image: if the old image is gone, show the standard card; if it is still showing, keep it and show the status line `Couldn't reload this image. {reason}` under it, announced to VoiceOver, until the next reload.
3. An untitled, unsaved document shows the local-image card `Save the document to show local images.`

Signing (2c, 2d):

4. Use the bundle ID `app.fortkeeps.scroll` on Mac and iOS. Build unsigned, for tests and the simulator only. Signing and notarization are deferred until Itay buys the Apple Developer membership (roadmap V1-43); do not add a team ID or a provisioning profile.

Copy terms (2c, 2d, 2f):

5. Name the create command `New File` in both the sidebar and the File menu, on every platform.
6. The folder-access prompt may say that Scroll reads and writes only the folder you choose (final wording from Story Weaver, WAIT-3).

iPhone home screen (2d). Steps 7–12 are PROPOSED in log 002 and wait on WAIT-7:

7. One scrolling list with an Open section, then a Recent section. Hide the Open section when nothing is open.
8. Keep a file in one section only: closing moves it to the top of Recent; opening from Recent moves it to Open. Recent holds 20 files, newest first.
9. Each row shows the file name, the parent folder in smaller text, and the last-opened time like `Today at 9:15`.
10. Swipe actions `Close` (Open) and `Remove from Recent` (Recent); neither deletes the file. Each is also in the VoiceOver actions menu and the long-press menu.
11. Toolbar `Browse` (Files picker) and New File; a search field at the top filters both sections.
12. Section titles are headings; rows grow with Dynamic Type; the folder line wraps. Both lists persist security-scoped bookmarks.

Decided (build now):

13. Strings: empty `Files you open will show up here.` with the Browse button below; no search results `No files match "<query>".`; the Recent heading `Recent`.
14. A Recent row whose bookmark can't resolve is dimmed with the note `Can't find this file. It may have been moved or deleted.` A tap opens a sheet titled `Can't find "<name>"` with `Find File…` (Files picker; on success the row keeps its place), `Remove from Recent`, and `Cancel`. Its VoiceOver label is `<name>, can't find this file`.

Must-pass tests:

- `activateImage(_:)` on a remote card starts exactly one fetch; `image(for:)` alone starts none.
- Launch blockers (keyboard and VoiceOver, 2c): a UI test with Full Keyboard Access tabs through links, checkboxes, and image cards in reading order; Return opens a link; Space toggles a checkbox; Control-F6 enters the format bar and Esc returns. Each heading exposes its level.
- iOS typing undo (UI test, 2d): type "hello world" with a 1 s pause before "world", then shake-to-undo or the three-finger undo gesture removes "world" only, and the caret is at the end of the restored text.
- With Auto-Play Animated Images off, a gif shows frame 1 with the play action. Every link is underlined.
- The File menu and the sidebar both read `New File`.
- An untitled document with a local image shows `Save the document to show local images.`
- A Recent file whose bookmark fails shows the dimmed row, the note, the sheet with its three buttons, and the VoiceOver label above. `Find File…` keeps the row's place. `Remove from Recent` leaves the file on disk.
- (After WAIT-7) Open and Recent never hold the same file; Recent caps at 20; swipe actions never delete a file.

## Handover

Follow the Handover of plan 01 or plan 02 for the stage this work is added to.
