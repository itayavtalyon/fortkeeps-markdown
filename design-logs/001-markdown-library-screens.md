# Fortkeeps Scroll — standalone Markdown app: screen design (Interface, 2026-10-25)

> Interface screen design, 2026-10-25, part of log 001 Design. Log 001 wins where they differ. The app name is now Fortkeeps Scroll.

Status: **UI design closed 2026-10-25**, except the HTML spike outcome (§3.9) and the Resolve copy from Story Weaver (§3.11). Copy remains DRAFT. Copy marked **DRAFT** goes to Story Weaver. Name: **Fortkeeps Scroll** (Itay 2026-10-25, Q1). Home-screen name **FK Scroll** (decided Q21). App Store subtitle includes "Markdown editor" (DRAFT: "Markdown editor for your files").
Sources: md-lib log 001, MD-LIB-ANSWERS-interface.md (Itay decisions 2026-10-25 win), Fortkeeps handoff 01/07/08.
Wireframes: `001-wireframes/*.png` (HTML source + `gen.py` beside them).

## 0. Decisions and assumptions

| # | Item | Status |
|---|---|---|
| D1 | Platforms v1: macOS 15+, iPadOS 18+, iOS 18+. No Android, no web. | Decision (Itay, log 001) |
| D2 | One style-as-you-type editor (syntax visible, dimmed — the Fortkeeps editor styling). No Read/Edit toggle in the app. | **Decision (Itay 2026-10-25)** — supersedes log 001 Read/Edit toolbar + ⌘⇧E |
| D3 | Optional per-document **Lock** (read-only) — editor becomes non-editable, links/images clickable, checkboxes disabled. | Assumption |
| D4 | Native tabs (Mac system tabs, iPad tab strip) + optional folder sidebar, shown only once folder access is granted. | Assumption (log 001 lists folder sidebar as future work) |
| D5 | Pure file editor; never opens Fortkeeps brains. | Assumption |
| D6 | Smart quotes and smart dashes off in the editor. | Decision (overrides log "system defaults") |
| D7 | Outside change → custom dialog with Reload / Keep Mine / Resolve…. | Decision (overrides log "system conflict interface") |
| D8 | Remote images never auto-load; click loads that one image. No bar. | Decision (overrides log auto-load and my MD-18 bar) |
| D9 | HTML: spike decides; design shows fallbacks for both outcomes. | Decision |
| D10 | Relaunch reopens everything not explicitly closed (Mac + iOS). | Decision |
| D11 | Hebrew/RTL read+write; UI English-only, localization-ready (all strings keyed, no concatenation, layout uses leading/trailing). | Decision |
| D14 | QUESTIONS.md Q9–Q25 decided 2026-10-25. | Decision |
| D13 | QUESTIONS.md Q1–Q8 decided 2026-10-25 (see there); Q7 cache decided (3-day on-disk cache, Q22 confirms the default). | Decision |
| D12 | Autosave only, no Save button; checkbox ticks save at once; Undo works across saves, no toast. | Decision |

Copy conventions (07): Mac buttons/menus Title Case, iOS sentence case; "…" opens a dialog/picker; curly quotes; no exclamation marks, no blame, no marketing.
Visual: Fortkeeps tokens (log 001 §Color), IBM Plex Sans 600 headings, system body, Plex Mono code. No custom animation; system transitions only (honour Reduce Motion).

## 1. Library requirement: two host modes (flag for Chief Architect)

The app uses only the editor (D2). Fortkeeps has **separate read and edit states**. So `MarkdownViews` must expose both, and the host chooses:

