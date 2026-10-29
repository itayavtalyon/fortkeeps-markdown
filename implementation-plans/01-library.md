# 01 — Library

**Design:** [`design-logs/001-markdown-library.md`](../design-logs/001-markdown-library.md) revision 3: Product, Host interface, View settings, Modes, Features, Parse, Document model, Rendering, Tasks, Direction, Editor, Format commands, Undo, Paste, the pure image rules, HTML, the pure link rules, Accessibility, Color, and Fonts.
**Next:** [02-apps.md](02-apps.md).

## Goal

Build `MarkdownCore` and `MarkdownViews` with no file I/O and no network I/O.

## Rules

Read Design before a stage.
Build only what Design states.
When Design leaves a choice, stop.
Ask Itay with a structured question.
Do not download a file other than the Swift packages that Design names.
Copy the font files that Design names from remember-mac `design/fonts/static/` and `design/fonts/`.
When one of those files is missing, stop.
Ask Itay which file is missing.

## Quality bar

Treat warnings as errors.
Run the formatter last.
Keep `MarkdownCore` free of AppKit, UIKit, SwiftUI, `URLSession`, `FileManager`, and `FileHandle`.
Keep coverage at 100% lines and functions on `MarkdownCore`.
`MarkdownViews` has no percentage gate.

## Stages

| Stage | Name | Status | Blocked by |
|---|---|---|---|
| 1a | Package, license, fonts, colors, CI guards | Not started | — |
| 1b | Parser, features, presentation | Not started | — |
| 1c | Document model, anchor, copy text | Not started | — |
| 1d | Styler, edits, format commands, undo, byte limit | Not started | WAIT-2 (steps 5–6 only) |
| 1e | Paste, image and link classifiers, line diff, HTML policy | Not started | WAIT-1 (step 8 only: the spike tests below are written now; the policy waits on the result) |
| 1f | Views, modes, host protocol, cards, accessibility | Not started | — |

### 1a — Package, license, fonts, colors, CI guards

1. Work in the repo `fortkeeps-markdown`. Its `main` already holds `README.md` and `LICENSE`.
2. Add the README trademark line from Design.
3. Keep the MIT `LICENSE`.
4. Create the package `FortkeepsMarkdown` for macOS 15 and iOS 18.
5. Add the target `MarkdownCore`.
6. Add the target `MarkdownViews` that depends on `MarkdownCore`.
7. Add the target `FortkeepsCards` that depends on `MarkdownCore` only. It holds the Fortkeeps card fields (stage 1c). `MarkdownCore` holds no Fortkeeps-specific type.
8. Add a test target for `MarkdownCore`, one for `MarkdownViews`, and one for `FortkeepsCards`.
9. Copy the font files and `OFL.txt` that Design names.
10. Write `design/fonts/README.md` with the release tag and the SHA-256 of each file.
11. Put the Design color values in one Swift file as named constants.
12. Turn warnings into errors.
13. Add the coverage check.
14. Add the acknowledgements check.
15. Add the analytics denylist check.

Must-pass tests:

- The package builds for macOS and for iOS.
- A test fails when `MarkdownCore` imports AppKit, UIKit, or SwiftUI.
- A test fails when `MarkdownCore` imports `FortkeepsCards`, or when `FortkeepsCards` imports AppKit, UIKit, or SwiftUI.
- A test fails when `MarkdownCore` or `MarkdownViews` uses `URLSession`, `FileManager`, or `FileHandle`.
- Each color constant equals the Design value.
- Each font file matches its recorded SHA-256.
- The acknowledgements check fails when a resolved package is missing from the list.
- The denylist check fails on a fixture `Package.resolved` that contains Sentry.

### 1b — Parser, features, presentation

1. Add `MarkdownFeatures` with the seven fields and the defaults.
2. Add the Fortkeeps value as a named constant.
3. Add `MarkdownPresentation` with `titleLine` and `imageFallback`.
4. Add `swift-markdown` at the newest release tag on the day this stage starts.
5. Record that tag in Implementation Notes.
6. Commit `Package.resolved`.
7. Parse with the extensions that the true fields name.
8. Apply the GFM tag filter only when `html` is true.

Must-pass tests:

