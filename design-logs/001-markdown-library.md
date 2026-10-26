# 001 - Fortkeeps Scroll and the FortkeepsMarkdown library

Revision 3, 2026-10-25. Chief Architect wrote this revision on the box from Itay's decisions. Status: Design.
Rule source: the design-log-grill snapshot (2026-10-13). The Mac was offline, so the live rules were not read.
Items that wait on someone other than the implementer carry the tag **WAIT-n**. They are listed in Known Limitations › Waiting items, with the stage each blocks. No other implementer choice is open.

## Background

Fortkeeps draws a memory body with the rules in remember-mac design log 010 §9.
That styler is specified to live inside `FortkeepsCore`.
Fortkeeps plan 18 has not started.

A person also wants the same views for plain Markdown files.
The product is a Swift library plus a Mac app and an iOS app.
The app name is Fortkeeps Scroll for now (Itay, 2026-10-25). The name Quill is withdrawn.
The library is the Markdown source that Fortkeeps adopts when plan 18 starts.

## Problem

A memory body and a Markdown file are not the same document.
A memory stops at 64 KiB, never renders raw HTML, hides a line-1 title, and never loads an image.
A file has none of those limits, and Fortkeeps Scroll renders GFM.
Fortkeeps must still be able to turn those extra features off.
Fortkeeps Scroll must open, edit, and save real files without a second copy of the rules.
Fortkeeps needs separate read and edit states. Fortkeeps Scroll needs one style-as-you-type editor.

## Questions and Answers

### Round 1

- **Q: What does the shared library contain?**
  A: Library plus Mac view. The package ships the TextKit 2 editor and the rendered view. The app owns windows and files. Round 4 below also puts the iOS views in the package.

- **Q: How should this relate to the Fortkeeps plans?**
  A: One source, adopt later. This library is the markdown source. When plan 18 starts, stages 18e and 18f call it. Log 010 stays as written until that work begins.

- **Q: Which markdown do files use?**
  A: Render full GFM, including raw HTML. Round 2 replaces a single dialect with host switches.

- **Q: How big can a file be?**
  A: No file cap. The library and the file app accept any size. Fortkeeps still enforces 64 KiB in its own editor. The 8 ms check stays defined at 64 KiB.

- **Q: What does the window show?**
  A: Read and edit. A rendered reading view, and a live-styled editor where every syntax character stays visible and dimmed. The person switches.

- **Q: Where should the code live?**
  A: New repo. A Swift package and a Mac app beside remember-mac. remember-mac does not change until plan 18 starts. The iOS app is in the same repo.

- **Q: What should happen to an image?**
  A: Local and remote. Round 2 locks the strict loader.

- **Q: When does the app write the file?**
  A: Autosave. Round 2 gives that job to the system document. Round 4 uses the system conflict interface.

- **Q: What does a task checkbox do?**
  A: Write immediately. A click in the reading view flips the byte and saves the file at once.

- **Q: Which platforms are in this design?**
  A: Mac and iOS.

- **Q: How many files does the app handle?**
  A: Tabs. Round 2 places the tabs.

- **Q: What type and color should the app use?**
  A: Fortkeeps look. IBM Plex and the log 010 colors. Light and dark follow the system appearance.

### Round 2

- **Q: Which dialect rule should the library ship?**
  A: Other. "GFM everywhere, but with a way for the host of the library to disable features." Round 3 locks the switches.

- **Q: How should the reading view render HTML?**
  A: Native page, sandboxed HTML. Markdown stays a native view. Each HTML block is a sandbox with JavaScript off and no navigation. The GFM disallowed tags stay text. A `javascript:` link cannot run. Images inside HTML use the image rules. Round 3 blocks network loads from the sandbox.

- **Q: What may an image load?**
  A: Strict local and remote. The editor shows the source and does not load an image. The reading view asks the host for bytes. A local image is a relative path that stays inside the file's folder. Remote is http or https, 10 seconds, 5 MB, no cookies. Block localhost, `.local`, and private addresses. Allow png, jpeg, gif, and webp. No SVG and no data URLs. At most 3 redirects, and each hop is checked. Anything else shows `Image: {alt}`.

- **Q: Who owns open, autosave, and a file that changed on disk?**
  A: System documents. Mac uses `NSDocument`. iOS uses `UIDocument`. The system schedules autosave. A new file lives in the system autosave area until Save names it. Round 4 replaces the custom Reload and Overwrite buttons with the system conflict interface.

- **Q: How should several open files appear on iPhone and iPad?**
  A: Tabs on Mac and iPad. Mac uses system document tabs. iPad uses a tab strip. iPhone shows one file, with a list of the other open files.

- **Q: Which bytes can the app open and write?**
  A: UTF-8, normalize. Only valid UTF-8 opens. Every save rewrites the file as LF with a final newline. Round 3 sets the timing.

- **Q: What should the app do with syntax that is not GFM?**
  A: Leave it literal. Front matter, footnotes, math, highlight, and wiki links stay ordinary CommonMark or literal text.

- **Q: What should Undo do?**
  A: Undo survives the save. Each open file has one undo stack. Autosave does not clear it. A checkbox click is one undo step. Undo writes the file again. There is no toast.

- **Q: Which files can be opened?**
  A: Also `.txt`. Round 3 treats `.txt` as markdown.

- **Q: What does Paste insert?**
  A: Convert HTML. Round 3 locks the tag map.

- **Q: What is the product name?**
  A: Fortkeeps Markdown. The repo is `fortkeeps-markdown`. The package is `FortkeepsMarkdown`.

- **Q: What should a large file do?**
  A: Open any size. The editor restyles the edited paragraph and its two neighbors. The reading view builds the blocks near the scroll position.

### Round 3

- **Q: Which switches exist?**
  A: strikethrough, autolink, html, tables, task lists, and paste HTML as markdown. All default on. Soft breaks are line breaks, and that switch defaults off. Fortkeeps later sets strikethrough, autolink, html, and paste off, and sets soft breaks on. Tables and task lists stay on. There is no settings screen. No other switch exists.

- **Q: What markdown should Paste insert for HTML?**
  A: The small tag map. Empty conversion inserts the plain text. Script and style elements are dropped with their text.

- **Q: When should the line-ending rewrite happen?**
  A: On the first change. Opening normalizes the buffer and does not write. A read-only visit leaves the file untouched. The first edit or checkbox click writes LF and a final newline for the whole file. There is no extra notice.