- `MarkdownPresentation` = `.rendered` (read-only native rendering, no syntax shown) | `.editor(styledSource)` | `.editorLocked` (editor styling, not editable; used for the app's Lock).
- **Mode switch is a property, not a new view**: changing it in place must not rebuild the document model or drop the undo stack.
- **Position preservation:** the library maps source offsets ↔ rendered positions. On switch it keeps (a) the first visible block and its intra-block offset as the scroll anchor, (b) the caret/selection mapped to the nearest rendered character (rendered → editor maps back to source; a selection on hidden syntax snaps to the content). Exposed as `anchor: MarkdownAnchor` get/set so a host can persist it (the app persists per file for relaunch, D10).
- **Accessibility:** on switch, post one announcement (host-supplied string; Fortkeeps e.g. "Editing" / "Reading" — DRAFT) and move VoiceOver focus to the element at the anchor, not the top. Rendered mode exposes heading/link/list/table/checkbox traits; editor exposes text-view + drawn checkboxes as toggles (MD-24).
- **Checkbox in both modes** calls the text-change closure with `.checkbox`; in `.editorLocked` checkboxes are disabled (trait `.notEnabled`).
- `isEditable` pause (for the conflict dialog / Resolve) separate from presentation.
- Must-pass tests: switch editor→rendered→editor preserves caret offset and first visible line within one line; undo after the round trip restores the pre-switch edit; VoiceOver focus after switch lands on the anchor block.

## 2. Screen list

1. Launch / empty window  2. Open, recent files, folder access  3. Document window (Mac)  4. Outline  5. Folder sidebar  6. Find and replace  6a. Floating format bar  7. Links  8. Images (local, remote placeholder, failed)  9. HTML fallbacks  10. External-change dialog  11. Resolve view  12. Missing / deleted / renamed file  13. Read-only, locked file  14. Large files  15. Multi-file drop  16. Export / print / share  17. Settings  18. Menu bar and shortcuts  19. iPad  20. iPhone  21. Error states catalogue

---

## 3. Screens

### 3.1 Launch / empty window
**Purpose:** get to a file in one step. **Mac:** restore all open docs (D10). With none: a 560×380 window, centered glyph, line, two buttons, and a Recent list (max 8) below.
```
┌───────────────────────────────────────┐
│              [glyph]                  │
│   Open a Markdown file, or create one.│
│        [ Open… ]   [ New ]            │
│  Recent ───────────────────────────── │
│  lisbon.md        ~/Notes/Trip   Today│
│  README.md        ~/Code/app   Oct 21 │
└───────────────────────────────────────┘
```
Shown at launch with nothing to restore, when the last tab closes, on a Dock click with no window. **iOS:** system `DocumentGroup` browser; New creates `Untitled.md` in the current folder and opens with keyboard up.
**States:** recent item missing → greyed with "Not found" and "Remove" on hover/swipe. **A11y:** Recent is a list, rows read "lisbon.md, in Trip, opened today"; Return opens; initial focus on Open….
Copy (DRAFT): `empty.line` "Open a Markdown file, or create one." · `empty.open` Mac "Open…" / iOS "Open" · `empty.new` "New" · `recent.header` "Recent" · `recent.missing` "Not found" · `recent.remove` Mac "Remove from Recent" / iOS "Remove".

### 3.2 Open, recent files, folder access
System Open panel (`.md .markdown .txt`, case-insensitive; also `.mdown .mkd` per MD-28). Mac File ▸ Open Recent (system).
**Folder access (sandbox):** sibling images/links need the folder. Ask only when the document actually has a relative image or sibling link. Inline strip under the toolbar, one per document per session, dismissible (it is information, not a nag: it appears once, only when useful, and never returns after dismissal that session).
```
│ ⓘ Allow access to “Trip” to show its images and open linked files. [Allow Access…] [×] │
```
Allow Access… opens the folder picker preset to the doc's folder; bookmark stored per folder; images then draw, sidebar becomes available. Inline local-image placeholders meanwhile read "Image: {alt} — needs folder access" and are clickable: the click opens the folder picker only when the sandbox actually needs access; if access already exists the image loads directly (decided Q18).
Copy (DRAFT): `access.bar` "Allow access to “{folder}” to show its images and open linked files." · `access.button` Mac "Allow Access…" / iOS "Allow access" · `access.dismiss` (a11y) "Dismiss" · `access.ph` "Needs folder access".
A11y: strip is announced once on appearance (polite), is a landmark group, × reachable by Tab.

### 3.3 Document window (Mac) — `001-wireframes/01-document-light.png`, `02-document-dark.png`
**Layout:** unified toolbar (title = file name, folder as subtitle; Outline/Sidebar toggle at leading; Find, Share, Lock at trailing) · system tabs · optional sidebar (Outline + Folder) · text column max 680 pt centred · status bar (on by default, "Saved · {n} words", View ▸ Show Status Bar; decided Q10).
```
┌ ● ● ●  [☰]        lisbon.md — ~/Notes/Trip        [⌕] [⇪] [🔓] ┐
├ lisbon.md │ packing.md │ README.md ─────────────────────────────┤
│ OUTLINE    │   # Lisbon, May                                   │
│ Lisbon,May │   Four days… [packing.md](packing.md)             │
│  Flights   │   ## To do                                        │
│  To do     │   ☑ Book the room   ☐ Buy a *Viva Viagem* card    │
│ FOLDER·Trip│   ‏לא לשכוח… (RTL block, bar on right)              │
├────────────┴──────────────────────────────────────────────────┤
│ Saved · 412 words                         Markdown · UTF-8 · LF│
```
**Interactions:** type anywhere (style-as-you-type, syntax `text3`); link click (§3.7, decided Q2, confirmed by Itay 2026-10-26): **click on link text places caret; ⌘-click follows; in Lock, click follows; on iPhone a tap places the caret and a long press shows Open Link**. Checkbox click toggles + saves immediately. ⌘B/⌘I/⌘K, list continuation (log). Zoom ⌘+/⌘−/⌘0, 80–200 %, per doc.
**Save state:** no Save button. Status shows "Saved" / "Saving…"; title has no dirty dot except while unsaved > 2 s. File ▸ Save is absent; ⌘S does nothing harmful (system "Save" remains only to name an Untitled doc via Save As… → File ▸ "Save…" appears for untitled documents only; decided Q17).
**States:** untitled ("Untitled", lives in autosave area until named); locked (§3.13); paused during conflict (editing disabled, checkboxes dimmed + `.notEnabled`, Mac beep on typing).
**A11y:** text view with rotor Headings/Links/Form controls over the whole doc (MD-21); checkboxes toggle trait with task label; Increase Contrast maps text3→text2, line2→text3; RTL blocks get trailing bullets/checkboxes; tab order: toolbar → sidebar → text → status.
Copy (DRAFT): `status.saved` "Saved" · `status.saving` "Saving…" · `status.words` "{n} words" · `toolbar.outline` "Outline" · `toolbar.find` "Find" · `toolbar.share` "Share" · `toolbar.lock` Mac "Lock" / unlocked state "Unlock" · `untitled` "Untitled".

### 3.4 Outline / TOC
Sidebar section listing H1–H3 (H4–H6 under disclosure), indent per level, current section highlighted as you scroll. Click scrolls and puts caret at heading start; VoiceOver focus moves there. Empty: "No headings yet." Keyboard: ⌃⌘S toggles sidebar, ⌥⌘O focuses Outline (per the §3.18 menu table; confirmed by Itay 2026-10-26). iPhone: Outline is a sheet from the ☰ button. RTL headings right-aligned within the row.
Copy (DRAFT): `outline.title` "Outline" · `outline.empty` "No headings yet."

### 3.5 Folder sidebar (assumption D4)
Appears only after folder access exists. Lists `.md .markdown .txt` and subfolders (other files hidden). Single click opens in a tab (or selects existing). **Actions (decided Q9):** New File, Rename, Move to Trash (context menu, File menu, and ⌘⌫ for Trash). Trash only, never permanent delete; Undo (⌘Z) restores from Trash. New File creates `Untitled.md` and starts inline rename immediately (decided Q25). Rename inline (Return commits, Esc cancels); open tabs follow the rename. Moving an open file to Trash closes its tab after the move (Undo reopens). Copy: `sidebar.folder` "{folder}" · `sidebar.empty` "No Markdown files in this folder." · `sidebar.new` Mac "New File" / iOS "New file" · `sidebar.rename` "Rename" · `sidebar.trash` Mac "Move to Trash" / iOS "Move to Trash" · `sidebar.undoTrash` "Undo Move to Trash" · `sidebar.nameTaken` "“{name}” already exists. Choose another name."

### 3.6 Find and replace
Mac: system find bar (`NSTextFinder`) above the text: ⌘F find, ⌥⌘F replace, ⌘G/⇧⌘G next/prev, ⌘E use selection. Options: Match Case, Whole Words (system menu). Searches the source text (what you see). Count "3 of 12". Replace All is one Undo step and goes through autosave. In Lock, replace controls hidden. iOS: `UIFindInteraction` (system). Large files: search runs on the model, results stream ("Searching…").
Copy: system strings; DRAFT extra `find.searching` "Searching…" · `find.none` "No results".

### 3.6a Floating format bar (decided Q11) — `001-wireframes/07-format-bar.png`
**Purpose:** common styling without memorising syntax; it only inserts portable Markdown.
**Buttons, in order:** Bold, Italic, Heading ▾ (Heading 1, 2, 3, Body), Bulleted List, Checkbox, Link, Code, Quote. Each does exactly what its menu command does; the result is plain Markdown characters (`**`, `*`, `#`, `- `, `- [ ] `, `[]()`, `` ` `` / fence for multi-line, `> `). Active state reflects the selection (e.g. Bold shown pressed inside `**…**`), shown with a filled background *and* the `.selected` trait, never colour only.
**Mac:** a small panel 8 pt above the selection (below it if no room), never covering the caret line; follows the selection, disappears on typing/scroll and returns on the next selection; Esc dismisses; ⌃F6 (system floating-window focus) moves keyboard focus into it, arrows move between buttons, Esc returns to text. Tooltips show the shortcut. Hidden in Lock.
**iPad / iPhone:** docked as the keyboard input accessory bar (replaces the log's Bold/Italic/Link-only bar), horizontally scrollable at large Dynamic Type sizes, 44 pt targets; with a hardware keyboard on iPad it docks at the bottom of the window as a compact bar. Long-press shows Large Content Viewer.
**VoiceOver:** toolbar container "Format"; each button labelled ("Bold", "Heading, Heading 2 selected"); after use announces nothing extra (the text change is read).
**Decided (Q23, Q24, 2026-10-25):** Mac shows it on selection only; iOS always docks it above the keyboard; View ▸ Show Format Bar hides or shows it.
Copy (DRAFT): `fmt.bar` "Format" · `fmt.bold` "Bold" · `fmt.italic` "Italic" · `fmt.heading` "Heading" · `fmt.h1` "Heading 1" · `fmt.h2` "Heading 2" · `fmt.h3` "Heading 3" · `fmt.body` "Body" · `fmt.list` Mac "Bulleted List" / iOS "Bulleted list" · `fmt.checkbox` "Checkbox" · `fmt.link` "Link" · `fmt.code` "Code" · `fmt.quote` "Quote" · `view.formatBar` Mac "Show Format Bar" / "Hide Format Bar".

### 3.7 Links
Click behaviour (log 001 Round 4 + D2): http/https → default browser; mailto → Mail; sibling `.md/.markdown/.txt` inside folder → opens in a tab (or selects it); `#fragment` → scrolls to slug + VO focus; anything else → nothing, plus hover tooltip showing destination after 1 s and Mac beep on activation. Sibling link with no folder access → the folder-access strip appears (once) and the link waits. Missing sibling → inline popover "“other.md” isn't in this folder." K: ⌘K insert link (log). Context menu: Open Link, Copy Link, Edit Link.
Copy (DRAFT): `link.missing` "“{name}” isn’t in this folder." · `link.menu.open` "Open Link" · `link.menu.copy` "Copy Link" · `link.menu.edit` "Edit Link".

### 3.8 Images — remote placeholder `001-wireframes/05-remote-image-placeholder.png`
Images draw inline below their source line (the source `![alt](url)` stays fully visible on one line above the image; it never collapses — decided by Itay, log 001 round 9).
- **Local, allowed:** draws at column width max, no upscaling, ≤80 % viewport height, scroll-anchored reflow.
- **Remote (D8):** a calm card: image glyph, alt text (or "Image"), "Remote image · {host}", button **Load Image**. Click anywhere on the card or Return/Space when focused loads *that* image only, for this window session. No document-level bar, no "load all" nag. Context menu offers "Load All Images in This Document" (decided Q7): this document only, never remembered. **Image cache (decided Q7, Itay 2026-10-25):**
  - Only images the person chose to load (one click or Load All Images) are cached. Nothing is ever fetched automatically.
  - Stored in the app's sandboxed Caches folder, excluded from backups (`isExcludedFromBackup`) and from iCloud/sync. Keyed by the image URL.
  - Expires **3 days after last view** (decided Q22; adjustable constant; shared by URL across documents). Each view of a cached image resets its clock. Purged at launch and when the app goes to the background.
  - Within the window, reopening the document (or any document with the same URL) draws the cached image with no click and no network request. After expiry the placeholder returns.
  - The Load All Images choice itself is not remembered; only the images it loaded are cached.
  - Context menu on a loaded image: **Reload Image** (iOS "Reload image") — downloads a fresh copy, same rules as §Images (10 s, 5 MB, no cookies, host checks), replaces the cache entry; on failure the old copy stays and the card shows "Couldn’t reload this image."
  - Note: this changes log 001 ("keeps the bytes in memory until the document closes").
  - VoiceOver: cached/loaded image = image trait, label "{alt}" (empty alt → decorative, hidden), hint none; custom action "Reload image". Placeholder = button, label "{alt}, remote image from {host}, not loaded", hint "Loads this image". Expired placeholders read the same as never-loaded ones.
- **Loading:** spinner glyph replaced by system progress indicator (static under Reduce Motion), text "Loading…"; Cancel by Esc.
- **Failed:** card stays with "Couldn’t load this image." and **Try Again**; reasons in tooltip/VO hint (too large, not allowed, timed out, unsupported format).
- **Refused by rules** (private host, SVG, data URL): follows `imageFallback` (log 001 round 9). `.text`: the "Image can't be shown" card, no button. `.link`: the link "Image: {alt}", or "Image" with no alt. Copy is PROPOSED in log 001 › Copy, pending WAIT-3.
- GIF under Reduce Motion: frame 1 + Play glyph, a11y action "Play animation".
A11y: card is a button, label "{alt}, remote image from {host}", hint "Loads this image". Empty-alt loaded image is decorative (hidden).
Copy (DRAFT): `img.remote.sub` "Remote image · {host}" · `img.load` Mac "Load Image" / iOS "Load image" · `img.noalt` "Image" · `img.loading` "Loading…" · `img.failed` "Couldn’t load this image." · `img.retry` Mac "Try Again" / iOS "Try again" · `img.refused` "This image can’t be shown." · `img.play` "Play animation" · `img.reload` Mac "Reload Image" / iOS "Reload image" · `img.reloadFailed` "Couldn’t reload this image." · `img.ax.placeholder` "{alt}, remote image from {host}, not loaded".

### 3.9 HTML fallbacks (D9, spike pending)
Outcome A (native subset): supported tags render natively; unsupported blocks render as dimmed source in a mono block with a small "HTML" label and no warning. Outcome B (sandboxed web view, if kept): block renders in a bordered region; if it fails, falls back to A. Either way: no scripts, no network, images obey image rules. Copy (DRAFT): `html.label` "HTML" · a11y hint "Shown as source."

### 3.10 External-change dialog `001-wireframes/03-external-change-dialog.png`
Trigger: file presenter reports a change on disk that differs from our last save. **No newer edits here:** reload silently, keep the scroll anchor, clear Undo, VO announces "Updated from disk." (decided Q4). If we do have newer edits: Mac sheet / iOS alert. Editing pauses while visible.
```
 ⇅  This file changed outside Fortkeeps Scroll
    “lisbon.md” was changed by another app at 10:42. You also have
    edits here that aren’t in that version.
    [Reload]                       [Resolve…]  [Keep Mine]
    Reload replaces your edits with the outside version and clears Undo.
```
**No default button and Esc picks nothing (Itay 2026-10-25, Q5).** None of the three buttons is styled as default; Return and Esc do nothing; the person must choose Reload, Resolve… or Keep Mine. Reload sits left, apart from the other two. iOS: alert with three plain buttons in sentence case (no `.cancel` role, no preferred action), "Reload" destructive style.
A11y: sheet announced with title + body; initial keyboard/VoiceOver focus on the title text, not a button, so Space/Return cannot trigger a choice by accident; Tab (FKA) moves through Reload → Resolve… → Keep Mine with the system focus ring visible on whichever button has focus; VO hint on each button states its effect.
Copy (DRAFT): `ext.title` "This file changed outside Fortkeeps Scroll" · `ext.body` "“{name}” was changed by another app at {time}. You also have edits here that aren’t in that version." · `ext.reload` "Reload" · `ext.keep` Mac "Keep Mine" / iOS "Keep mine" · `ext.resolve` "Resolve…" · `ext.note` "Reload replaces your edits with the outside version and clears Undo. Keep Mine saves your version over it." · deleted variant see §3.12.

### 3.11 Resolve view `001-wireframes/04-resolve-view.png`
**Purpose:** merge Mine (window) vs Theirs (disk) per hunk, safely. Mac: replaces the document content area in the same window (not a new window), toolbar title "Resolve changes — {name}". iPad: full-screen cover. iPhone: inline (stacked) layout.
**Layout:** side-by-side by default (Mine left, Theirs right; no swap in RTL, the chrome stays LTR); toggle Side by Side / Inline (View menu, ⌥⌘I); inline automatically when the window is narrow or at large text sizes (decided Q20). Unchanged runs collapsed to "{n} unchanged lines — Show". Each hunk: two panes rendered with the editor styling, actions **Use Mine / Use Theirs / Use Both** (Both = mine then theirs; order switch in context menu "Use Both, Theirs First"), and a state label "✓ Mine / ✓ Theirs / ✓ Both / Not resolved". After choosing, the hunk shows the result and an **Edit** affordance to hand-tune text in place. Counter "{k} of {n} resolved" in toolbar. Colour is never the only cue: pane headers, state text, and a ✓ glyph.
**Bottom bar:** shortcuts hint · **Cancel** · **Apply** (disabled until all hunks resolved; "Use Mine for the Rest"/"Use Theirs for the Rest" in a menu on Apply).
**Keyboard:** ⌥↓/⌥↑ next/previous hunk; ⌘⌥← Mine; ⌘⌥→ Theirs; ⌘⌥B Both; ⌘Z undo a choice; Return = Apply when enabled; Esc = Cancel.
**Cancel safely:** Cancel returns to the dialog state (Keep Mine semantics are NOT applied silently): it reopens the external-change dialog. Nothing is written until Apply. Apply writes the merged text once, as one Undo group ("Undo Resolve"), and Undo is kept (merged result is new mine). If the disk changes again during Resolve: banner inside the view "The file changed again. Restart with the newest version?" [Restart] — choices kept where hunks still match.
**VoiceOver:** each hunk is a container: "Change 2 of 3, not resolved. Mine: … Theirs: …"; actions are buttons and also custom actions on the container (Use mine/theirs/both); rotor "Changes" custom rotor; resolving announces "Change 2 resolved, using theirs. 1 left." Dynamic Type: at AX sizes side-by-side switches to inline automatically.
Copy (DRAFT): `res.title` "Resolve changes — {name}" · `res.mine` "Mine · this window" · `res.theirs` "Theirs · on disk, {time}" · `res.useMine` Mac "Use Mine" / iOS "Use mine" · `res.useTheirs` "Use Theirs"/"Use theirs" · `res.useBoth` "Use Both"/"Use both" · `res.state.none` "Not resolved" · `res.count` "{k} of {n} resolved" · `res.unchanged` "{n} unchanged lines" · `res.show` "Show" · `res.apply` "Apply" · `res.cancel` "Cancel" · `res.again` "The file changed again. Restart with the newest version?" · `res.restart` "Restart" · `res.ax.resolved` "Change {i} resolved, using {side}. {n} left." · `res.ax.paused` "Editing is paused until you resolve the conflict."

### 3.12 Missing / deleted / renamed file
- **Renamed/moved** (file presenter follows): update title and tab silently; no dialog.
- **Deleted / moved to Trash** while open: non-modal strip "“{name}” was deleted. Your text is still here." [Save As…] [Close]. Editing continues in memory; autosave pauses; Close asks nothing more only if they choose Close (Close on unsaved deleted file = confirm "Close without saving? The text will be lost." [Cancel] [Close]).
- **Volume unmounted/iCloud evicted:** same strip, "“{name}” is no longer available."
- **Recent/relaunch item missing:** not reopened; Recent row "Not found".
Copy (DRAFT): `gone.deleted` "“{name}” was deleted. Your text is still here." · `gone.unavailable` "“{name}” is no longer available. Your text is still here." · `gone.saveAs` "Save As…"/"Save as" · `gone.close` "Close" · `gone.confirm` "Close without saving? The text will be lost."

### 3.13 Read-only or locked file
- **No write permission / locked in Finder / read-only volume:** opens normally with Lock on and a lock glyph in the title; strip "You can read this file but not change it." [Duplicate] (Mac: "Unlock" only when Finder-locked and the user owns it).
- **User Lock (D3):** toolbar Lock toggles; status shows "Locked". Typing: beep (Mac), nothing (iOS); VO announces "Locked" once.
- Checkbox in read-only: disabled, not silently ignored.
Copy (DRAFT): `ro.strip` "You can read this file but not change it." · `ro.duplicate` "Duplicate" · `lock.on` "Locked" · `lock.unlock` "Unlock".

### 3.14 Large files
Any size opens (log). Above 5 MB (decided Q16): open with a determinate progress in the window ("Opening {name}…") after 300 ms; editing is available once loaded. Above 20 MB: a quiet status note "Large file: styling updates as you scroll." No modal. Word count computed lazily ("—" until ready). Find streams. Never block the main thread.
Copy (DRAFT): `big.opening` "Opening “{name}”…" · `big.note` "Large file: styling updates as you scroll."

### 3.15 Multi-file drop
Drop onto Dock icon, window, or tab bar: every valid file opens in a tab (existing ones are selected). Invalid ones: one combined alert after the valid tabs open.
```
 Some files weren’t opened
 Fortkeeps Scroll opens .md, .markdown, and .txt files.
 • report.pdf  • photo.png  …and 3 more            [OK]
```
Folder dropped: if it contains Markdown files, offer "Open Folder in Sidebar" (grants access; decided Q15); otherwise extension message. Non-UTF-8 files listed separately: "Not UTF-8: notes-latin1.txt".
Copy (DRAFT): `drop.title` "Some files weren’t opened" · `drop.body` "Fortkeeps Scroll opens .md, .markdown, and .txt files." · `drop.more` "and {n} more" · `drop.utf8` "Not UTF-8:" · single refusals per log: "Open a .md, .markdown, or .txt file." / "This file is not UTF-8, so it was not opened."

### 3.16 Export / print / share
Toolbar Share (system share sheet: the file itself). File menu:
- **Export as PDF…** — rendered (no syntax) using reading typography, page margins 20 mm, headers off; remote images only if already loaded (never fetched for export).
- **Export as HTML…** — single self-contained file, minimal CSS, no scripts, local images embedded as data (decided Q12); remote images kept as links.
- **Print…** ⌘P — same rendering as PDF.
- **Copy as Rich Text** ⌥⌘C — selection (or whole doc if none) as RTF+HTML; plain Copy stays source.
iOS: Share menu items "Export PDF", "Export HTML", "Print", "Copy as rich text".
Copy (DRAFT): `export.pdf` "Export as PDF…" · `export.html` "Export as HTML…" · `print` "Print…" · `copyRich` "Copy as Rich Text" / iOS "Copy as rich text" · `export.failed` "Couldn’t export “{name}”. {system reason}".

### 3.17 Settings (minimal)
Mac ⌘, one pane, 420 pt wide; iOS: in-app sheet from the ⋯ menu (decided Q13).
- Text size: system (Mac zoom per doc instead); **Line width**: Narrow / Medium / Wide (default Medium 680 pt).
- **Show word count** (status bar) on/off.
- **Spelling**: Check Spelling While Typing (system).
- Relaunch reopens open files and restores scroll, caret and Lock per file (decided Q14); no toggle.
- Folders with access: list with Remove (revokes bookmarks). Transparency, local-first.
- **Image cache:** button **Clear Image Cache** (iOS "Clear image cache") with current size, e.g. "Clear Image Cache (4.2 MB)"; disabled with "Image cache is empty" at 0. Explanation line below. Clearing is immediate (cache is re-creatable, no confirm); VO announces "Image cache cleared."
No theme switch (follows system). No analytics. No account.
Copy (DRAFT): `set.lineWidth` "Line width" · `set.narrow` "Narrow" · `set.medium` "Medium" · `set.wide` "Wide" · `set.wordCount` "Show word count" · `set.folders` "Folders Fortkeeps Scroll can open" · `set.folders.remove` "Remove" · `set.folders.empty` "None yet." · `set.cache.clear` Mac "Clear Image Cache ({size})" / iOS "Clear image cache ({size})" · `set.cache.empty` "Image cache is empty" · `set.cache.note` "Images you load are kept on this device for 3 days after you last view them, so they show again without another click. They are never backed up or synced." · `set.cache.cleared` "Image cache cleared."

### 3.18 Menu bar and shortcuts (Mac)
| Menu | Items (shortcut) |
|---|---|
| Fortkeeps Scroll | About Fortkeeps Scroll, Settings… ⌘,, Hide, Quit ⌘Q |
| File | New ⌘N, Open… ⌘O, Open Recent ▸, Open Folder… ⇧⌘O, Close Tab ⌘W, Close Window ⇧⌘W, Rename…, Move To…, Duplicate ⇧⌘S, Revert To ▸ (system versions), Export as PDF…, Export as HTML…, Share ▸, Print… ⌘P |
| Edit | Undo ⌘Z, Redo ⇧⌘Z, Cut/Copy/Paste, Copy as Rich Text ⌥⌘C, Paste and Match Style ⌥⇧⌘V, Select All ⌘A, Find ▸ (Find… ⌘F, Find and Replace… ⌥⌘F, Find Next ⌘G, Find Previous ⇧⌘G, Use Selection for Find ⌘E), Spelling ▸, Substitutions ▸ (Smart Quotes and Smart Dashes off by default, switchable here; decided Q19) |
| Format | Bold ⌘B, Italic ⌘I, Link… ⌘K, Code ⇧⌘C, Quote ⌘', Toggle Checkbox ⌘↩, Heading ▸ (Heading 1–3 ⌥⌘1–3, Body ⌥⌘0), Bulleted List ⇧⌘8 (decided Q11) |
| View | Show Format Bar (decided Q24), Show Sidebar ⌃⌘S, Outline ⌥⌘O, Show Status Bar, Lock ⌥⌘L, Actual Size ⌘0, Zoom In ⌘+, Zoom Out ⌘−, Enter Full Screen ⌃⌘F |
| Window | system + Show Previous/Next Tab ⇧⌘[ / ⇧⌘] |
| Help | Fortkeeps Scroll Help, Markdown Basics |
Removed per D2: View ▸ Read/Edit and ⌘⇧E.

### 3.19 iPad
Tab strip under nav bar (name + close, "Close {name}"), ⇧⌘[ ⇧⌘], ⌘W, ⌘1–9, drag to reorder; sidebar (Outline/Folder) as `UISplitViewController` primary column, collapsible; Stage Manager multiwindow supported; floating format bar per §3.6a (all 8 buttons; above the software keyboard, docked at the window bottom with a hardware keyboard); hardware-keyboard ⌘-hold overlay lists all commands. Pointer hover shows link destination.

### 3.20 iPhone `001-wireframes/06-iphone-document.png`
Nav bar: "‹ Open Files" back, title block (file name, folder · Saved), trailing ☰ Outline, Share, ⋯ (Find, Lock, Export, Settings). Text 17 pt body Dynamic Type, checkboxes 44 pt hit area. Keyboard bar: the full format bar per §3.6a (8 buttons, 44 pt, scrollable). Open Files list: swipe "Close"; empty → system browser. Resolve view: stacked inline layout, per-hunk buttons full width. Dialogs: system alerts, sentence case.
Copy (DRAFT): `nav.openFiles` "Open Files" (log string) · `more.find` "Find" · `more.lock` "Lock" · `more.export` "Export" · `more.settings` "Settings" · `list.close` "Close".

### 3.21 Error states catalogue
| Case | Surface | Copy (DRAFT) |
|---|---|---|
| Wrong extension | alert | Open a .md, .markdown, or .txt file. (log) |
| Not UTF-8 | alert | This file is not UTF-8, so it was not opened. (log) |
| Save failed | strip, retries automatically | Couldn’t save “{name}”. Fortkeeps Scroll will keep trying. [Save As…] |
| Disk full | strip | There isn’t enough space to save “{name}”. |
| No permission at save | §3.13 strip | — |
| Image failed | inline card | §3.8 |
| Export failed | alert | §3.16 |
| Folder access denied | inline placeholder | Needs folder access |
Rule: never lose text silently; every failure keeps the in-memory text and offers Save As….

## 4. Accessibility checklist (all screens)
VoiceOver complete (rotors Headings/Links/Form controls/Changes); keyboard-complete incl. Resolve; Dynamic Type no cap (iOS); Mac zoom; Increase Contrast mapping (MD-24); Reduce Motion: no custom animation, GIFs paused; no colour-only meaning (Resolve uses labels + ✓; checkbox uses state); RTL: per-block direction, trailing markers; 44 pt targets iOS; XCUITest `performAccessibilityAudit()` per screen.