- A new `MarkdownFeatures` matches the default column.
- The Fortkeeps constant matches the Fortkeeps row.
- Defaults render a table, a task, a strike, and an autolink.
- Each false field leaves its construct as text.
- A leading `---` stays a thematic break.
- The disallowed tag names appear as text when `html` is true.
- The GFM spec tests pass with the defaults. Examples 140, 141, 142, 145, and 147 (tag filter) and 610, 614, 616, 619, and 620 (autolink) are pinned to the `swift-markdown` extension output: the test stores that output as the expected value and fails when it changes (confirmed by Itay, round 9).
- Log 010 cases 01–30 pass with the Fortkeeps value and `titleLine .hidden`.

### 1c — Document model, anchor, copy text

1. Build the block list, the heading levels, and each task's byte offset, excluding a leading BOM.
2. Build the base direction of each block.
3. Build the rendered-mode copy string for any selection.
4. Build the line-1 title rule for `titleLine .hidden`.
4a. Build the Fortkeeps card fields in `FortkeepsCards`, on top of the `MarkdownCore` model. Keep them out of `MarkdownCore`.
5. Build `MarkdownAnchor` as a `Codable` value in source byte offsets.
6. Build the map from a source offset to a rendered position and back.
7. Snap a selection on hidden syntax to the nearest content character.
8. Treat a soft break as a space or as a line break by `softBreakAsLine`.

Must-pass tests:

- A task offset points at the byte between the brackets, with and without a BOM.
- A toggle of `[ ]` gives `[x]`, and a second toggle gives `[ ]` again. A toggle of `[X]` gives `[ ]`, and a second toggle gives `[x]`, not `[X]` (MD-29, kept in round 9).
- A Hebrew block is RTL. A Latin block is LTR. A Hebrew task list puts the checkbox on the trailing edge.
- The copy of a heading, a link, a code span, and a fence matches Design. The copy has no direction marks.
- A drawn image adds no copy characters.
- A rendered-mode copy of a bulleted list gives `- ` markers. An ordered list gives `1. `, `2. `, and so on, keeping the start number.
- A task list copies as `- [ ] milk` and `- [x] milk`.
- A nested list copies with 2 spaces per bullet level and 3 spaces per ordered level.
- `FortkeepsCards` builds its fields from a `MarkdownCore` model, and `MarkdownCore` builds with `FortkeepsCards` removed.
- A source-to-rendered-to-source round trip keeps each offset that is not on hidden syntax.
- An anchor encodes and decodes to the same value.
- With `.hidden`, a tick on line 5 flips the correct byte.

### 1d — Styler, edits, format commands, undo, byte limit

1. Build the styler that returns a range and a style token for one paragraph.
2. Return the dimmed syntax tokens and the emphasis tokens.
3. Return a checkbox token, and return the raw marker when the caret is inside it.
4. Restyle the caret paragraph and the paragraph on each side.
5. Build each format command from the Design table, with toggle and per-line behavior.
6. When WAIT-2 is in Design, build those exact cases. Until then, stop after step 4 and do steps 7–11.
7. Build list continuation and the empty-item exit.
8. Build the undo-group rules.
9. Build the `maxUTF8Bytes` cut on a UTF-8 and grapheme boundary.
10. Add a release timing test for the 8 ms budget.
11. Keep that timing test out of the default test run.

Must-pass tests:

- One token test for each syntax that Design lists.
- A plain paragraph returns no syntax token.
- The caret-inside-marker case returns the raw marker.
- Each command adds the format, and a second run removes it.
- Code on two lines makes a fence.
- Each Command-K case returns the text and the caret that Design states.
- Return in `- [x] a` yields `- [ ] `.
- Return on an empty item ends the list.
- "hello world" typed with a 1 s pause, then one undo, removes "world" only.
- A paste is one undo group.
- A 70 KB paste into 60 KB with a 65,536 limit leaves at most 65,536 bytes, with no split grapheme, in one undo group.

When no Apple-silicon Mac is available, stop.
Record the chip with the 8 ms result.

### 1e — Paste, image and link classifiers, line diff, HTML policy