- **Q: How should a `.txt` file be treated?**
  A: Same as markdown. `.md`, `.markdown`, and `.txt` parse as GFM. Any other extension is refused.

- **Q: How does a person move between reading and editing?**
  A: A file opens in the reading view. The toolbar has Read and Edit. Command-Shift-E toggles them. The window title is the file name. A first heading stays in the body. An iPad tab shows the file name and a close button. iPhone has a back button to the list of open files. An empty window shows Open and New.

- **Q: What may an HTML sandbox load?**
  A: Nothing from the network. Style tags and style attributes are removed. An image that passed the image rules is inserted as data. Any other image becomes the alt text. A gif that passed the rules plays.

### Round 4

- **Q: What should a click do in the reading view?**
  A: http and https open in the default browser. mailto opens Mail. A relative link that stays inside the file's folder and ends in `.md`, `.markdown`, or `.txt` opens in this app. Any other link does nothing. The same rules apply inside an HTML block. The editor does not follow a link. A `javascript:` link does nothing.

- **Q: What does Copy place on the pasteboard in the reading view?**
  A: The words on screen. No hash marks and no asterisks. A link copies its label. An image does not copy its bitmap. In the editor, Copy takes the source characters.

- **Q: What should the editor do to typed characters?**
  A: System substitutions. Smart quotes, smart dashes, and spellcheck replacement stay at the system defaults. A formatting bar above the iPhone keyboard has Bold, Italic, and Link.

- **Q: What should the app show when the file on disk changed?**
  A: The system conflict interface, for a local change and for iCloud. The app does not add Reload or Overwrite buttons. This answer replaces the Reload and Overwrite buttons from round 2.


### Round 5 (2026-10-25: Itay, the md-lib answers and the Interface app design)

Rounds 1–4 above stay as written. The answers in this round replace earlier answers where they differ.

- **Q: Which platforms are in v1?**
  A: Mac, iPad, and iPhone.
- **Q: How many views does the app show?**
  A: One style-as-you-type editor, with no Read/Edit toggle. Fortkeeps keeps separate read and edit states. This replaces the round 3 toolbar and Command-Shift-E.
- **Q: What happens when the file on disk changes?**
  A: The app shows its own dialog with Reload, Keep Mine, and Resolve…. Reload loads the outside version, discards the newer local edits, and clears Undo. Keep Mine ignores the outside version, and the next autosave writes over it. Resolve… opens a merge view. When there are no local edits, the app reloads silently. In the dialog, Esc picks nothing and there is no default button. Resolve Cancel returns to the dialog. This replaces the round 4 answer about the system conflict interface.
- **Q: When does the app save?**
  A: Autosave only, with no Save button. A checkbox tick saves immediately. Save… appears only for an untitled document. This overrides log 010 MD-43 for Fortkeeps at adoption.
- **Q: What do smart substitutions do?**
  A: Smart quotes and smart dashes are off. Edit › Substitutions can turn them on. This replaces the round 4 answer.
- **Q: When does a remote image load?**
  A: Never automatically. A click on the image card loads that image. Load All Images in This Document is in the context menu. It applies to this document only and is not remembered.
- **Q: Does a loaded image stay?**
  A: Yes, in an on-disk cache in the sandbox Caches folder. The cache is excluded from backup and sync and is keyed by URL. An entry expires 3 days after its last view. Reload Image fetches a fresh copy. Settings has Clear Image Cache. This replaces the round 2 rule that bytes stay in memory only.
- **Q: What does the folder sidebar do?**
  A: It lists Markdown files after the person grants folder access. Its actions are New File, Rename, and Move to Trash, with Undo. New File creates `Untitled.md` and starts an inline rename.
- **Q: What formatting control exists?**
  A: A format bar with Bold, Italic, Heading, List, Checkbox, Link, Code, and Quote. On Mac it floats near a selection. On iOS it is docked above the keyboard. View › Show Format Bar hides it. The Format menu has the same commands. This replaces the round 4 Bold/Italic/Link bar.
- **Q: What does a link click do in the editor?**
  A: A click places the caret. Command-click follows the link. With Lock on, a click follows the link. On iPhone, a long press shows Open Link.
- **Q: What is Lock?**
  A: A per-file read-only state, toggled with Option-Command-L and kept for each file path.
- **Q: What does relaunch restore?**
  A: Every document that was not closed explicitly, with its scroll position, caret, and Lock.
- **Q: How does a large file open?**
  A: A file over 5 MB opens with a progress bar.
- **Q: What do export and print do?**
  A: PDF, HTML, and Print. HTML export embeds local images as data.
- **Q: Which languages?**
  A: Hebrew and RTL text are read and written correctly. The UI is English only and localization-ready.
- **Q: What is the app called?**
  A: Fortkeeps Scroll, for now. The home-screen name is OPEN-8.

### Round 6 (2026-10-25: Itay, open-questions sheet v2)

- **Q: How do apps talk to the library?**
  A: Through a formal interface that each app implements completely (option C). OPEN-1 covers who owns the text and whether the interface has defaults.
- **Q: Read mode and edit mode in one view?**
  A: One view with a mode setting. A mode switch keeps Undo and the position.
- **Q: How does an app keep its place?**
  A: The library provides a saveable position value.
- **Q: Which text-change reasons exist?**
  A: Edit, checkbox, undo, redo, and reload.
- **Q: What does the host return for an image?**
  A: A state. The library draws the matching card.
- **Q: How does Fortkeeps get its title and image rules?**
  A: A separate presentation value.
- **Q: How is the 64 KiB limit enforced?**
  A: An optional byte limit in the library, with a clean cut.
- **Q: Which license applies?**
  A: MIT. The app source is open in the same repo, with an Acknowledgements screen and a CI check.
- **Q: Which fonts ship?**
  A: The static Plex files from log 010 X-10a.
- **Q: Which tests prove the rendering?**
  A: The GFM spec tests with the file defaults, plus log 010 cases 01–30 with the Fortkeeps value.
- **Q: What does Android follow?**
  A: Option A, with this note: "We will extend the library and the app to Android too, and the Android Fortkeeps version will have the same relationship." The mechanism is OPEN-2.
- **Q: How does Fortkeeps consume the library?**
  A: As a SemVer package dependency, after roadmap V1-42.
- **Q: How are versions pinned, and who does the second review?**
  A: The parser is pinned now. The Chief Architect does the second review. Any Apple-silicon Mac may run the speed test, and the log records the chip.
- **Q: What are the repo and package names?**
  A: The package keeps the neutral name. The repo follows the app name. The repo name is OPEN-6.
