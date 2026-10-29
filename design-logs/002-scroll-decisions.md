# 002 - Fortkeeps Scroll decisions of 2026-10-26 to 2026-10-29

Revision 1, 2026-10-29. Written from Itay's decisions: the 2026-10-26 decisions (formerly PR #3), the 2026-10-27/29 review answers (formerly PR #4, round 9), and the team-room decisions of 2026-10-29. Status: Design.
Log 001 and plan 01 stay as written (log immutability). This log amends or clarifies them. Each decision names the log 001 or plan 01 section it amends. Where this log and log 001 differ, this log wins.
Work items are in plan 03 (`implementation-plans/03-scroll-decisions.md`).
Items marked **PROPOSED** wait for Itay's OK and are not yet decided.

## Background

Log 001 (revision 3, 2026-10-25) designs the FortkeepsMarkdown library and Fortkeeps Scroll.
Since then, Itay answered contradictions and roadmap items (2026-10-26), answered the Scroll review (2026-10-27 to 2026-10-29), and the team room settled more items on 2026-10-29.
Two pull requests (#3 and #4) put these answers into log 001 and plans 01 and 02 directly. Itay decided that log 001 and plan 01 stay untouched, so the decisions live here instead.

## Problem

Log 001 leaves these open or states them in a way that the decisions changed: the screens-file self-conflicts, the bundle ID prefix, refused images and image clicks, the editor image line, wide blocks, keyboard and VoiceOver access, list copy, the Fortkeeps card target, the image strings, the HTML policy, WAIT-5, signing, and several copy terms. The iPhone has no home screen design beyond the system document browser.

## Questions and Answers

### Round 1 (2026-10-26: Itay, contradictions and roadmap items)

Amends log 001 › Design › Windows and chrome (the screens-file conflict rules), Design › Product (bundle ID), Round 6 (the price/privacy answer), and Known Limitations › Waiting items.

- **Q: Do the three self-conflicts in the screens file resolve as log 001 says?**
  A: Yes. Show Sidebar is ⌃⌘S per the §3.18 menu table, and ⌥⌘O focuses the Outline. The iPad format bar has all 8 buttons of §3.6a. A link click follows Q2: click places the caret, ⌘-click follows, in Lock a click follows, and an iPhone tap places the caret with a long press showing Open Link.
- **Q: What is the bundle ID prefix (WAIT-6, roadmap V1-44)?**
  A: `app.fortkeeps.*` everywhere. Fortkeeps Scroll is `app.fortkeeps.scroll` on Mac and iOS.
- WAIT-5 reopened 2026-10-26: Android and web app are in phase one; see roadmap V1-42.

### Round 2 (2026-10-27 to 2026-10-29: Itay, the Scroll review answers)

Rounds of log 001 stay as written. Where an answer here differs from an earlier one, this round wins and Design states the winner.

- **Q: What does a refused image show?** (amends log 001 › Host interface `.refused`, View settings `imageFallback`, screens §3.8)
  A: It follows `imageFallback`. With `.text`, the "Image can't be shown" card. With `.link`, the link `Image: {alt}`, or `Image` when the alt text is empty. The Design text that drew the card for every `.refused` is corrected.
- **Q: How does the host learn that the person clicked an image card?** (amends log 001 › Host interface)
  A: A separate host method, distinct from `image(for:)`. A click is consent to fetch. The protocol has no default methods, so the method is required.
- **Q: How does a drawn image show in the editor?** (amends log 001 › Editor, Images, screens §3.8)
  A: The source stays on its own line, fully visible, with a thumbnail under it once the image is loaded. The syntax does not collapse. This replaces the "collapses to one dimmed line" rule.
- **Q: How do wide code blocks and tables behave?** (amends log 001 › Rendering)
  A: Each scrolls sideways in its own box, with an edge fade. Prose wraps. The box scrolls by trackpad, keyboard, and VoiceOver's three-finger swipe.
- **Q: Is keyboard access a launch blocker?** (amends log 001 › Accessibility)
  A: Yes. Tab moves through links, checkboxes, and image cards in reading order. Return opens a focused link. Space toggles a focused checkbox. Control-F6 moves into the Mac format bar, and Esc returns to the text.
- **Q: Is VoiceOver a launch blocker?** (amends log 001 › Accessibility)
  A: Yes. The Mac exposes heading levels. iOS respects the Auto-Play Animated Images setting.
- **Q: Are iOS links underlined?** (amends log 001 › Rendering)
  A: Always, since iOS has no hover.
- **Q: What does copying a rendered list give?** (amends log 001 › Rendering, copy rules)
  A: Real Markdown markers (`- `, `1. `). Task items copy as `- [ ] milk` and `- [x] milk`. Nested items keep their indentation.
- **Q: Where is the iOS typing-undo check?**
  A: In plan 02's UI tests (the test itself is in plan 03).
- **Q: Which output do the 10 GFM spec examples that touch the tag filter and autolink pin to?** (clarifies plan 01 stage 1b)
  A: Examples 140, 141, 142, 145, and 147 (tag filter) and 610, 614, 616, 619, and 620 (autolink) stay pinned to the extension output. Itay confirmed the earlier agent call.
- **Q: Does the MD-29 toggle change?** (clarifies plan 01 stage 1c)
  A: No. `[X]` becomes a space, and a second toggle gives `[x]`. A second toggle does not restore `X`. The remember-mac log 010 conformance README says it restores the original bytes; that README is corrected in remember-mac (follow-up, not in this repo).
- **Q: Where do the Fortkeeps card fields live?** (amends log 001 › Fortkeeps later, plan 01 stages 1a and 1c)
  A: They are still built in stage 1c, but in their own target `FortkeepsCards` in this package, not in `MarkdownCore`. The core stays generic. This confirms the earlier agent call, amended.
- **Q: Are the stage 1f choices kept?** (clarifies plan 01 stage 1f)
  A: Yes. The Heading button opens a menu of Heading 1, Heading 2, Heading 3, and Body. Checked tasks are dimmed in the editor too, and the dimmed text meets 4.5:1 contrast. After Undo, the caret goes to the end of the restored text. Indent is 22 pt per list or quote level.
- **Q: Which image strings go to Story Weaver?** (amends log 001 › Copy, WAIT-3)
  A: The copy in Design › Copy › Final image strings. Story Weaver approved it as final on 2026-10-29; all WAIT-3 image strings are settled.
- **Q: What is the raw-HTML policy?** (amends log 001 › HTML, WAIT-1)
  A: Render a safe subset if the spike tests in plan 03 stage 3b pass. The spike result still closes WAIT-1.
- **Q: Was the bundle-ID answer of log 001 round 6 tied to the right roadmap item?**
  A: No. It is V1-44, not V1-43. Log 001 round 6 ("An `app.fortkeeps.` bundle ID after V1-43") is corrected to V1-44.
- **Q: Where does Fortkeeps' phone code live (WAIT-5, roadmap V1-42)?**
  A: Answer A. The Apple apps (Mac, iPhone, iPad) are one multiplatform SwiftUI app in remember-mac. Android is a separate native repo (Kotlin and Jetpack Compose). The web app is in fortkeeps-cloud (HTML and vanilla JS). They share the core through the C engine `libremember` and the open sync protocol. WAIT-5 is closed.
- **Q: When is the Apple Developer membership bought (roadmap V1-43)?**
  A: Late: "when most of the development is done and all that's left depends on getting the membership". Scroll signing in plan 02 stages 2c and 2d is deferred until then.

### Round 3 (2026-10-29: the team room)

- **Q: How does the keyboard scroll a wide code block or table?** (clarifies Round 2 wide blocks and Design › Wide blocks)
  A: Arrow keys scroll 40 pt and Option+arrow jumps to the start or end, only while the block is focused. The block joins the Tab order only when it overflows. Esc returns to the text. VoiceOver presents it as a scroll area. The focus ring needs at least 3:1 contrast.
- **Q: Which copy terms are fixed?** (amends log 001 › Windows and chrome, Tasks, Images, Files, and screens §3.1, §3.2, §3.18)
  A: The menu command is `New File` everywhere (not New Document), in both the sidebar and the File menu. The VoiceOver checkbox state is "checked / unchecked". The folder-access prompt may say plainly that Scroll reads and writes only the folder you choose (true because Scroll is sandboxed and uses security-scoped access). In an untitled, unsaved document local images can't be shown (no base folder), and the card says `Save the document to show local images.`
- **Q: What does the iPhone home screen show?** (amends log 001 › Windows and chrome, "On iOS, the launch screen is the system document browser", for iPhone)
  A: Decided by Itay: both open files and recent files. The detailed layout (Interface's layout, agreed by Story Weaver) is **PROPOSED**, awaiting Itay's OK; see Design › iPhone home screen. The strings are decided.
- **Q: What does a Recent file that can't be found show?**
  A: The row is dimmed with the note `Can't find this file. It may have been moved or deleted.` Tapping it opens a sheet titled `Can't find "<name>"` with `Find File…`, `Remove from Recent`, and `Cancel`. VoiceOver label: `<name>, can't find this file`.
- **Q: Do the launch accessibility requirements apply only to Scroll?**
  A: No. They apply from day one to every app, web app and site.
- **Q: Does Scroll get the Archive shortcut (⌃⌘A)?**
  A: No. Scroll has no Archive command. That decision belongs to the Fortkeeps app (remember log 018, V1-12).

## Design

### Product and signing (amends log 001 › Product, Round 6)

The bundle ID prefix is `app.fortkeeps.` everywhere (roadmap V1-44, WAIT-6, resolved by Itay 2026-10-26). The bundle ID of Fortkeeps Scroll is `app.fortkeeps.scroll` for Mac and iOS.
Round 6 of log 001 reads "after V1-43"; the correct item is V1-44.
Signing, notarization, TestFlight, and the App Store for Fortkeeps Scroll wait until Itay buys the Apple Developer membership (roadmap V1-43: "when most of the development is done and all that's left depends on getting the membership"). Until then, plan 02 stages 2c and 2d build unsigned, for tests only.

### Screens-file conflicts (amends log 001 › Windows and chrome)

These rules are confirmed by Itay 2026-10-26. They win over the screens file `001-markdown-library-screens.md`, which stays as written:
- The §3.18 menu table wins over other shortcut mentions. Show Sidebar is Control-Command-S. Option-Command-O focuses the Outline (screens §3.4 reads ⌃⌘1; that is superseded).
- The iPad format bar has the eight buttons of §3.6a, not the three of §3.19.
- A link click follows the Links section of log 001 (Q2): a click places the caret, Command-click follows, in Lock a click follows, and an iPhone tap places the caret with a long press showing Open Link. Screens §3.3 "Interactions" is read this way.

### Host interface (amends log 001 › Host interface)

A new required method joins `MarkdownHost`:

| Method | When | Thread |
|---|---|---|
| `func activateImage(_ activation: ImageActivation)` | The person clicks an image card, or presses Return or Space on a focused card, or chooses the card's action. | Main actor. |

`.refused`: with `imageFallback .text`: the "Image can't be shown" card, with no button. With `imageFallback .link`: the link `Image: {alt}`, or `Image` when the alt is empty.

`activateImage(_:)` is the "person clicked" event. It is separate from `image(for:)`, which only asks for the current state.
A click is consent to fetch. The host fetches only after `activateImage(_:)` (or Load All Images in This Document), never because of `image(for:)`.
`ImageActivation` has `destination: String`, `documentURL: URL?`, and `card`: the `ImageResult` case the card showed (`.remoteNotLoaded`, `.failed`, or `.needsAccess`).
The view calls `activateImage(_:)` only for those three cards. A `.loading` card, a `.refused` card, and an `Image: {alt}` link do not call it. The link calls `open(_:)`.
After `activateImage(_:)`, the host returns `.loading` from `image(for:)` and calls `MarkdownView.refreshImage(destination:)` when the result changes.

### View settings (amends log 001 › View settings)

- `imageFallback`: `.text` or `.link`. It decides what a `.refused` result draws. `.text` draws the "Image can't be shown" card. `.link` draws `Image: {alt}` as a link element that calls `open(_:)`; with an empty alt the link text is `Image`.

### Rendering (amends log 001 › Rendering)

A code block scrolls horizontally in its own box (see Wide blocks).
A link uses `accent`. On Mac, it underlines on hover or focus. On iOS, a link is always underlined, since iOS has no hover. This holds in every mode.
A wide table scrolls horizontally in its own box (see Wide blocks).

Wide blocks: a code block or a table wider than the text column scrolls sideways in its own box. The page itself never scrolls sideways. Prose, headings, lists, and quotes wrap.
The box shows a 16 pt edge fade from `pane` on each side that has hidden content. The fade hides when that side is at its end.
The box scrolls with a trackpad or mouse sideways scroll, and with VoiceOver's three-finger swipe left and right.
In `.editor`, moving the caret inside the box scrolls it to keep the caret visible. In `.rendered` and `.editorLocked`, a box with hidden content is a scroll area that Full Keyboard Access can focus; Left and Right Arrow scroll it by 40 pt, and Option-Left and Option-Right scroll it to the start and end.
Keyboard scrolling (Round 3): arrow keys scroll 40 pt and Option+arrow jumps to the start or end, only while the block is focused. The block joins the Tab order only when it overflows. Esc returns to the text. VoiceOver presents it as a scroll area. The focus ring needs at least 3:1 contrast.

Copy in `.rendered` mode, added to log 001's copy rules:
A list item copies with a real Markdown marker: `- ` for a bulleted item and `1. ` (its own number) for an ordered item.
A task item copies as `- [ ] milk` or `- [x] milk`.
A nested item keeps its indentation: 2 spaces per level under a bullet, 3 spaces under an ordered item, as in the paste map.

### Tasks (amends log 001 › Tasks)

A checked item's words use `text3`, in `.rendered` and in the editor. `text3` meets 4.5:1 on `pane` in both appearances (6.4:1 dark, 5.9:1 light). Increase Contrast maps it to `text2`.
List and quote content indents 22 pt per level.
The checkbox accessibility value is "checked" or "unchecked" (Round 3). This replaces `done` / `not done` of log 001 Round 6, Tasks, and Verification Criteria 19.
MD-29 is unchanged: a toggle of `[X]` gives a space, and a second toggle gives `[x]`.

### Editor (amends log 001 › Editor)

The `![alt](url)` source of an image always stays visible on its own line, styled as syntax. It never collapses. Once the result is `.image`, a thumbnail draws under that line, at the size rules of Images. Before that, the matching card draws under the line.
This replaces "When an image draws, its `![alt](url)` source collapses to one dimmed line while the caret is outside it." and the screens §3.8 collapse question.

### Format commands (amends log 001 › Format commands)

The Heading button opens a menu of Heading 1, Heading 2, Heading 3, and Body. Each menu item performs that command.
On Mac, Control-F6 moves keyboard focus from the text into the format bar, showing it if it is hidden by typing. Tab and the arrow keys move between buttons. Esc returns focus to the text at the same selection.

### Undo (amends log 001 › Undo)

After Undo or Redo, the caret goes to the end of the restored text, with no selection.

### Images (amends log 001 › Images)

The app returns `.remoteNotLoaded(host)` until the view calls `activateImage(_:)` for that card (a click, or Return or Space on the focused card).
Reload Image in the context menu fetches a fresh copy with the same rules and replaces the entry. On failure the old copy stays. If the old image is gone, the standard card shows: `Image can't be shown` plus the reason line. If the old image is still showing, the image stays and a status line under it (not a toast) reads `Couldn't reload this image. {reason}`, where {reason} is one of the four final reasons; the line is announced to VoiceOver and stays until the next reload. (FINAL, 2026-10-29)
The editor does not draw an image whose result is not `.image`. It draws what `.rendered` draws for that result (the card, or the `Image: {alt}` link), under the source line.
Failed: the card stays with the title "Image can't be shown", one of the four final reason lines under it (too large, timed out, unsupported format, network error; Copy › Final image strings), and **Try Again**.
Refused by rules (private host, SVG, data URL): follows `imageFallback`. `.text`: the "Image can't be shown" card, no button; it shows the host's reason line if the host gives one, otherwise the title alone. `.link`: the link "Image: {alt}", or "Image" with no alt.
An untitled, unsaved document has no base folder, so local images can't be shown. Its card says `Save the document to show local images.` (Round 3; replaces the DRAFT hint "Save the file to show local images.").

### HTML (amends log 001 › HTML, WAIT-1)

`html` true: WAIT-1. The policy is a native safe subset if the spike tests of plan 03 stage 3b pass. If they fail, the HTML stays as text and a new log decides. The test result goes into a new log before the HTML policy is built.
The safe subset renders these tags natively: `b`, `strong`, `i`, `em`, `u`, `s`, `del`, `ins`, `sub`, `sup`, `code`, `kbd`, `mark`, `br`, `p`, `div`, `span`, `h1`–`h6`, `ul`, `ol`, `li`, `blockquote`, `pre`, `hr`, `a`, `img`, `details`, `summary`, `table`, `thead`, `tbody`, `tr`, `th`, `td`. The allowed attributes are `href` on `a`, `src`, `alt`, `width`, and `height` on `img`, `align` on table cells, and `open` on `details`. Every other attribute is stripped.

### Files and folder access (amends log 001 › Windows and chrome, screens §3.2 and §3.18)

The command that creates a file is `New File` everywhere, in both the sidebar and the File menu (not New, not New Document).
The folder-access prompt may say plainly that Scroll reads and writes only the folder you choose. This is true because Scroll is sandboxed and uses security-scoped access.

### iPhone home screen (amends log 001 › Windows and chrome, iOS launch screen, for iPhone)

Decided (Itay): the iPhone home screen shows both open files and recent files.

**PROPOSED, awaiting Itay's OK** (Interface's layout, agreed by Story Weaver):
- One scrolling list with two sections, Open first and then Recent.
- When nothing is open, the Open section is hidden entirely.
- A file is never in both sections: closing moves it to the top of Recent, and opening from Recent moves it to Open.
- Recent shows 20 files, newest first.
- Each row has the file name, the parent folder in smaller text, and the last-opened time like `Today at 9:15`.
- Swipe actions are `Close` on Open rows and `Remove from Recent` on Recent rows, and neither ever deletes the file.
- The toolbar has a `Browse` button (Files picker) and New File, and a search field at the top filters both sections.
- Both section titles are real headings, every swipe action is also in the VoiceOver actions menu and the long-press menu, rows grow with Dynamic Type, and the folder line wraps.
- Both lists persist security-scoped bookmarks so files reopen without asking again.

Strings (decided): when both lists are empty `Files you open will show up here.` with the Browse button below; a search with no results `No files match "<query>".`; the Recent section heading `Recent`.

Missing Recent file (the bookmark can't resolve), decided:
- The row is dimmed with the note `Can't find this file. It may have been moved or deleted.`
- Tapping it opens a sheet titled `Can't find "<name>"` with `Find File…` (opens the Files picker to point to it again, keeping its place in the list), `Remove from Recent`, and `Cancel`.
- VoiceOver label: `<name>, can't find this file`.

### Accessibility (amends log 001 › Accessibility)

Keyboard access and VoiceOver are launch blockers. Fortkeeps Scroll does not ship until each rule below passes. The launch accessibility requirements apply from day one to every app, web app and site.

- A heading exposes its level, on Mac and iOS (`accessibilityHeading` level 1–6 on Mac).
- Tab moves through links, checkboxes, and image cards in reading order, in every mode. Shift-Tab moves back.
- Return opens a focused link.
- Space toggles a focused checkbox.
- On Mac, Control-F6 moves into the format bar, and Esc goes back to the text.
- On iOS, a gif follows the Auto-Play Animated Images setting (see Images).
- A wide block that overflows is in the Tab order, is a scroll area to VoiceOver, and has a focus ring of at least 3:1 contrast.

### Fortkeeps later (amends log 001 › Fortkeeps later)

The Fortkeeps card fields are in the target `FortkeepsCards` in this package. `FortkeepsCards` depends on `MarkdownCore`. `MarkdownCore` has no Fortkeeps-specific type.
Fortkeeps consumes the package by SemVer tag. Roadmap V1-42 is answered (WAIT-5 closed 2026-10-29): the Apple apps are one multiplatform SwiftUI app in remember-mac, which adds this package. Android (a separate Kotlin and Jetpack Compose repo) and the web app (fortkeeps-cloud) do not use this Swift package; they share the core through `libremember` and the sync protocol.

### Copy (amends log 001 › Copy)

Final image strings (FINAL: Story Weaver's final copy, approved 2026-10-29; all WAIT-3 image strings are fully settled):

| Key | Mac | iOS |
|---|---|---|
| `img.refused.title` | Image can't be shown | Image can't be shown |
| `img.reason.tooLarge` | It's too large to show. | It's too large to show. |
| `img.reason.timedOut` | It took too long to load. | It took too long to load. |
| `img.reason.unsupported` | This image format isn't supported. | This image format isn't supported. |
| `img.reason.network` | Couldn't reach it. Check your connection. | Couldn't reach it. Check your connection. |
| `img.link` | Image: {alt} | Image: {alt} |
| `img.link.noalt` | Image | Image |
| `img.load` (the click action) | Load Image | Load image |
| `img.load.hint` (VoiceOver hint) | Loads the image from {host}. | Loads the image from {host}. |
| `img.reloadFailed` (status line under a kept image) | Couldn't reload this image. {reason} | Couldn't reload this image. {reason} |
| `img.load.hint.local` (VoiceOver hint, local file) | Shows the image from this file. | Shows the image from this file. |
| `img.ax.card` (card accessibility label) | Image can't be shown. {reason} | Image can't be shown. {reason} |
| `img.ax.card.alt` (appended when there is alt text) |  Alt text: {alt} |  Alt text: {alt} |

The Failed card and the Refused card (`img.refused`) both use the title `Image can't be shown`. Failed shows one of the four reason lines under it. Refused shows the host's reason line if the host gives one, otherwise the title alone. "Couldn't load this image." and "This image can't be shown." are dropped. The card shows the title and at most one reason line. The reason line matches the `ImageFailure` case. The card's accessibility label is `Image can't be shown. {reason}`, plus ` Alt text: {alt}` when there is alt text. The click action (`activateImage`) is `Load Image` on Mac and `Load image` on iOS; its VoiceOver hint is `Loads the image from {host}.`, or `Shows the image from this file.` for a local file.

Screens-file copy keys, as amended (screens §3.8): `img.failed` title "Image can't be shown" + one final reason line · `img.refused` title "Image can't be shown" + the host's reason line, or the title alone · `img.reloadFailed` (FINAL) "Couldn't reload this image. {reason}" status line under the kept image, or the standard card if the old image is gone.

Other copy (Round 3): `New File` (menu and sidebar) · checkbox VoiceOver value "checked" / "unchecked" · untitled local-image card `Save the document to show local images.` · iPhone home screen and missing-file strings as in iPhone home screen.

## Trade-offs

- **Chosen:** a new log instead of editing log 001.
  - Pros: Log 001 stays an exact record. Each amendment names what it changes.
  - Cons: An implementer reads two logs; this one wins.
- **Chosen:** a required `activateImage(_:)` host method.
  - Pros: A fetch always follows an explicit click.
  - Cons: Every host writes one more method.
- **Chosen:** wide blocks scroll in their own box.
  - Pros: The page never scrolls sideways; prose wraps.
  - Cons: One more focus stop per overflowing block.

## Verification Criteria

1. Keyboard (launch blocker): Tab reaches every link, checkbox, and image card in reading order. Return opens a link. Space toggles a checkbox. Control-F6 and Esc move into and out of the Mac format bar.
2. VoiceOver (launch blocker): Mac headings expose their level. With iOS Auto-Play Animated Images off, a gif shows frame 1.
3. A refused image shows the card with `.text` and `Image: {alt}` or `Image` with `.link`. An image card click calls `activateImage(_:)` and no fetch happens before it.
4. Copy of a rendered list gives `- `, `1. `, `- [ ] `, and `- [x] ` markers with nested indentation.
5. A focused overflowing wide block scrolls 40 pt per arrow key and to its ends with Option+arrow; a block that does not overflow is not in the Tab order; Esc returns to the text; VoiceOver reports a scroll area; the focus ring is at least 3:1.
6. The checkbox accessibility value reads "checked" or "unchecked".
7. The HTML spike tests of plan 03 stage 3b all pass, or the failure is reported to Itay.
8. The iPhone missing-file row, sheet, and VoiceOver label match the strings above.

## Known Limitations

### Waiting items

| Tag | Item | Who | Blocks |
|---|---|---|---|
| WAIT-1 | The HTML spike result. Policy: a native safe subset if the spike tests pass. | Itay, after the test | The HTML policy step (plan 03 stage 3b). |
| WAIT-2 | The exact format-command cases. | Interface | Plan 01 stage 1d steps 5–6. |
| WAIT-3 | The final on-screen copy. All image strings are settled (FINAL, approved 2026-10-29, Copy › Final image strings); the non-image strings are open. | Story Weaver | The exact-string tests in plan 02. |
| WAIT-4 | The `FK Scroll` app icon in the Fortkeeps theme. | Interface | Resolved: assets in `design/icon/`. |
| WAIT-5 | Roadmap V1-42: where Fortkeeps' phone code lives. | Itay | Resolved 2026-10-29: answer A (Apple apps in remember-mac, Android its own Kotlin repo, web in fortkeeps-cloud; shared core `libremember` and the sync protocol). |
| WAIT-6 | Roadmap V1-44: the bundle ID prefix. | Itay | Resolved 2026-10-26: `app.fortkeeps.*`; Scroll is `app.fortkeeps.scroll`. |
| WAIT-7 | Itay's OK on the PROPOSED iPhone home-screen layout. | Itay | Plan 03 stage 3d steps 1–6. |

WAIT-4, WAIT-5, and WAIT-6 are resolved. WAIT-1, WAIT-2, WAIT-3, and WAIT-7 are open (all WAIT-3 image strings are settled as of 2026-10-29).

Deferred, not waiting on a person: signing, notarization, TestFlight, and the App Store for Fortkeeps Scroll wait until the Apple Developer membership (roadmap V1-43).

## Future Work

- The HTML spike result, in a new log.
- The remember-mac log 010 conformance README correction for MD-29 (in remember-mac).