1. Build the paste converter for the Design table, on a hand-written HTML tokenizer.
2. Drop `script` and `style` with their text.
3. Insert the plain text when the conversion is whitespace only, or when `pasteHtml` is false.
4. Build the pure image classifier: local, remote, untitled, and refused.
5. Build the host blocklist for every form that Design lists.
6. Build the pure link classifier: browser, mail, sibling file, fragment, and none.
7. Build the line diff for Resolve.
8. HTML spike (WAIT-1). Write the spike tests below now, against a native safe-subset renderer. Policy: when they all pass, Itay records the result in Design and `html` true renders the safe subset. Until the result is in Design, `html` true shows raw HTML as text, the same as `html` false, and the stage notes record that. When a spike test cannot pass, stop and report it to Itay.
   The safe subset renders these tags natively: `b`, `strong`, `i`, `em`, `u`, `s`, `del`, `ins`, `sub`, `sup`, `code`, `kbd`, `mark`, `br`, `p`, `div`, `span`, `h1`–`h6`, `ul`, `ol`, `li`, `blockquote`, `pre`, `hr`, `a`, `img`, `details`, `summary`, `table`, `thead`, `tbody`, `tr`, `th`, `td`. The allowed attributes are `href` on `a`, `src`, `alt`, `width`, and `height` on `img`, `align` on table cells, and `open` on `details`. Every other attribute is stripped.

Must-pass tests:

- Each row of the paste table has one test.
- A `script` body does not appear.
- Escaping happens only where a character would start syntax.
- A `colspan` cell puts its content in the first cell and empty cells after it.
- A golden corpus of 20 clipboard samples converts to fixed output.
- The converter runs under a 10-minute fuzz test in CI with no crash.
- A relative path inside the directory is local.
- `../` outside the directory is refused.
- An untitled document refuses a local path.
- https is remote. http is refused.
- Each blocklist form is refused, including `100.64.0.1`, `::ffff:127.0.0.1`, `2130706433`, `0x7f.1`, and `localhost.`.
- A data URL is refused.
- A sibling `.MD` link is an in-app open.
- `#intro` resolves to the GFM slug.
- `javascript:` is none.
- The line diff of two texts gives the expected hunks, and applying all "theirs" choices gives the second text.

HTML spike tests (step 8; written now, run against the safe-subset renderer):

- Allowed tags render: `<b>x</b>`, `<em>x</em>`, `<sub>2</sub>`, `<kbd>⌘</kbd>`, `<br>`, `<details><summary>s</summary>b</details>`, and a `<table>` with `<th>` each render as their native style, with no tag characters shown.
- `<script>alert(1)</script>` shows as text (GFM tag filter). No script runs.
- `<iframe src="https://example.com"></iframe>`, `<style>p{}</style>`, `<textarea>`, `<title>`, `<xmp>`, `<noembed>`, `<noframes>`, and `<plaintext>` show as text. Nothing loads.
- `<object>`, `<embed>`, `<form>`, `<input>`, `<button>`, `<link>`, `<meta>`, `<base>`, `<svg>`, and `<math>`: only that tag turns into text; its allowed children still render.
- `<a href="https://example.com" onclick="x()">a</a>` renders the link and strips `onclick`. Every `on*` attribute (`onload`, `onerror`, `onmouseover`, any case) is stripped.
- `<a href="javascript:alert(1)">a</a>`, `JaVaScRiPt:`, `&#106;avascript:`, ` javascript:` with leading space or tab, and `vbscript:`: the link text renders and following it does nothing.
- `<img src="javascript:x">`, `<img src="data:image/png;base64,...">`, and `<img src="http://x">` follow the image rules: refused.
- `<img src="https://example.com/a.png" onerror="x()">` strips `onerror` and draws the remote-image card with no request.
- `style` and `class` attributes are stripped: `<p style="color:red" class="x">a</p>` renders a plain paragraph.
- Nested HTML: `<div><b><i>x</i></b></div>` renders bold italic. Nesting 200 levels deep renders without a crash, and depth past 64 shows the rest as text.
- Malformed HTML: an unclosed `<b>x` closes at the end of its HTML block. A stray `</i>` is dropped. Overlapping `<b><i>x</b></i>` renders `x` bold italic with no tag characters. An attribute with no closing quote turns that tag into text.
- Raw HTML inside a code span (`` `<b>x</b>` ``) and inside a fenced or indented code block is untouched: the tag characters show as code.
- With `html` false, every case above shows its source as text.

### 1f — Views, modes, host protocol, cards, accessibility