- **Q: How does raw HTML display?**
  A: A native-support test runs first, leaning toward a native subset. This is OPEN-3.
- **Q: Which safety rules apply to remote images?**
  A: The full blocklist, https only, a 5,000,000-byte cap, and very large images refused. The pixel limit is OPEN-5.
- **Q: How does paste convert HTML?**
  A: Escape only where needed, and merged-cell content goes into the first cell. The parser choice is OPEN-4.
- **Q: How do the format buttons behave?**
  A: They toggle and apply per line, and Code on several lines makes a fence. The exact cases are OPEN-7.
- **Q: What does one Undo step cover?**
  A: A word run. A paste, a format button, a tick, Replace All, and a Resolve Apply are one step each.
- **Q: What does VoiceOver say for a checkbox?**
  A: "done" or "not done".
- **Q: What is the price, privacy, and distribution?**
  A: Free, with no in-app purchase and no account. "No analytics, no network except images you load", with a CI guard. An `app.fortkeeps.` bundle ID after V1-43. The App Store and a notarized DMG.
- **Q: Where is the Resolve comparison computed?**
  A: In the library, line by line, with tests.
- **Q: How does an untitled document treat local images?**
  A: It shows the "can't be shown" card, with a VoiceOver hint.

### Round 7 (2026-10-25: Itay, the open items)

- **Q: Who owns the text under the protocol?**
  A: The view holds the text. The host replaces it only with reload.
- **Q: Does the protocol have default methods?**
  A: No. Every method is required.
- **Q: What is the repo name?**
  A: `fortkeeps-markdown`.
- **Q: Which paste HTML parser?**
  A: Hand-written, with a fuzz test, now. A later swap is possible.
- **Q: What is the decoded-image pixel limit?**
  A: 8192 × 8192.
- **Q: Are `.mdown` and `.mkd` accepted?**
  A: Yes.
- **Q: What is the home-screen name?**
  A: `FK Scroll`, with its own icon in the Fortkeeps theme.
- **Q: What about Android?**
  A: An Android app comes after the Apple apps are ready, in its own design log.
- **Q: Fortkeeps card heading sizes, and name clearance?**
  A: Card heading sizes go to the Fortkeeps adoption log. Name clearance happens when the name is final.

### Round 8 (2026-10-26: Itay, contradictions and roadmap items)

- **Q: Do the three self-conflicts in the screens file resolve as this log says?**
  A: Yes. Show Sidebar is ⌃⌘S per the §3.18 menu table, and ⌥⌘O focuses the Outline. The iPad format bar has all 8 buttons of §3.6a. A link click follows Q2: click places the caret, ⌘-click follows, in Lock a click follows, and an iPhone tap places the caret with a long press showing Open Link.
- **Q: What is the bundle ID prefix (WAIT-6, roadmap V1-44)?**
  A: `app.fortkeeps.*` everywhere. Fortkeeps Scroll is `app.fortkeeps.scroll` on Mac and iOS.
- WAIT-5 reopened 2026-10-26: Android and web app are in phase one; see roadmap V1-42.

## Design

### Product

The product is Fortkeeps Scroll.
The repo is `fortkeeps-markdown`.
The Swift package is `FortkeepsMarkdown`.
The package has the targets `MarkdownCore` and `MarkdownViews`.
The Mac app and the iOS app are targets in the repo.
The Mac app target and the app display name are `Fortkeeps Scroll`.
The iOS home-screen name (`CFBundleDisplayName`) is `FK Scroll`.
The app has its own icon in the Fortkeeps theme. Interface designed it (WAIT-4, resolved: assets in `design/icon/`).
The Mac minimum is macOS 15.
The iOS minimum is iOS 18 and iPadOS 18.
remember-mac is not a dependency.
This log does not edit remember-mac log 010.
Android is post-v1. A future design log covers the Android library and app.

`MarkdownCore` holds the pure rules.
`MarkdownCore` does not import AppKit, UIKit, or SwiftUI.
`MarkdownCore` does not use `URLSession`, `FileManager`, or `FileHandle`.
`MarkdownViews` holds the Mac view and the iOS view.
`MarkdownViews` does not open a file and does not open a network connection.

The license of the package and of the app targets is MIT.
The app has an Acknowledgements screen.
That screen lists every shipped dependency with its license name and its full license text: IBM Plex (SIL OFL 1.1), swift-markdown (Apache-2.0), swift-cmark (BSD-2-Clause), and every other package in `Package.resolved`.
A CI test fails when a resolved dependency is missing from that list.
A CI test fails when `Package.resolved` or a target links a package on the analytics denylist.
The denylist is: Firebase, Sentry, Amplitude, Mixpanel, Segment, AppCenter, Bugsnag, Crashlytics.
The bundle ID prefix is `app.fortkeeps.` everywhere (roadmap V1-44, WAIT-6, resolved by Itay 2026-10-26). The bundle ID of Fortkeeps Scroll is `app.fortkeeps.scroll` for Mac and iOS.
The README states that "Fortkeeps" and the app icon are trademarks of the project owner.

The library follows SemVer.
A breaking change to the public API needs a new major version and a new design log.
`Package.resolved` is committed.
The `swift-markdown` tag is pinned in plan 01 stage 1b. The implementer records it in Implementation Notes before 1b is done. The tag does not change after that without a new log.

### Host interface

The host is the app or Fortkeeps.
The host implements the protocol `MarkdownHost`.
Every method of `MarkdownHost` is required. The protocol has no default implementations.
The methods are:

| Method | Called when | Thread |
|---|---|---|
| `func image(for request: ImageRequest) async -> ImageResult` | The view needs an image near the viewport. | Any. The view cancels the task when it discards the block. |
| `func open(_ link: LinkActivation)` | The person follows a link. | Main actor. |
| `func textDidChange(_ change: TextChange)` | After the view applies a change. | Main actor. |

`ImageRequest` has `destination: String`, `documentURL: URL?`, and `maxPixelSize: CGSize`.
`ImageResult` is one of:

| Case | The view draws |
|---|---|
| `.image(Data)` | The image. |
| `.needsAccess` | The folder-access placeholder. |
| `.remoteNotLoaded(host: String)` | The remote-image card. |
| `.loading` | The loading card. The host calls `MarkdownView.refreshImage(destination:)` when the result changes. |
| `.failed(reason: ImageFailure)` | The failed card with Try Again. `ImageFailure` is `tooLarge`, `timedOut`, `unsupported`, or `network`. |
| `.refused` | The "can't be shown" card, with no button. |

The view caches each result per destination for the lifetime of the document.
The view does not retry by itself.

`LinkActivation` has `destination: String`, `resolvedURL: URL?`, `documentURL: URL?`, `modifiers`, and `source` (`markdown` or `html`).

`TextChange` has `reason`, `range` (UTF-16 `NSRange` before the change), `replacement: String`, and `text: String` (the full text after the change).
The reasons are `edit`, `checkbox`, `undo`, `redo`, and `reload`.
`edit` covers typing, paste, a format command, list continuation, Replace All, and Resolve Apply.

The view holds the working text.
The host sets the initial text when it creates the view.
The host replaces the text only with `reload(text:)`.
`reload(text:)` replaces the text, clears Undo, keeps the anchor at the nearest block, and reports `reload`.

### View settings

The view takes these values:

| Value | Type | Default | Fortkeeps |
|---|---|---|---|
| `features` | `MarkdownFeatures` | the defaults below | the Fortkeeps value below |
| `presentation` | `MarkdownPresentation` | `titleLine .inBody`, `imageFallback .text` | `titleLine .hidden`, `imageFallback .link` |
| `mode` | `MarkdownMode` | `.editor` | `.rendered` or `.editor` |
| `isEditable` | Bool | true | true |
| `maxUTF8Bytes` | `Int?` | nil | 65536 |
| `anchor` | `MarkdownAnchor` | the document start | — |

`features` and `presentation` stay fixed until the document closes.
A change to `mode` or `isEditable` applies in place. It does not rebuild the document model. It does not clear Undo.
Card heading sizes for Fortkeeps are outside this log. The Fortkeeps adoption log decides them.

### Modes

`MarkdownMode` has three cases:

| Mode | Shows | Editable | Checkboxes | Link click |
|---|---|---|---|---|
| `.rendered` | The rendered text. No syntax shows. | No | Enabled | Follows |
| `.editor` | The source, styled as typed. | Yes | Enabled | Places the caret. Command-click follows. |
| `.editorLocked` | The source, styled as typed. | No | Disabled (`.notEnabled`) | Follows |

`isEditable` false pauses edits in any mode. The host sets it while the outside-change dialog or the Resolve view is visible. While `isEditable` is false, the checkboxes are disabled. On Mac, a typed key beeps. On iOS, a typed key does nothing.

Fortkeeps Scroll uses `.editor` and `.editorLocked`. Lock selects `.editorLocked`.
Fortkeeps uses `.rendered` and `.editor`.

On a mode switch, the view keeps the anchor.
The anchor holds the first visible block, the offset inside that block, and the selection.
A selection on hidden syntax snaps to the nearest content character.
After a mode switch, VoiceOver focus moves to the anchor block.
The view posts one announcement. The host supplies the string.

`MarkdownAnchor` is `Codable`. It stores UTF-8 byte offsets in the source, excluding a leading BOM.
The host can read the anchor and set it.
Fortkeeps Scroll stores the anchor and the Lock state for each file path, for relaunch.

### Features

`MarkdownFeatures` is a value with these Bool fields:

| Field | Default | Effect |
|---|---|---|
| strikethrough | true | False: `~~` stays literal text. |
| autolink | true | False: a bare URL stays literal text. |
| html | true | False: raw HTML shows as text. True: see HTML (WAIT-1). |
| tables | true | False: a pipe table stays CommonMark paragraphs. |
| taskLists | true | False: a task item is a plain list item. |
| pasteHtml | true | False: paste inserts plain text. True: paste converts HTML. |
| softBreakAsLine | false | False: a soft break is a space. True: a soft break is a line break. |

Fortkeeps passes strikethrough false, autolink false, html false, tables true, taskLists true, pasteHtml false, and softBreakAsLine true.
No other feature field exists.

`MarkdownPresentation` has two fields:
- `titleLine`: `.inBody` or `.hidden`. `.hidden` applies the log 010 MD-09–MD-12 title rule in `.rendered` mode only. The editor always shows every byte. Task byte offsets do not change.
- `imageFallback`: `.text` or `.link`. `.link` draws `Image: {alt}` as a link element that calls `open(_:)`.

### Parse

The parser is `swift-markdown`, pinned as in Product.
The parser is CommonMark 0.31.2 plus the GFM extensions that the feature fields turn on.
The table extension follows `tables`.
The task-list extension follows `taskLists`.
The strikethrough extension follows `strikethrough`.
The autolink extension follows `autolink`.
`html` true applies the GFM tag filter.
The tag filter shows these tags as text: `title`, `textarea`, `style`, `xmp`, `iframe`, `noembed`, `noframes`, `script`, `plaintext`.
Front matter, footnotes, math, highlight, and wiki links stay literal.
A line of `---` is a CommonMark thematic break, not a metadata block.

### Document model

`MarkdownCore` builds one model of the whole text.
The model holds the blocks, the heading levels, each task's byte offset, each block's base direction, and the copy string.
Copy, Select All, Find, and the accessibility tree come from the model. They cover the whole text, not only the built blocks.
The view builds the blocks that intersect the viewport and the blocks within one viewport above and below.
The view discards the other blocks.
When VoiceOver focuses a block that is not built, the view scrolls to the block and builds it.

### Rendering (`.rendered` mode)

A heading uses IBM Plex Sans at weight 600.
On Mac, an H1 is 20 pt.
On Mac, an H2 is 15.5 pt.
On Mac, H3 through H6 use the body size at weight 600.
Body text uses the system font.
On Mac, body text is 14.5 pt with a line height of 1.6.
On iOS, an H1 is relative to `.title2`, an H2 to `.title3`, body to `.body`, and code to `.callout`. Dynamic Type has no cap.
Code uses IBM Plex Mono at 13 pt on the `pill` color.
A code block does not wrap.
A code block scrolls horizontally.
A code block has no syntax coloring.
A link uses `accent` and underlines on hover or focus.
A table header is weight 600.
Table cell padding is 6 pt by 10 pt.
A wide table scrolls horizontally.
A quote has a 2 pt `line2` bar on the leading edge and `text2` text.
`**strong**` is weight 600.
`*emphasis*` is italic.
Strikethrough is the body font with a line through it and no new color.
The rendered view does not spellcheck.

Copy in `.rendered` mode writes the characters the view drew for the selection.
The copy has no heading marks and no emphasis marks.
A link copies its label.
Code content is copied.
Fence markers are not copied.
A drawn image adds no characters.
An image that drew as text copies that text.
Blocks in the selection are separated by one newline.
The copy adds no direction marks.