1. Define `MarkdownHost`, `ImageRequest`, `ImageResult`, `LinkActivation`, and `TextChange` from Design.
2. Keep the working text in the view. Take the initial text at creation. Replace it only through `reload(text:)`. Give the protocol no default implementations.
3. Build one Mac view and one iOS view on TextKit 2 with the three modes.
4. Apply a `mode` or `isEditable` change in place.
5. Keep the anchor on a mode switch, and move VoiceOver focus to it.
6. Map the style tokens to the Design fonts, sizes, and colors.
7. Scale with Dynamic Type on iOS.
8. Build the image cards for each `ImageResult`. A `.refused` result draws the "Image can't be shown" card with `imageFallback .text`, and the `Image: {alt}` link (or `Image` with no alt) with `.link`. A card has a title and at most one reason line (one per `ImageFailure`); its accessibility label is `Image can't be shown. {reason}`, plus ` Alt text: {alt}` when there is alt text. Use the FINAL strings in Design › Copy › Final image strings (approved 2026-10-29).
8a. Call `activateImage(_:)` when the person clicks a `.remoteNotLoaded`, `.failed`, or `.needsAccess` card, or presses Return or Space on it while it is focused. Never fetch from `image(for:)`. Give the remote card the action `Load Image` (Mac) / `Load image` (iOS) and the VoiceOver hint `Loads the image from {host}.`, or `Shows the image from this file.` for a local file (FINAL, 2026-10-29).
8b. In the editor, keep the image source line fully visible and draw the card or the loaded thumbnail under it. Never collapse the source.
8c. Put a code block or table wider than the column in its own sideways-scrolling box with the 16 pt edge fade, per Design › Rendering › Wide blocks. Wrap prose.
9. Cancel the image task when the view discards a block.
10. Build the format bar for Mac and iOS. The Heading button opens a menu of Heading 1, Heading 2, Heading 3, and Body. On Mac, Control-F6 moves focus into the bar and Esc returns it to the text.
11. Wire the Design shortcuts.
12. Report every change with its reason.
13. Expose the accessibility elements from the model. Expose each heading's level. Put links, checkboxes, and image cards in the Tab order in reading order. Return opens a focused link. Space toggles a focused checkbox. (Launch blockers.)
14. Turn smart quotes and smart dashes off.
15. Dim checked task text with `text3` in the editor as well as in `.rendered`.
16. After Undo or Redo, put the caret at the end of the restored text.
17. Indent list and quote content 22 pt per level.
18. On iOS, underline every link in every mode.
19. On iOS, show a gif's first frame with the play action when Auto-Play Animated Images is off.

Must-pass tests:

- A view test double records an image request for a near block and a cancellation for a discarded block.
- A view test double records `open(_:)` on Command-click in `.editor` and on click in `.editorLocked`, and records nothing on a plain click in `.editor`.
- A checkbox click reports `checkbox`. In `.editorLocked`, the checkbox reports not enabled.
- A switch from editor to rendered to editor keeps the caret offset and the first visible line within one line. Undo restores the pre-switch edit.
- `reload(text:)` clears Undo and reports `reload`.
- The format bar buttons report the same text as the shortcuts.
- The checkbox accessibility value is `done` or `not done`.
- The editor spellchecks. Rendered mode does not.
- `~~` is dimmed only when `strikethrough` is true.
- Copy separates blocks with one newline.
- Select All and Copy on a 2 MB document equal the model copy string.
- With Reduce Motion on, a gif reports not animating. With iOS Auto-Play Animated Images off, a gif reports not animating.
- A view test double records `activateImage(_:)` on a click and on Return or Space on a focused remote card, and records zero `activateImage(_:)` calls and no fetch from `image(for:)` alone.
- A `.refused` result draws the card with `.text`, and `Image: {alt}` with `.link`; an empty alt gives `Image`.
- The card accessibility label equals the title and the reason line together.
- The editor shows the full `![alt](url)` line with the thumbnail under it after `.image`.
- A 2,000 pt wide code block and table scroll sideways in their box; the page does not scroll sideways; a long paragraph wraps. The edge fade shows only on a side with hidden content.
- Keyboard: Tab visits links, checkboxes, and image cards in reading order; Return opens a link; Space toggles a checkbox; Control-F6 focuses the Mac format bar and Esc returns to the text.
- Each Mac heading reports its level to accessibility.
- The Heading button menu lists Heading 1, Heading 2, Heading 3, and Body.
- A checked task in the editor uses `text3`, and its contrast on `pane` is at least 4.5:1 in light and dark.
- After Undo, the caret is at the end of the restored text.
- A nested list item and a nested quote indent 22 pt per level.
- On iOS, a link is underlined with no hover or focus.

## Handover

When the stage definition of done holds except the second review, commit the stage.
Write `.claude/REVIEW_REQUEST` with the stage name, this plan path, and the commit.
Stop.
Do not start the next stage.