### Tasks

A task draws a checkbox in place of `[ ]` or `[x]`.
The checkbox is 15 pt on Mac.
The checkbox hit size is 44 pt on iOS.
A checked item's words use `text3`.
A click flips one byte.
The byte is the character between `[` and `]`.
An unchecked task becomes `x`.
A checked task (`x` or `X`) becomes a space.
The click reports reason `checkbox`.
A checkbox click is one undo group.
The accessibility element of a checkbox has the toggle trait.
Its label is the task text.
Its value is `done` or `not done`.
Space toggles a focused checkbox.

### Direction

Each block takes its base direction from its first strong letter.
The scan ignores code spans and link destinations.
Hebrew and Arabic set RTL.
Latin sets LTR.
No strong letter follows the parent block.
In an RTL block, the text aligns to the trailing edge.
In an RTL block, the bullet, the checkbox, and the quote bar sit on the trailing edge.
Inline code and a URL inside RTL text are LTR isolates.
The editor applies the same rule to each paragraph while the person types.
The chrome stays LTR English.
Every UI string is keyed with `String(localized:)` and plural rules. No string is built by concatenation.

### Editor (`.editor` and `.editorLocked`)

The editor shows the stored text.
Every character stays visible, except a task marker while the caret is outside it.
Syntax characters are `text3` at regular weight.
The characters are `#`, `**`, `*`, `_`, `` ` ``, `>`, list markers, `[`, `](url)`, `|`, code fences, and `~~` when strikethrough is on.
On Mac, an H1 is 22 pt Plex Sans 600.
On Mac, an H2 is 16 pt Plex Sans 600.
Strong is weight 600.
Emphasis is italic.
Inline code is Plex Mono 13 pt.
Link text uses `accent`.
The `(url)` is `text3`.
Quote text uses `text2`.
A body with no syntax is the system font at 15 pt on Mac, with a line height of 1.6.
On iOS, those sizes scale with Dynamic Type.
The editor spellchecks.
Smart quotes and smart dashes are off. Edit › Substitutions turns them on for the app.
When an image draws, its `![alt](url)` source collapses to one dimmed line while the caret is outside it.

The caret inside a task marker shows the raw marker in `text3`.
Return in a list item continues the list with the same marker.
Return in a task item continues with `- [ ] `.
Return on an empty list item ends the list.

The editor restyles the paragraph that contains the caret, the paragraph before it, and the paragraph after it.
After 300 ms without an edit, the editor restyles the whole text when the text is 20 MB or smaller.
Above 20 MB, the editor restyles only the built blocks.
The 8 ms budget is the 95th percentile of the neighborhood restyles on a 64 KiB text, in a release build, on an Apple-silicon Mac. The log records the chip.

When `maxUTF8Bytes` is set, an insertion that would pass the limit keeps the longest prefix that fits.
The cut falls on a UTF-8 boundary and on a grapheme-cluster boundary.
The editor discards the rest of that insertion.
The cut is one undo group with the insertion.

### Format commands

The commands are:

| Command | Mac shortcut | Text result |
|---|---|---|
| Bold | Command-B | Wraps the selection in `**`. |
| Italic | Command-I | Wraps the selection in `*`. |
| Link… | Command-K | See the Link rules below. |
| Code | Shift-Command-C | One line: wraps in `` ` ``. Several lines: wraps in a fence. |
| Quote | Command-' | Adds `> ` to each selected line. |
| Toggle Checkbox | Command-Return | Adds `- [ ] ` to each selected line. |
| Heading 1–3 | Option-Command-1 to 3 | Replaces any `#` run at the line start with that level. |
| Body | Option-Command-0 | Removes the `#` run. |
| Bulleted List | Shift-Command-8 | Adds `- ` to each selected line. |

Each command toggles: on a line or selection that already has the format, the command removes it.
Each command applies per line.
The exact cases (a heading inside a list item, a mixed selection, and nested markers) are WAIT-2.
Each command is one undo group.

Link rules:
- Command-K with a selection, and the whole clipboard string is an http or https URL: inserts `[selection](clipboard)`.
- Command-K with a selection and no URL on the clipboard: inserts `[selection](|)` with the caret in the destination.
- Command-K with no selection: inserts `[|]()` with the caret between the brackets.

The format bar shows Bold, Italic, Heading, Bulleted List, Checkbox, Link, Code, and Quote, in that order.
Each button performs the matching command.
A button shows its active state with a filled background and the selected trait.
On Mac, the bar floats 8 pt above the selection, or below it when there is no room. It shows only while text is selected. It hides on typing or scrolling. Esc hides it.
On iOS, the bar docks above the software keyboard. With a hardware keyboard on iPad, it docks at the bottom of the window.
The bar buttons have a 44 pt hit size on iOS.
View › Show Format Bar hides or shows the bar. The app keeps the choice for all windows.
The bar does not show in `.editorLocked` or while `isEditable` is false.

### Undo

Each document has one undo stack.
Autosave does not clear the stack.
A typed word run is one undo group. The group ends on whitespace after 1 s without typing, on a caret jump, on Return, or on a format command.
Each of these is one undo group: a paste, a list continuation, a format command, a checkbox click, Replace All, and a Resolve Apply.
Committed IME composition is one undo group.
Undo reports reason `undo`. Redo reports reason `redo`.
`reload(text:)` clears the stack.

### Paste

`pasteHtml` false inserts the plain-text pasteboard value.
`pasteHtml` true and an HTML pasteboard value use the map below.
The converter drops `script` and `style`, including their text.
The converter ignores `style` and `class`.
The converter uses a hand-written HTML tokenizer in `MarkdownCore`. CI fuzzes it for 10 minutes on each pull request. A later swap to a library parser needs a new design log.
A whitespace-only conversion inserts the plain text instead.
The converter escapes a Markdown character only when the character would otherwise start syntax.
Whitespace collapses as in HTML.
The output is CommonMark and GFM only. It contains no HTML.

| HTML | Markdown |
|---|---|
| `h1`–`h6` | An ATX heading of that level. |
| `p`, `div` | A paragraph. |
| `br` | A line break. Inside a table cell, a space. |
| `strong`, `b` | `**` |
| `em`, `i` | `*` |
| `del`, `s`, `strike` | `~~` |
| `pre`, or `code` that is a block | A fenced code block. |
| inline `code` | A code span. |
| `a` with an https or mailto `href` | `[text](href)` |
| any other `a` | The text only. |
| `ul`, `ol`, `li` | The matching list. Nested lists indent 2 spaces (bullet) or 3 spaces (ordered). `ol start` stays. |
| `blockquote` | `>` |
| `table` | A GFM table. The first row is the header when there is no `thead`. A `colspan` cell puts its content in the first cell and empty cells after it. `|` is escaped. |
| `img` whose source the image rules allow | `![alt](source)` |
| any other `img` | The alt text. |
| a checkbox input | A task item. `checked` gives `[x]`. |
| any other element | Its children, with the tag removed. |

### Images

The library does not load bytes.
The view calls `image(for:)` only for blocks near the viewport.
Fortkeeps returns `.refused` for every destination and uses `imageFallback .link`.

Fortkeeps Scroll classifies the destination with the pure rules in `MarkdownCore`.

A local destination is a relative path.
The app percent-decodes it and resolves it against the document directory.
The resolved path must stay inside that directory.
A path that escapes the directory gives `.refused`.
A symlink that resolves outside the directory gives `.refused`.
The path must be a regular file.
When the sandbox has no access to the directory, the app returns `.needsAccess`.
An untitled document returns `.refused` for every local destination. The VoiceOver hint of that card is "Save the file to show local images." (DRAFT)

A remote destination uses https.
An http destination gives `.refused`.
The app checks the literal host before any DNS lookup.
The app refuses these hosts:
- `localhost`, and a host that ends in `.local`, with or without a trailing dot;
- the IPv4 ranges `0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10`, `127.0.0.0/8`, `169.254.0.0/16`, `172.16.0.0/12`, `192.168.0.0/16`, `198.18.0.0/15`, `224.0.0.0/4`, and `240.0.0.0/4`;
- the IPv6 addresses `::`, `::1`, `fc00::/7`, `fe80::/10`, and an IPv4-mapped IPv6 address in a refused IPv4 range;
- an IPv4 host written in a decimal, octal, or hexadecimal form other than dotted decimal.
A public name that resolves to a private address is not checked.
The timeout is 10 seconds.
The app reads at most 5,000,000 bytes, for remote and for local images.
The app sends no cookies.
The app follows at most 3 redirects.
The app checks the host of each hop.
The app decodes png, jpeg, gif, or webp.
Any other decode gives `.failed(unsupported)`.
A decoded image wider or taller than 8192 pixels gives `.failed(tooLarge)`. The app reads the dimensions from the header before it decodes.
A gif plays, except when Reduce Motion is on, or iOS Auto-Play Animated Images is off. Then the gif shows frame 1 with a play glyph and the accessibility action "Play animation" (DRAFT).

A remote image never loads automatically.
The app returns `.remoteNotLoaded(host)` until the person clicks the card, or presses Return or Space on it.
The context menu item Load All Images in This Document loads every remote image of this document. The app does not remember that choice.
The app writes a loaded image to the image cache.
The image cache is in the app's sandboxed Caches folder.
Every cache file has `isExcludedFromBackup` set. The cache is not synced.
The cache key is the URL.
An entry expires 3 days after its last view. The expiry is one constant.
Each view of a cached image resets its clock.
The app purges expired entries at launch and when the app goes to the background.
A cached image draws with no click and no network request, in any document.
Reload Image in the context menu fetches a fresh copy with the same rules and replaces the entry. On failure the old copy stays, and the card shows "Couldn’t reload this image." (DRAFT)
Settings has Clear Image Cache, with the current size. Clearing is immediate and has no confirmation.

An image fits the text column width at most. The app does not upscale an image.
A drawn image is at most 80% of the viewport height, with its aspect ratio kept.
When the file header gives the dimensions, the view reserves the height. Otherwise, the view reflows once and keeps the first visible text line in place.
A linked image follows its link.
A drawn image has the image trait and its alt text as the label. An image with an empty alt is hidden from VoiceOver.
The editor does not draw an image whose result is not `.image`. It draws the matching card.

### HTML

`html` false draws raw HTML characters as text.
`html` true: WAIT-1. A native-support test decides between a native subset and a sandboxed web view. The test result goes into this log before plan 01 stage 1e starts.
In both outcomes, these rules hold:
- No script runs.
- Nothing loads from the network.
- Images follow the image rules.
- A `javascript:` link does nothing.
- A disallowed tag turns only that tag into text.
- Unsupported HTML shows as dimmed source with a small "HTML" label (DRAFT).

### Links

The view calls `open(_:)` for a link the person follows.
In `.editor`, a click places the caret. Command-click follows the link. On iPhone, a long press shows Open Link.
In `.editorLocked` and `.rendered`, a click follows the link.
Fortkeeps Scroll opens https and http links in the default browser.
Fortkeeps Scroll opens mailto in the default mail app.
Fortkeeps Scroll opens a relative link in a tab when the resolved path stays inside the document directory and the extension is an accepted extension. When that path is already open, the app selects its tab.
The extension test is case-insensitive. The app ignores a query and a fragment for that test.
A `#fragment` link scrolls to the heading with the matching GFM slug and moves VoiceOver focus there. A slug with no heading does nothing.
A sibling link to a file that does not exist shows the popover "“{name}” isn’t in this folder." (DRAFT)
A sibling link while the folder has no access shows the folder-access strip.
Any other link does nothing. On Mac, the app beeps.
On Mac, hovering over a link for 1 s shows its destination in a tooltip.
The context menu of a link has Open Link, Copy Link, and Edit Link.

### Files

The accepted extensions are `.md`, `.markdown`, `.txt`, `.mdown`, and `.mkd`.
The extension test is case-insensitive.
The app refuses any other extension. The app does not open the file.
The refusal body is "Open a .md, .markdown, or .txt file." (DRAFT)
The app refuses a file that is not valid UTF-8, and a file that contains a NUL byte. The app does not open the file.
That refusal body is "This file is not UTF-8, so it was not opened." (DRAFT)
A refusal is an alert. Its title is "Can’t Open “{name}”" on Mac and "Can’t open “{name}”" on iOS (DRAFT). Its only button is OK.
A leading UTF-8 BOM stays in the text.
An empty file opens.
A file over 5 MB opens with a determinate progress indicator, "Opening “{name}”…" (DRAFT), shown after 300 ms. Above 20 MB, the status bar shows "Large file: styling updates as you scroll." (DRAFT)

The app normalizes CRLF, a lone CR, and mixed endings to LF in the buffer.
The app adds a final newline in the buffer when the text has none.
The document is not dirty when that is the only difference.
The file on disk stays unchanged until the first `edit` or `checkbox` change.
The first such change writes the whole text as LF with a final newline.

Mac stores the document in `NSDocument`.
iOS stores the document in `UIDocument`.
The app keeps one document object for one path.
The system schedules autosave for `edit`, `undo`, and `redo` changes.
A `checkbox` change saves immediately. That save also writes pending edits.
Undo or redo of a checkbox change saves immediately.
The app has no Save command for a named document.
File › Save… shows only for an untitled document. The system save panel names it.
The status bar shows "Saved" or "Saving…" (DRAFT) and the word count.

### Outside changes

The app watches the file with a file presenter.
When the file on disk changes and the document has no unsaved edits, the app calls `reload(text:)`, keeps the anchor, and VoiceOver announces "Updated from disk." (DRAFT)
When the document has unsaved edits, the app sets `isEditable` false and shows the outside-change dialog.
On Mac, the dialog is a sheet. On iOS, it is an alert.
The dialog has three buttons: Reload, Resolve…, and Keep Mine.
No button is the default. Return and Esc do nothing.
Initial focus is on the title text, not on a button.
On iOS, Reload has the destructive style, and no button has the cancel role.
Reload calls `reload(text:)` with the disk text. Undo is cleared.
Keep Mine closes the dialog. The next autosave writes the local text over the disk text.
Resolve… opens the Resolve view.

The Resolve view compares the two versions with a line diff in `MarkdownCore`.
On Mac, it is side by side by default. It is inline when the window is narrow or at accessibility text sizes.
Each hunk has Use Mine, Use Theirs, and Use Both.
Apply writes the merged text once, as one undo group with reason `edit`. Undo stays.
Cancel returns to the outside-change dialog. Nothing is written.
When the disk changes again during Resolve, the view shows "The file changed again. Restart with the newest version?" with a Restart button (DRAFT).
The full Resolve layout, keys, and VoiceOver rules are in `001-markdown-library-screens.md` §3.11. That section is part of this Design.

A renamed or moved file updates its title and tab with no dialog.
A deleted file shows the strip "“{name}” was deleted. Your text is still here." (DRAFT) with Save As… and Close. Autosave pauses.
A file with no write permission opens in `.editorLocked`, with the strip "You can read this file but not change it." (DRAFT) and Duplicate.
A failed save shows the strip "Couldn’t save “{name}”. Fortkeeps Scroll will keep trying." (DRAFT) with Save As…. The app keeps the text in memory.

### Windows and chrome

The Mac app uses system document tabs.
The iPad app uses a tab strip. A tab shows the file name and a close control labelled "Close {name}".
The iPhone app shows one file, with a back button to the list "Open Files" (DRAFT). That list has swipe-to-close.
Tab shortcuts are Shift-Command-[ and Shift-Command-], Command-W, and Command-1 to Command-9.
The window title is the file name. The subtitle is the folder.
Light and dark follow the system appearance.
The document surface uses the `pane` color.
The app has no custom animation.
Lock toggles with Option-Command-L and with the toolbar Lock button.
On Mac, Command-+, Command-−, and Command-0 zoom from 80% to 200% in 10% steps. The app keeps the zoom for each document.

On Mac, with no document to restore, the app shows the empty window.
The app also shows it when the last tab closes, and on a Dock click with no window.
The empty window shows the line "Open a Markdown file, or create one." (DRAFT), the buttons Open… and New (DRAFT), and up to 8 recent files.
On iOS, the launch screen is the system document browser. New creates `Untitled.md` in the current folder and opens it with the keyboard up.

Relaunch reopens every document that the person did not close. It restores each document's anchor and Lock.
A dropped folder that contains Markdown files offers "Open Folder in Sidebar". A multi-file drop opens every valid file and shows one alert for the rest.

The folder sidebar shows after the person grants folder access.
It lists the accepted files and the subfolders.
Its actions are New File, Rename, and Move to Trash.
Move to Trash never deletes permanently. Undo restores the file.
New File creates `Untitled.md` (then `Untitled 2.md`) and starts an inline rename.
The Outline sidebar section lists H1–H3. Its empty text is "No headings yet." (DRAFT)

Folder access: when a document has a relative image or a sibling link, and the sandbox has no access to its folder, the app shows one dismissible strip per document per session: "Allow access to “{folder}” to show its images and open linked files." with Allow Access… (DRAFT). Allow Access… opens a folder picker set to the document's folder. The app stores a security-scoped bookmark for each folder. Settings lists the folders and can remove each one. A click on a "needs folder access" placeholder opens the same picker.

Find uses the system find bar on Mac and `UIFindInteraction` on iOS. It searches the source text. Replace All is one undo group. In `.editorLocked`, the replace controls are hidden.

Export: File › Export as PDF…, Export as HTML…, and Print…. PDF and Print use the `.rendered` typography. HTML export is one self-contained file with no scripts. It embeds local images as data and keeps remote images as links. Export never fetches an image. Copy as Rich Text is Option-Command-C.

Settings has: Line width (Narrow, Medium, Wide; Medium is 680 pt), Show word count, the folders with access, and Clear Image Cache. Settings is in-app on iOS.

The full screen list, wireframes, and the accessibility checklist are in `001-markdown-library-screens.md` (Interface, 2026-10-25) and `001-wireframes/`. Those sections are part of this Design, except where this log says otherwise. This log wins over that file.
Where that file conflicts with itself, these rules hold (confirmed by Itay 2026-10-26; the screens file is corrected to match):
- The §3.18 menu table wins over other shortcut mentions. Show Sidebar is Control-Command-S. Option-Command-O focuses the Outline.
- The iPad format bar has the eight buttons of §3.6a, not the three of §3.19.
- A link click follows the Links section of this log (Q2): a click places the caret, Command-click follows, in Lock a click follows, and an iPhone tap places the caret with a long press showing Open Link.

### Accessibility

- Increase Contrast maps `text3` to `text2` and `line2` to `text3`.
- A heading exposes its level.
- Lists, tables, and quotes are announced.
- Reading-view links and checkboxes are in the keyboard Tab order with Full Keyboard Access.
- Return activates a focused link.
- Every screen passes `performAccessibilityAudit()` in UI tests.
- No meaning rests on color alone.

### Color

The app copies these sRGB values:

| Token | Dark | Light |
|---|---|---|
| `pane` | `#161E28` | `#FFFFFF` |
| `text` | `#EDEFF2` | `#1C2430` |
| `text2` | `#B9C2CC` | `#3E4753` |
| `text3` | `#97A1AD` | `#5C6570` |
| `accent` | `#93B9E6` | `#1B3A5F` |
| `pill` | `rgba(255,255,255,.05)` | `#F4F1EB` |
| `line2` | `rgba(255,255,255,.12)` | `#DAD3C7` |

### Fonts

The package ships the static Plex files of log 010 X-10a, copied from remember-mac `design/fonts/static/`, plus the IBM Plex Mono Regular, Medium, and SemiBold files and `OFL.txt`.
`design/fonts/README.md` in the repo records the IBM release tag and the SHA-256 of each file.
The app does not download a font.

### Fortkeeps later

This library is the Markdown source for Fortkeeps plan 18 stages 18e and 18f.
Log 010 stays as written until that work starts.
Fortkeeps consumes the package by SemVer tag after roadmap V1-42 (WAIT-5).
The library passes log 010 conformance cases 01–30 with the Fortkeeps value before 18e starts.
Until the Android design log exists, log 010 stays the Fortkeeps Android reference.
The adoption edit to log 010 records these overrides:
- MD-43: a tick saves immediately.
- Smart quotes off.
- Checkbox value words.

### Copy

Every string marked (DRAFT) comes from `001-markdown-library-screens.md` or from revision 1 of this log.
Story Weaver finalizes them (WAIT-3).
The plan's exact-string tests use the final strings.
The app name inside strings is "Fortkeeps Scroll".

## Examples

A file `note.md` contains:

```markdown
# Title

See [the site](https://example.com) and ~~later~~.

- [ ] One task
```

The editor shows the `#`, the brackets, the URL, and the `~~` in `text3`, with the heading at 22 pt on Mac.
A click on the checkbox writes `- [x] One task` and saves at once.
Command-Z restores `- [ ] One task` and saves at once.
A click on `the site` places the caret. Command-click opens the browser.
Paste of `<strong>Hi</strong>` inserts `**Hi**`.
With `pasteHtml` false, the same paste inserts `Hi`.
With `softBreakAsLine` true, `a⏎b` shows two lines.

The same text in Fortkeeps in `.rendered` mode with `titleLine .hidden` hides `Title`, shows `~~later~~` as characters, and draws the checkbox.

## Trade-offs

- **Chosen:** one library, GFM on, host Bools, a presentation value, and three modes.
  - Pros: Fortkeeps and Scroll share one parser and one styler.
  - Cons: The host must pass the right values.
- **Chosen:** a required `MarkdownHost` protocol.
  - Pros: Every host states every behavior.
  - Cons: A simple host writes more code.
- **Chosen:** a custom outside-change dialog instead of the system conflict interface.
  - Pros: Clear choices, and Resolve.
  - Cons: More code and more copy to maintain.
- **Chosen:** an on-disk image cache.
  - Pros: No repeated clicks or downloads.
  - Cons: The cache stores remote content on the device for 3 days.

## Verification Criteria

1. Each `MarkdownFeatures` default matches the table. The Fortkeeps value matches.
2. With the defaults, a conformance file renders strikethrough, an autolink, a table, and a task. The disallowed tags appear as text.
3. With html, strikethrough, and autolink false, those constructs appear as source characters. `softBreakAsLine` true gives a line break, and false gives a space.
4. The GFM spec tests pass with the defaults. Log 010 cases 01–30 pass with the Fortkeeps value.
5. A mode switch from editor to rendered to editor keeps the caret offset and the first visible line within one line. Undo after the round trip restores the edit.
6. A task click changes one byte and reports `checkbox`. Undo restores the byte and saves at once.
7. Each format command toggles. Return continues a list and ends an empty item.
8. `maxUTF8Bytes` 65536: a 70 KB paste into 60 KB leaves at most 65,536 bytes, with no split grapheme, in one undo group.
9. The paste map matches the table.
10. A remote image makes zero requests until a click. A cached image draws after relaunch with zero requests. An expired entry shows the card.
11. The blocklist refuses each listed form. http is refused. A file over 5,000,000 bytes is refused.
12. The outside-change dialog has no default button. Esc does nothing. Reload clears Undo. Keep Mine writes on the next autosave.
13. Resolve Apply writes once and is one undo group. Cancel writes nothing.
14. Accepted extensions open in either case. Other extensions and invalid UTF-8 show their refusal. Neither writes the file.
15. A CRLF file is not written until the first change. The first change writes LF and a final newline. A BOM remains.
16. Relaunch restores the documents, the anchors, and Lock.
17. `MarkdownCore` has no UI, file, or network import. The analytics denylist check passes.
18. A 64 KiB neighborhood restyle meets the 8 ms budget at the 95th percentile.
19. `performAccessibilityAudit()` passes on every screen. The checkbox value reads `done` or `not done`.

## Known Limitations

A public host name that resolves to a private address is not refused.
A single paragraph larger than 64 KiB is outside the 8 ms budget.
A folder bookmark gives read access to the whole folder.

### Waiting items

| Tag | Item | Who | Blocks |
|---|---|---|---|
| WAIT-1 | The HTML result of the native-support test (native subset or sandboxed web view). | Itay, after the test | The HTML part of plan 01 stage 1e. |
| WAIT-2 | The exact format-command cases. | Interface | Plan 01 stage 1d steps 5–6. |
| WAIT-3 | The final on-screen copy. | Story Weaver | The exact-string tests in plan 02. |
| WAIT-4 | The `FK Scroll` app icon in the Fortkeeps theme. | Interface | Resolved: assets in `design/icon/`. |
| WAIT-5 | Roadmap V1-42: where Fortkeeps' phone code lives. | Itay | Fortkeeps adoption (plan 18) only. No stage here. Reopened 2026-10-26: Android and web app are in phase one. |
| WAIT-6 | Roadmap V1-44: the bundle ID prefix. | Itay | Resolved 2026-10-26: `app.fortkeeps.*`; Scroll is `app.fortkeeps.scroll`. |

WAIT-4 and WAIT-6 are resolved. WAIT-4 was a design task, not an open question. WAIT-5 is open. The other rules of this log are complete.

## Future Work

- Android: the library, Fortkeeps Scroll, and Fortkeeps Android adoption, after the Apple apps ship. A new design log.
- A settings screen for `MarkdownFeatures`.
- Syntax outside GFM.
- A Hebrew UI.
- Name clearance and a trademark search, when the name is final.
- The Fortkeeps adoption edit to log 010 and plan 18, which waits until that plan starts.
