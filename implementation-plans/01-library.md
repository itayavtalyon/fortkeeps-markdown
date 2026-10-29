# 01 — Library

**Design:** [`design-logs/001-markdown-library.md`](../design-logs/001-markdown-library.md) revision 4: Product, Host interface, View settings, Modes, Features, Parse, Document model, Rendering, Tasks, Direction, Editor, Format commands, Undo, Paste, the pure image rules, HTML, the pure link rules, Accessibility, Color, and Fonts.
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
| 1a | Package, license, fonts, colors, CI guards | In review | — |
| 1b | Parser, features, presentation | In review | — |
| 1c | Document model, anchor, copy text | In review | — |
| 1d | Styler, edits, format commands, undo, byte limit | In review (steps 5–6 base commands built in 1f; WAIT-2 cases wait) | WAIT-2 (exact cases only) |
| 1e | Paste, image and link classifiers, line diff, HTML policy | In review (step 8 waits) | WAIT-1 (step 8 only) |
| 1f | Views, modes, host protocol, cards, accessibility | In review (gaps listed in the 1f notes) | — |
| 1g | Review changes (log 001 revision 5) | Done (Review Notes in the 1g notes) | — |

### 1a — Package, license, fonts, colors, CI guards

1. Work in the repo `fortkeeps-markdown`. Its `main` already holds `README.md` and `LICENSE`.
2. Add the README trademark line from Design.
3. Keep the MIT `LICENSE`.
4. Create the package `FortkeepsMarkdown` for macOS 15 and iOS 18.
5. Add the target `MarkdownCore`.
6. Add the target `MarkdownViews` that depends on `MarkdownCore`.
7. Add a test target for `MarkdownCore`.
8. Add a test target for `MarkdownViews`.
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
- A test fails when `MarkdownCore` or `MarkdownViews` uses `URLSession`, `FileManager`, or `FileHandle`.
- Each color constant equals the Design value.
- Each font file matches its recorded SHA-256.
- The acknowledgements check fails when a resolved package is missing from the list.
- The denylist check fails on a fixture `Package.resolved` that contains Sentry.

### 1b — Parser, features, presentation

1. Add `MarkdownFeatures` with the seven fields and the defaults.
2. Add the Fortkeeps value as a named constant.
3. Add `MarkdownPresentation` with `titleLine` and `imageFallback`.
4. Add swift-cmark from the fork and tag that Design › Product names. (Revision 3 named `swift-markdown` at the newest release tag. Round 8 replaced it.)
5. Record that tag in Implementation Notes.
6. Commit `Package.resolved`.
7. Parse with cmark-gfm, and attach the extensions that the true fields name.
8. Apply the GFM tag filter only when `html` is true.
9. When `html` is false, make each inline HTML node text, and parse each HTML block again as Design › Parse states.

Must-pass tests:

- A new `MarkdownFeatures` matches the default column.
- The Fortkeeps constant matches the Fortkeeps row.
- Defaults render a table, a task, a strike, and an autolink.
- Each false field leaves its construct as text.
- A leading `---` stays a thematic break.
- The disallowed tag names appear as text when `html` is true.
- The GFM spec 0.29 tests pass with the defaults, as Verification 4 states.
- The parse tree of each log 010 case 01–30 matches its `.html` with the Fortkeeps value.

### 1c — Document model, anchor, copy text

1. Build the block list, the heading levels, and each task's byte offset, excluding a leading BOM.
2. Build the base direction of each block.
3. Build the rendered-mode copy string for any selection.
4. Build the line-1 title rule for `titleLine .hidden`.
5. Build `MarkdownAnchor` as a `Codable` value in source byte offsets.
6. Build the map from a source offset to a rendered position and back.
7. Snap a selection on hidden syntax to the nearest content character.
8. Treat a soft break as a space or as a line break by `softBreakAsLine`.
9. Map the source positions of the nodes of a re-parsed HTML block (1b step 9) back to the document. Those nodes carry positions relative to the block.
10. Build the log 010 `.expect.json` fields: title, tasks, block directions, and the card fields (variant, factSize, summary, statusFields, link, visibleLength), by Design › Fortkeeps later.

Must-pass tests:

- A task offset points at the byte between the brackets, with and without a BOM.
- A toggle of that byte, then a second toggle, restores the text.
- A Hebrew block is RTL. A Latin block is LTR. A Hebrew task list puts the checkbox on the trailing edge.
- The copy of a heading, a link, a code span, and a fence matches Design. The copy has no direction marks.
- A drawn image adds no copy characters.
- A source-to-rendered-to-source round trip keeps each offset that is not on hidden syntax.
- An anchor encodes and decodes to the same value.
- With `.hidden`, a tick on line 5 flips the correct byte.
- Every `.expect.json` field of log 010 cases 01–30 matches with the Fortkeeps value and `titleLine .hidden`, and each case passes the toggle test.
- An offset inside a re-parsed HTML block maps to the correct document byte.

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
8. When WAIT-1 is in Design, build the HTML policy from it. Until then, `html` true shows raw HTML as text, the same as `html` false, and the stage notes record that.

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

### 1f — Views, modes, host protocol, cards, accessibility

1. Define `MarkdownHost`, `ImageRequest`, `ImageResult`, `LinkActivation`, and `TextChange` from Design.
2. Keep the working text in the view. Take the initial text at creation. Replace it only through `reload(text:)`. Give the protocol no default implementations.
3. Build one Mac view and one iOS view on TextKit 2 with the three modes.
4. Apply a `mode` or `isEditable` change in place.
5. Keep the anchor on a mode switch, and move VoiceOver focus to it.
6. Map the style tokens to the Design fonts, sizes, and colors.
7. Scale with Dynamic Type on iOS.
8. Build the image cards for each `ImageResult`.
9. Cancel the image task when the view discards a block.
10. Build the format bar for Mac and iOS.
11. Wire the Design shortcuts.
12. Report every change with its reason.
13. Expose the accessibility elements from the model.
14. Turn smart quotes and smart dashes off.

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
- With Reduce Motion on, a gif reports not animating.

### 1g — Review changes (log 001 revision 5)

Build the revision 5 changes on `stage/1f-views`.

1. Create the target and library product `FortkeepsCards`. Move the Fortkeeps card fields and their log 010 checks into it. Remove every card field computation from `MarkdownCore`.
2. Apply the `MarkdownCore` coverage gate and the module trace to `FortkeepsCards`.
3. Make the rendered copy write the list markers, the task markers, and the marker-width indentation from Rendering.
4. Add `imageActivated(_:)` to `MarkdownHost`. Send it from every card that has a button. Do not call `image(for:)` for an activation.
5. Draw each card of the Image cards table with its strings and accessibility label. Draw the `.link` fallback link with "Image" for an empty alt text.
6. Underline iOS links in rendered mode and in the editor. Underline Mac links on keyboard focus.
7. In the editor, draw the one-line image source, the card under it, and the thumbnail once the result is `.image`.
8. In rendered mode, draw code blocks and table rows as boxes, with the fade and the Increase Contrast edge.
9. Reserve an image's height from its file header when the header gives the dimensions.
10. Build the keyboard access from Accessibility for Mac and iOS.
11. Expose heading levels on Mac. Announce lists, tables, and quotes. Follow the iOS Auto-Play Animated Images setting.
12. Add a test that `text3` on `pane` has a contrast ratio of at least 4.5:1 in both appearances.

Must-pass tests:

- A click on Load Image, Try Again, or the folder-access card records one `imageActivated(_:)` and no `image(for:)` call. `refreshImage(destination:)` records one `image(for:)` call.
- Each `ImageResult` draws the card of the Image cards table, with its strings and accessibility label.
- Rendered copy of a nested list with a task gives the markers, `[ ]`, `[x]`, and the marker-width indentation.
- In `.rendered` and `.editorLocked`, Tab visits the links, checkboxes, cards, and wide boxes in reading order, and then leaves the view. In `.editor`, Tab inserts a tab.
- In rendered mode, a code line wider than the column does not wrap, and its box scrolls sideways. Prose next to it wraps. The editor wraps the same line.
- An editor image draws its card under the one-line source, and a thumbnail at most 120 pt tall once the result is `.image`.
- The Mac view exposes each heading level to VoiceOver.
- `FortkeepsCards` passes the log 010 card checks at 100% coverage. `MarkdownCore` computes no card field.
- `text3` on `pane` meets 4.5:1 in light and dark.

## Handover

When the stage definition of done holds except the second review, commit the stage.
Write `.claude/REVIEW_REQUEST` with the stage name, this plan path, and the commit.
Stop.
Do not start the next stage.

## Implementation Notes

### 1a — Package, license, fonts, colors, CI guards

Branch `stage/1a-package` from `origin/main` 3c80aea. Toolchain: Xcode 27.1, Swift 6.4, macOS 27.2, Apple silicon.

**Decisions (Itay, 2026-10-25).** Remember keys `decision:fortkeeps-markdown-fonts-2026-10-25` and `decision:fortkeeps-markdown-acks-2026-10-25`.

- remember-mac has no `design/fonts/static/`. Itay approved downloading the four static Plex Sans files from IBM tag `@ibm/plex-sans@1.1.0`.
- The remember-mac Plex Mono files match no IBM release. Their git blob SHAs differ from every tag from v5.2.1 to `@ibm/plex-mono@2.5.0`. Itay chose to download Plex Mono from `@ibm/plex-mono@1.1.0` instead. This deviates from "copy Plex Mono from remember-mac".
- The fonts live in both `design/fonts/` and `Sources/MarkdownViews/Resources/Fonts/`. One test checks both copies.
- The Acknowledgements list is `Acknowledgements/acknowledgements.json` (`name`, `package`, `license`, `file`) plus one license text file per entry. 1a lists IBM Plex only.

**Files.**

| Step | Files |
|---|---|
| 2 | `README.md` (trademark line) |
| 4–8, 12 | `Package.swift` (tools 6.2, macOS 15, iOS 18, `.treatAllWarnings(as: .error)` on every target) |
| 9–10 | `design/fonts/*`, `Sources/MarkdownViews/Resources/Fonts/*`, `design/fonts/README.md`, `Sources/MarkdownViews/MarkdownViews.swift` (`resourceBundle`) |
| 11 | `Sources/MarkdownCore/DesignColors.swift` (`SRGBColor`, `ColorToken`, `DesignColors`) |
| 13 | `scripts/check-coverage.py`, `Justfile` `coverage-check` |
| 14 | `Acknowledgements/`, `Tests/MarkdownCoreTests/DependencyGuardTests.swift` |
| 15 | `Tests/MarkdownCoreTests/DependencyGuardTests.swift` |
| guards | `Tests/MarkdownCoreTests/SourceGuardTests.swift`, `scripts/check-core-modules.sh` |
| tooling | `Justfile`, `.github/workflows/ci.yml`, `.swiftlint.yml`, `.swiftformat`, `ruff.toml`, `.gitignore`, `.claude/REVIEW_CONTRACT.md` |

**Other deviations and additions.**

- Warnings are errors through `.treatAllWarnings(as: .error)` in the manifest, not through `-Xswiftc` and not through `unsafeFlags`. Proof that a dependent package still builds: a scratch consumer depended on a copy of this package by a `file://` git URL, with an unused-variable warning added to the copy. `swift build` in the consumer printed `Build complete!`.
- The UI-import rule has two checks. `SourceGuardTests` scans the source text, which covers code behind `#if` on every platform. `scripts/check-core-modules.sh` reads the compiler's loaded-module trace on macOS and iOS, which covers an indirect import. A probe showed that `import Cocoa` and `import WebKit` load AppKit, and that the text scan does not see this.
- The file and network rule also flags `fopen`, `InputStream`, `OutputStream`, `NWConnection`, a `contentsOf:` read, and a `write(to:` file write. Design says MarkdownViews does not open a file or a network connection. The three names in the plan alone missed `Data(contentsOf:)`.
- The denylist check scans `Package.swift` as well as `Package.resolved`. A binary target or a path package does not appear in `Package.resolved`.
- The coverage gate fails when a MarkdownCore file is missing from the report. A file with no executable code (for example, a file with only a protocol) therefore fails. When that case appears, add a skip entry with a written reason.
- The repo-level checks are Swift Testing tests in the test targets. They read the checkout through `#filePath`.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| The package builds for macOS and for iOS. | `just build`; `just ios-build` prints `ok: package builds for iOS` |
| A test fails when `MarkdownCore` imports AppKit, UIKit, or SwiftUI. | `no MarkdownCore source imports a UI framework`, `uiImports finds each import form`, `scripts/check-core-modules.sh` |
| A test fails when `MarkdownCore` or `MarkdownViews` uses `URLSession`, `FileManager`, or `FileHandle`. | `library sources use no file or network API` (both folders), `ioUses finds each file or network API` |
| Each color constant equals the Design value. | `each DesignColors token equals its Design dark and light values` (reads the Design table), `every Design table token has a DesignColors constant` |
| Each font file matches its recorded SHA-256. | `each font file matches its recorded SHA-256` (16 cases: 8 files, 2 copies), `each font folder holds exactly the recorded files` |
| The acknowledgements check fails when a resolved package is missing from the list. | `acknowledgements check fails when a resolved package is missing from the list` |
| The denylist check fails on a fixture `Package.resolved` that contains Sentry. | `denylist check fails on a Package.resolved that contains Sentry` (real sentry-cocoa 8.40.1 revision from `git ls-remote`) |

Test helpers have their own tests: `parse reads a hex cell and an rgba cell`, `parse rejects a malformed color cell`, `parse rejects a log with no Color section`, `parse reads the file and SHA-256 cells of each table row`, `parse rejects a SHA-256 cell that is not 64 hex digits`, `parse rejects a file recorded twice`, `hits labels each hit with its file path`, `hits throws for a folder with no Swift file`.

**Mutations.** Each mutation changes one clause. A scratch runner (not committed) applied each mutation, ran the named check, and restored the tree.

| Mutation | Red |
|---|---|
| `pane.dark` red 0x16 → 0x17; `pill.dark` alpha .05 → .06; `line2.light` blue 0xC7 → 0xC8 | `each DesignColors token equals its Design dark and light values` |
| `line2` dropped from the test token list; a new row added to the Design table | `every Design table token has a DesignColors constant` |
| one byte appended to the bundled `IBMPlexSans-Regular.ttf`; to `design/fonts/IBMPlexMono-Medium.ttf` | `each font file matches its recorded SHA-256` |
| extra file in the bundled Fonts folder; a bundled font deleted; a README row removed | `each font folder holds exactly the recorded files` |
| README SHA-256 changed by one digit | `each font file matches its recorded SHA-256` |
| `FontRecord` duplicate check removed; hex check removed | `parse rejects a file recorded twice`; `parse rejects a SHA-256 cell that is not 64 hex digits` |
| color parser: rgba part count check removed; hex length check removed | `parse rejects a malformed color cell` |
| color parser: stop at the next heading removed | `parse reads a hex cell and an rgba cell` |
| `import AppKit` in `DesignColors.swift`; `#if os(iOS) import UIKit`; `import SwiftUI` in a subfolder | `no MarkdownCore source imports a UI framework` |
| `import AppKit`; `#if os(macOS) import Cocoa`; `#if os(macOS) import WebKit` | `check-core-modules.sh`: `MarkdownCore loads a UI framework on macos` |
| `#if os(iOS) import UIKit` | `check-core-modules.sh`: `... on ios` |
| `FileManager` in MarkdownViews; `URLSession` in MarkdownCore; `Data(contentsOf:)` in MarkdownViews | `library sources use no file or network API` |
| `append(` exclusion removed; `insert(` exclusion removed; `&` exclusion of `write(to:` removed; word boundary on the API names removed | `ioUses ignores code that does no I/O` |
| `hits` empty-folder throw removed | `hits throws for a folder with no Swift file` |
| repo `Package.resolved` with an unacknowledged swift-markdown pin | `repo Acknowledgements list names every package in Package.resolved` (the same pin with an entry stays green) |
| `.package(` in `Package.swift` with no `Package.resolved` | `repo Acknowledgements list names every package in Package.resolved` |
| `missingAcknowledgements` filter replaced | `acknowledgements check fails when a resolved package is missing from the list` |
| repo `Package.resolved` with sentry-cocoa; `Package.swift` with a Sentry binary target | `repo manifest files link no denylisted package` |
| denylist match made case-sensitive | `denylist check fails on a Package.resolved that contains Sentry`, `denylist check finds each listed vendor in a dependency URL` |
| `Sentry` removed from the denylist | `denylist check fails on a Package.resolved that contains Sentry` |
| untested public function in MarkdownCore | coverage gate: `1 uncovered function(s)` |
| covered function with an unmarked uncovered line | coverage gate: the line is listed |
| the same line marked `// coverage:ignore` with no reason | coverage gate fails; with `- <reason>` it passes |
| MarkdownCore file with only a protocol | coverage gate: `not in the coverage report` |
| unused `let` in MarkdownCore | `swift build`: `error: initialization of immutable value 'unused' was never used` |
| `import AppKit` in MarkdownViews | `just ios-build`: `Unable to resolve module dependency: 'AppKit'` |

Two mutants first went red for the wrong reason, so they were run again as valid code. `import AppKit` broke the iOS build before the trace was read. The script now checks each trace right after its build. A global `let` of `FileManager` failed on a concurrency error; a function form replaced it. The word boundaries before `contentsOf:` and `write(to:` survived their mutants, so they were removed. Without them the rules are stricter.

Repo-file mutants ran against the built bundle with `xcrun xctest`. `swift build` and `swift test --skip-build` re-resolve packages: a stale `Package.resolved` was deleted (`ls Package.resolved` after `swift build`: no such file).

**Probes past the plan.**

- `scripts/check-coverage.py` with no argument: usage, exit 2. With a missing file, a non-JSON file, or `{}`: `error: cannot read coverage report ...`, exit 1.
- A non-UTF-8 `Package.resolved` fails `repo Acknowledgements list names every package in Package.resolved` and `repo manifest files link no denylisted package`. It is not treated as missing.
- Import forms `@_spi(Internal) import AppKit` and a tab-separated `import\tSwiftUI` were missed at first. Both are now test cases and are found.

**Simplify pass.**

1. The test-only `Row` type was replaced by `ColorToken`: about 5 lines.
2. The four font tests became two parametrized tests over both copies, and the SHA test has no loop: about 14 lines.
3. The two source scans share `SourceGuard.hits`: about 8 lines.
4. The unused `import MarkdownCore` in MarkdownViews was removed: 1 line.
5. Not shrunk: `FontFilesTests` repeats the three-line repo-root lookup from `RepoPath`, because the two test targets cannot share a file without a shared test-support target.

**Not verified here.** The CI workflow has not run. It runs when the stage pull request opens.


### 1b — Parser, features, presentation

Branch `stage/1b-parser`, stacked on `stage/1a-package` (Itay said to keep implementing before the 1a pull request merged). Toolchain as 1a. Machine: Apple M1 Max.

**Decisions (Itay, 2026-10-25).** Remember keys `decision:fortkeeps-markdown-parser-2026-10-25` and `decision:fortkeeps-markdown-cmark-fork-2026-10-25`. Design log 001 revision 4 records them (Round 8).

- swift-markdown 0.9.0 cannot follow the feature fields. `CommonMarkConverter.parseString` always attaches `table`, `strikethrough`, and `tasklist`, never attaches `autolink` or `tagfilter`, and turns on smart punctuation unless told not to. Itay chose cmark-gfm directly. swift-markdown is dropped.
- cmark-gfm's tasklist extension has two bugs: `- [ ] buy [x] item` is checked (`strstr` over the line), and a task inside a block quote is never found (the scanner runs from offset 0 of the raw line). Both are unchanged in github/cmark-gfm since 2019. Itay chose a fork: `github.com/itayavtalyon/swift-cmark`, branch `fix/tasklist-marker`, tag `0.9.0-fortkeeps.1` (commit a2f7fe6). **Pinned tag: `0.9.0-fortkeeps.1`** (step 5).
- html false parses each HTML block again as full Markdown (Itay replaced "one paragraph, parsed inline"). Inline-only mode was tried first: it puts the whole input on line 1, so soft breaks never form (XML of `<div>\na\nb\n</div>` with `CMARK_OPT_INLINE_ONLY`: one text node `\na\nb\n`, all `sourcepos="1:..."`).
- Log 010: Itay chose the tree check plus the card fields in MarkdownCore. **Agent call, for Itay to confirm in the PR:** the card fields, title, tasks, and directions go into 1c (steps 9–10), because the card fields need the title and the tasks. 1b checks the tree only.
- **Agent call, for Itay to confirm in the PR:** the 10 GFM spec examples that conflict with a default extension are pinned to the extension output (Design Verification 4). Upstream runs those examples with no extensions; `MarkdownFeatures` cannot express "raw HTML without the tag filter".
- Design correction: cmark-gfm is the GFM spec 0.29 (CommonMark 0.29). Revisions 1–3 said 0.31.2. Any cmark-gfm parser, swift-markdown included, has the same base.

**Files.**

| Step | Files |
|---|---|
| 1–3 | `Sources/MarkdownCore/MarkdownFeatures.swift` |
| 4–6 | `Package.swift`, `Package.resolved`, `Acknowledgements/acknowledgements.json`, `Acknowledgements/swift-cmark.txt` (swift-cmark `COPYING`: BSD-2-Clause plus MIT notices) |
| 7–9 | `Sources/MarkdownCore/ParsedMarkdown.swift` (internal; 1c builds the public model on it) |
| tests | `MarkdownFeaturesTests`, `ParsedMarkdownTests`, `GFMSpecTests`, `Log010ConformanceTests`, `HTMLShape(Tests)` |
| fixtures | `Tests/MarkdownCoreTests/Fixtures/gfm-spec/spec.txt` (swift-cmark 0.9.0 `test/spec.txt`, CC BY-SA 4.0, not shipped), `Fixtures/log010/` (remember-mac c673327 `design/markdown-conformance/cases`) |
| fork | `itayavtalyon/swift-cmark`: `extensions/tasklist.c`, `test/regression.txt` (7 new examples) |

`Package.swift` excludes `Fixtures` from the test target; the tests read the files from the checkout. Without the exclude, SwiftPM warns about 91 unhandled files.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| A new `MarkdownFeatures` matches the default column. | `a new MarkdownFeatures matches the Design default column` |
| The Fortkeeps constant matches the Fortkeeps row. | `the Fortkeeps value matches the Design Fortkeeps row` |
| Defaults render a table, a task, a strike, and an autolink. | `defaults render a table`, `... a task`, `... a strikethrough`, `... a bare URL as a link` |
| Each false field leaves its construct as text. | `tables false ...`, `taskLists false ...`, `strikethrough false ...`, `autolink false leaves a bare URL as text`, `html false shows inline HTML as text`, `softBreakAsLine true ...` |
| A leading `---` stays a thematic break. | `a leading thematic break line stays a thematic break` |
| The disallowed tag names appear as text when `html` is true. | `defaults show a disallowed tag as text` (all nine names), `defaults keep an allowed tag next to a disallowed one` |
| The GFM spec tests pass with the defaults. | `each GFM spec example renders its HTML with the defaults` (660), `a CommonMark HTML block example shows its disallowed tag as text with the defaults` (5), `a CommonMark example links its bare URL with the defaults` (5), `the spec fixture holds every example` (670 + 2 disabled) |
| Log 010 cases 01–30 (tree). | `each log 010 case parses to the reference tree with the Fortkeeps value` (30), `the fixture holds cases 01 to 30` |

The tag-filter expectations come from the spec's own HTML with the filter rule applied in the test. The autolink expectations were written by hand from the GFM autolink rules before the run (616 included). Example 610 differs from the spec text: cmark-gfm `url_match` has no preceding-character check, while `www_match` has one (autolink.c line 180).

Log 010 tree check: `HTMLShape` compares element names, `href`, `checked`, and text with entities decoded and whitespace collapsed (the case README: compare structure, not attributes). `img` becomes the `Image: {alt}` link of `imageFallback .link`. Before the fork and the HTML-block re-parse, cases 12 and 21 failed; both pass now.

**Fork verification.** `ctest` in the fork: 9 of 9 suites pass (spec, extensions, regression, smart punctuation, round trip, API). A differential run of unfixed 0.9.0 against the fix over all 748 examples of `spec.txt`, `extensions.txt`, `regression.txt`, and `smart_punct.txt` with every extension: only the 3 new regression examples differ. A second differential over 25 task edge forms (padding, tabs, `[]`, `[ ]x`, a marker on a later line, a marker at line end): no difference outside the fixed cases. Two behaviours of the first fix draft differed there (`- [ ]` at line end became a task, and a marker on the item's second line became a task); the final fix keeps the original scanner's spacechar class (space, tab, VT, FF) and requires the marker on the line that opens the item.

**Mutations (Swift).** One clause each; the tree restored after each.

| Mutation | Red |
|---|---|
| default `strikethrough` false | `a new MarkdownFeatures matches the Design default column`, `defaults render a strikethrough` |
| Fortkeeps keeps `html` on | `the Fortkeeps value matches the Design Fortkeeps row` |
| presentation default `.hidden`; `.link` | `a new MarkdownPresentation shows the title line in the body and images as text` |
| `table` follows `taskLists`; `strikethrough` follows `autolink`; `autolink` follows `strikethrough`; `tasklist` follows `tables` | the matching `... false ...` test |
| `tagfilter` never | `defaults show a disallowed tag as text`, `defaults keep an allowed tag next to a disallowed one` |
| `UNSAFE` never | `defaults keep raw HTML` and both tag-filter tests |
| `HARDBREAKS` never | `softBreakAsLine true ...`, `html false gives a former HTML block line breaks with softBreakAsLine` |
| html-false pass never runs | 6 `html false ...` tests |
| inline HTML not made text | `html false shows inline HTML as text`, `html false shows a disallowed tag as text` |
| every line with `<` neutralized (probe skipped) | `html false keeps an autolink that starts a line of a former HTML block` |
| only the first line neutralized | `html false converts every HTML block` and 5 more |
| only the first HTML block converted | `html false converts every HTML block` |
| sentinel ignores the literal | `html false keeps a control character that was already in an HTML block` |
| backslash fallback empty | `html false neutralizes an HTML block whose text holds every spare control character` |
| tab allowed as a sentinel | `html false never uses a tab as the stand-in for a bracket` |
| restore never runs; skips text; skips code | 6 tests; 6 tests; `html false restores a neutralized bracket inside a code span` |
| former block kept in the tree | 6 tests |
| pre-check allows no indent | traps on `precondition(startsWithBracket)` with `html false turns a three-space-indented HTML block into a paragraph` (before the opener rule, this mutant recursed forever; that showed the need for the rule) |
| `nodes()` ignores the type filter | traps on the `literal(of:)` unwrap (a container node has no literal) |

Equivalent mutants, kept on purpose: the opener sent through the probe (an opener alone always opens an HTML block; the opener rule makes termination independent of the probe), and a looser indent pre-check (the probe still decides; the pre-check only skips probes). Timing evidence for the pre-check: 4.66 s before and 3.59 s after (debug build, 4.7 MB of HTML blocks); the probe without extensions brought it to 0.85 s in release.

**Mutations (C, fork).** Each mutant recompiled with the object file, the extension archive, and the binary deleted first. An earlier batch kept a stale binary because make compares times by the second; its results were discarded.

| Mutation | Red regression example |
|---|---|
| start-line check removed | marker on a later line (32) |
| line end allowed after the marker | `- [ ]` at line end (31) |
| checked from `strstr` over the line | `- [ ] buy [x] item` (27) |
| marker searched at column 2 | block quote (28), nested quote (29) |
| `X` not accepted | nested quote `[X]` (29) |
| `]` check removed; `[` check removed; any middle character | near-miss markers (33) |

Equivalent: `marker + 3 >= len` against `> len` (the line buffer ends with NUL, which is not a task space; `>=` kept so nothing reads past `len`), and advancing 3 from the offset (at that point the offset equals the first non-space position for every form tried, tabs included; the explicit `marker - offset + 3` stays correct if it ever does not).

**Probes past the plan.** Empty text, a lone BOM, a BOM before a heading, CRLF inside an HTML block, a NUL byte (becomes U+FFFD), trailing double spaces in an HTML block (hard breaks, as CommonMark), 200 nested quotes and 200 nested lists around an HTML block: no crash, output as CommonMark gives. `cmark_gfm_core_extensions_ensure_registered` is guarded by `CMARK_RUN_ONCE`, so a parse may run on any thread.

**Coverage.** `preconditionFailure(message)` and `precondition(_, message)` create autoclosures that count as uncovered functions (Remember `lesson:swift-coverage-autoclosure`). The NULL-on-malloc guards are force unwraps with a per-line SwiftLint disable and a reason. The one `precondition` has no message.

**Simplify pass.**

1. The inline-only init and its helpers were removed by the full re-parse: about 10 lines.
2. The two iterator loops became one `nodes(in:ofType:)`: about 12 lines.
3. `HTMLShape.attribute` uses a Foundation regex range instead of a force-tried `Regex`, and the entity decoder has one numeric branch: about 6 lines.
4. Not shrunk: the extension table in `makeParser`; a dictionary is the same size and loses the order.

**For 1c.** Nodes of a re-parsed HTML block carry positions relative to the block (step 9). The sentinel keeps byte lengths, so the mapping is the block's start line plus the per-line container prefix.

**Not verified here.** CI has not run; nothing is pushed in this repo. The upstream pull requests are drafted, not opened.

### 1c — Document model, anchor, copy text

Branch `stage/1c-model`, stacked on `stage/1b-parser`. Itay asked to continue the plan and to run the deep review at the end of plan 01. The upstream tasklist PRs are open as drafts: swiftlang/swift-cmark#103 and github/cmark-gfm#396 (Remember `decision:fortkeeps-markdown-cmark-fork-prs`). github/cmark-gfm shares a fork network with swift-cmark, so both PR heads live in `itayavtalyon/swift-cmark`.

**Files.**

| Step | Files |
|---|---|
| 1, 2, 4, 8, 9 | `Sources/MarkdownCore/MarkdownDocument.swift` (public model, title, toggle, anchor, snap), `DocumentBuilder.swift`, `DocumentBuilder+Text.swift`, `DocumentBuilder+Cmark.swift` (one tree walk), `TextDirection.swift`, `ParsedMarkdown.swift` (`move`: positions of a re-parsed HTML block) |
| 3, 6, 7 | `Sources/MarkdownCore/RenderedText.swift` (rendered string, runs, both maps, copy) |
| 5 | `Sources/MarkdownCore/MarkdownAnchor.swift` |
| 10 | `Sources/MarkdownCore/FortkeepsCard.swift`, `SavedLink.swift` |
| tests | `MarkdownDocumentTests`, `RenderedTextTests`, `CorpusAlignmentTests`, `FortkeepsCardTests`, `SavedLinkTests`, `Log010ConformanceTests` (expect.json and toggle), `GivenDocument.swift` |

**Model.** `MarkdownDocument(text:features:presentation:)` drops a leading BOM, parses once, and walks the cmark tree once. It holds the top-level `blocks` (kind, 0-based line, source range, direction), the `tasks` (line, byte offset, checked, text, direction), the line-1 `title`, and `rendered`. `RenderedText` holds the drawn string (UTF-16 positions, the unit TextKit uses), one line-level `Block` per paragraph, heading, code block, HTML block, rule, or table row (separated by one `\n`), the links, the images (one U+FFFC each), and the runs that map rendered UTF-16 to source bytes.

**Implementer choices for the deep review** (Design leaves them open):

- A table row draws its cells separated by a tab, and copies that way.
- A list bullet and a checkbox are not characters in `string`; the view draws them from the block (`listDepth`, `taskIndex`).
- An item with no content (`- [ ] `) gets an empty paragraph block, so the checkbox has a line.
- A source offset on hidden syntax snaps to the nearest rendered caret position; a tie snaps forward. A selection start snaps forward and its end snaps back (`snappedSelection`).
- `copyText(_:imagesDrawnAsText:)`: the view says which images drew as text; those copy `Image: {alt}`.
- `MarkdownAnchor` holds `block` (the first visible top-level block's start), `offsetInBlock`, and `selection`, all in source bytes.
- `TextDirection.markerEdge` names the chrome edge (`.trailing` for RTL), because Design says "trailing edge" of the LTR chrome.

**Conflict to report (log 010).** The conformance README asks a second toggle to give the original bytes. MD-29 and Design › Tasks turn `X` into a space and a space into `x`, so `[X]` comes back as `[x]`. The toggle test follows MD-29 and pins `X → space → x`.

**swift-cmark 0.9.0 inline positions.** Probes showed three wrong positions: a code span that spans lines ends on its first line (`1:2-1:4` for `` `a\nb` ``); an inline on a lazy or indented continuation line is shifted by the first line's indentation (spec 52, 63, 192); the autolink extension leaves empty text nodes and links with an end before their start (`3:27-3:23`, log 010 case 30). Block positions are right. So the aligner treats an inline's start as a hint: the hint is used when the whole literal aligns from it and it is not behind the last run; otherwise the first offset after the last run where the literal aligns is used. The search is bounded by the top-level block's end. The aligner matches an entity before the same byte, an escape before the same byte (and falls through when the escaped byte is not the literal's), skips whitespace, and makes a scalar with no match stand for one source scalar. Code and HTML blocks align line by line, bounded by each source line.

`CorpusAlignmentTests` pins the result: over all 670 spec examples and the 30 log 010 cases, with the defaults and with the Fortkeeps value, every drawn character maps to its source, except breaks, tabs, images, entities, NUL, and the second scalar of an entity that decodes to two scalars (`&ngE;`). Progress of that count while fixing: 646, 203, 39, 16, 2 (the expected entity tail), then the test.

Bugs found by tests and coverage while building, all fixed with a test: an entity followed by text left the rest of the node unmapped; a task with two images repeated the first alt; a code span across CRLF lost its second line; `&x;` text was treated as an entity; an escaped backslash shifted later characters.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| A task offset points at the byte between the brackets, with and without a BOM. | `a task offset points at the byte between the brackets`, `a task offset excludes a leading BOM`, `a task offset inside a nested quote and list is exact` |
| A toggle of that byte, then a second toggle, restores the text. | `toggleTask twice restores the text`, `toggleTask flips the marker byte` (3 cases) |
| Hebrew RTL, Latin LTR, Hebrew task checkbox on the trailing edge. | `a Hebrew block is RTL and a Latin block is LTR`, `a Hebrew task list puts the checkbox on the trailing edge`, `an Arabic block is RTL`, `a CJK block is LTR`, `a block with no strong letter follows its parent`, `a code block inside a Hebrew quote stays LTR` |
| Copy of a heading, a link, a code span, and a fence; no direction marks. | `copy of a heading, a link, a code span, and a fence drops the syntax`, `copy has no direction marks` |
| A drawn image adds no copy characters. | `a drawn image adds no copy characters`, `an image drawn as text copies that text` |
| A round trip keeps each offset that is not on hidden syntax. | `a source to rendered to source round trip keeps each offset that is not on hidden syntax`, `every drawn character of the corpus maps to its source ...` (2) |
| An anchor encodes and decodes to the same value. | `an anchor encodes and decodes to the same value` |
| With `.hidden`, a tick on line 5 flips the correct byte. | `with the title hidden a tick on line 5 flips the correct byte` |
| Every `.expect.json` field of cases 01–30 and the toggle test. | `each log 010 case matches every expect.json field with the Fortkeeps value` (30), `each log 010 task toggles exactly one byte and toggles back by MD-29` (30) |
| An offset inside a re-parsed HTML block maps to the document byte. | `an offset inside a re-parsed HTML block maps to the document byte`, `a task inside a quoted former HTML block has the right offset` |

**Mutations.** 70 one-clause mutants over the builder, the aligner, the maps, the title, toggle, anchor, direction, card, saved link, and the HTML position move. Each is red, with the red tests recorded in the session; the ones that first survived each got a test (hard break, CRLF code span, `&;`, code block in a Hebrew quote, CJK and Arabic direction, lone CR, image-only block copy, snap tie, title not on line 1, H2 on line 1, fact-size boundaries, link before title, one field, one-letter field, doc fields, four lines before a URL, root path, earlier URL line, quoted HTML-block task). Several mutants are red only by an invariant trap (`precondition` on the task marker, the run-lookup unwrap), which is the fail-fast check firing. Three survivors were equivalent and their code was removed: the punctuation test on escapes, the non-empty entity name, and the code-line suffix fast path. Two equivalent survivors stay on purpose: the early stop of the zero-length run walk (performance) and refusing a hint behind the cursor (runs must not overlap for the binary search). The mutation runner first reported a crashed test process as a survivor; it now reports crashes and build failures, and every mutant that had been reported before that change was run again.

**Coverage.** The unbounded range `x[...]` compiles to a closure that counts as an uncovered function; `Substring(x)` replaces it. `??` fallbacks that cannot run were restructured (each task records its leaf; the scalar of a run that holds an offset is a justified force unwrap).

**Performance (release, Apple M1 Max).** A 2 MB document builds its model in 0.32 s; Copy of all of it takes 0.02 s. Lookups use binary search over runs.

**Simplify pass.** (1) The builder became a top-level type in three files, and leaf content follows from the leaf kind (one switch instead of a 13-branch one). (2) `appendLines` lost its suffix fast path (equivalent to the per-character aligner). (3) Two equivalent clauses in the aligner were removed. (4) Not shrunk: `FortkeepsCard` and `SavedLink` mirror `generate.py` line by line on purpose, so a reviewer can compare them.

**For 1d.** The styler should reuse `DocumentBuilder.span` and the aligner rules where it needs source positions.

### 1d — Styler, edits, format commands, undo, byte limit

Branch `stage/1d-editor`, stacked on `stage/1c-model`. Steps 5–6 (format commands) wait on WAIT-2 and are not built; the Command-K and toggle must-pass tests wait with them.

**Files.** `Sources/MarkdownCore/MarkdownStyler.swift` (public styler, tokens, line state, `styleText`, `neighborhood`, `CodeFence`), `LineScanner.swift` (block syntax of one line), `InlineStyler.swift` (inline spans from an inline-only cmark parse), `Editing.swift` (`TextEdit`, `ListContinuation`, `UndoGrouping`, `ByteLimit`). Tests: `MarkdownStylerTests`, `EditingTests`, `StylerTimingTests`. `Justfile`: `timing`.

**Design of the styler.** It styles one line at a time (log 010 X-16). The only state a line hands to the next is an open code fence (`LineState`). Block syntax comes from line rules: quote markers, a fence, list markers, a task marker after a list marker, an ATX heading, a table delimiter row, and pipes of a row that starts with `|`. Inline syntax comes from cmark with `CMARK_OPT_INLINE_ONLY` over the line's content: a node's range minus its children's range is syntax. A single line keeps cmark's positions right, except the autolink extension's, so a bare URL is found by search. A block style (heading, quote, fence code) comes before the inline spans that start where it starts. Positions are UTF-16 offsets.

**Implementer choices for the deep review.**

- A heading's syntax span holds the `#` run and the blanks after it; a quote's holds `>` and one space; a list marker's holds the marker and its blanks.
- A table row is a line whose content starts with `|`; a row without a leading pipe is not dimmed.
- A setext heading and a closing `#` sequence are not styled; a thematic break is not dimmed (neither is in Design's syntax list).
- An image's alt text is not styled; the image collapse to one dimmed line belongs to the view (1f).
- The caret counts as inside a task marker from just before `[` to just after `]`.
- A plain Return (no list) and a caret jump close the typing run. Return, a format command, paste, list continuation, a checkbox click, Replace All, Resolve Apply, and a committed IME composition are each their own group (`UndoGrouping.Decision.ownGroup`). A typed run ends when a run that ends in whitespace is followed by typing at least 1 s later.
- List continuation writes one space after the marker, keeps the quote prefix and the indentation, increments an ordered number, and keeps `.` or `)`. Return on an item with only its marker removes the marker and inserts no newline.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| One token test for each syntax Design lists. | `a heading dims its hashes ...`, `strong dims each double asterisk`, `emphasis dims each asterisk and each underscore`, `a code span dims its backticks`, `a quote dims its marker ...`, `a list marker is dimmed` (5), `a link dims its brackets and destination ...`, `a table row dims its pipes`, `a table delimiter row is dimmed`, `a code fence line is dimmed and opens a fence`, `strikethrough dims its tildes when strikethrough is on`, `tildes are text when strikethrough is off` |
| A plain paragraph returns no syntax token. | `a plain paragraph has no syntax token` |
| The caret-inside-marker case returns the raw marker. | `the caret inside a task marker shows the raw marker` |
| Return in `- [x] a` yields `- [ ] `. | `pressing Return in a task item continues with an unchecked task` |
| Return on an empty item ends the list. | `pressing Return on an empty item ends the list` (3) |
| "hello world" with a 1 s pause, then one undo, removes "world" only. | `hello world typed with a 1 s pause then one undo removes world only` |
| A paste is one undo group. | `an edit of its own kind is one undo group and ends the typing run` (paste and 7 more) |
| 70 KB into 60 KB with 65,536: at most 65,536 bytes, no split grapheme, one group. | `a 70 KB paste into 60 KB with a 65,536 limit keeps the longest whole-grapheme prefix`, `the cut never splits a grapheme`; the cut and the insertion are one `TextEdit`, so one group |
| 8 ms budget (steps 10–11). | `just timing`: `timing: 65325 bytes, 1071 restyles, p95 0.000169958 seconds, chip Apple M1 Max`. The default run skips the suite (`.enabled(if: FORTKEEPS_TIMING == "1")`). |

**Mutations.** 38 one-clause mutants over the scanner, the inline styler, the styler, and the editing helpers. The ten that first survived each got a test (fence of the other character, closing run with text, `[X]`, seven hashes, `#x`, `---`, escaped pipe, row without a leading pipe, heading after a list marker, a pause of exactly 1 s). One survivor was equivalent and removed: the empty-selection test on an empty item (the marker pattern takes every blank, so an empty item never has content to select). One mutant was malformed (`nil ?? x`) and was run again in a valid form; it is red.

**Coverage.** Two `??` fallbacks that cannot run were restructured (an ordered number of at most nine digits is a justified force unwrap; the neighborhood line is a count of line feeds). The padding loops of a code span were dead code (cmark's code range already spans the padding) and were removed.

**Simplify pass.** (1) The code-span syntax is three `add` calls over cmark's range (8 lines removed). (2) `readQuotes` is a conditional loop instead of `while true`. (3) The fence type moved out of `LineState` and owns its `closes` rule. (4) Not shrunk: the scanner's small readers stay separate, one per block construct, so each maps to one Design line.

### 1e — Paste, image and link classifiers, line diff, HTML policy

Branch `stage/1e-paste`, stacked on `stage/1d-editor`.

**Step 8 (HTML policy) waits on WAIT-1.** Until then `html` true shows raw HTML as text: the rendered model draws an HTML block's literal and an inline HTML node's characters as plain text, as it does for `html` false. The one difference is structure: `html` false re-parses an HTML block as Markdown (1b), `html` true keeps one block of literal text.

**Files.** `PasteConverter.swift` (`pasteText`, `markdown(fromHTML:)`, block renderer, table renderer), `InlineRenderer.swift` (atoms, whitespace collapse, emphasis, links, images, code spans), `MarkdownEscaper.swift`, `HTMLParser.swift` (hand-written tokenizer and tree builder, `HTMLNode`), `ImageRules.swift` (`ImageSource`, `ImageRules`, `URLScheme`, `FolderPath`), `IPAddress.swift`, `LinkRules.swift` (`LinkTarget`, `LinkRules`, `GFMSlug`), `LineDiff.swift`, and `MarkdownDocument.headingBlock(forFragment:)`. Tests: `PasteConverterTests`, `PasteGoldenTests` (20 samples in `Fixtures/paste`), `PasteFuzzTests`, `ImageRulesTests`, `LinkRulesTests`, `LineDiffTests`. `Justfile`: `fuzz`. CI: a 10-minute fuzz step.

**Implementer choices for the deep review.**

- A line break is a backslash and a newline (`\` at the line end), visible but robust where trailing spaces are not.
- Spaces at the edge of an emphasis move outside it (`a<b> bold </b>c` → `a **bold** c`), so the delimiters stay flanking.
- A link destination with a space, a parenthesis, or `<`/`>` is wrapped in `<…>`.
- A list item's nested blocks are indented by the marker's width: 2 for `- `, 3 for `1. ` (as Design says), 4 for `10. `.
- A `code` element that holds a line break is a block (a fence); any other `code` is a code span.
- `hr` follows the table's last row (its children, so nothing).
- Entities decode through cmark's own HTML5 table (`houdini_unescape_html_f`), so every named entity is covered without a second table.
- Escaping: `` ` `` and `[` always; `*` and `~` when either neighbor is not a space; `_` the same, except inside a word; `<` before a letter, `/`, `!`, or `?`; `&` before a name that cmark decodes (`&unknown;` stays); `\` before ASCII punctuation; `|` in a table cell; at a line start, the first character of a heading, quote, list item, ordered marker delimiter, thematic break, or setext underline.
- Image rules: a local destination is a relative path; an absolute path is refused even inside the folder. A host whose dot-separated parts are all numbers (decimal, octal, `0x` hex, or empty) is an IPv4 literal and is refused unless it is canonical dotted decimal outside the blocked ranges. An unreadable IPv6 literal (a zone index included) is refused.
- Link rules: http and https need a host. A sibling link drops its query and fragment before the extension test and is percent-decoded.
- GFM slugs follow github-slugger: lowercased, letters, numbers, marks, `_`, and `-` kept, each space a `-`; a taken slug gets the first free `-1`, `-2`.
- The line diff uses the standard library's `difference(from:)` (Myers) on lines and groups adjacent removals and insertions into hunks.
- Nesting deeper than 64 elements is flattened into the deepest open element. At 256 a recursive walk overflowed the stack of a test thread (signal 10).

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| Each row of the paste table has one test. | `PasteConverterTests`: headings (6), p/div, br, br in a cell, strong/b, em/i, del/s/strike, pre, block code, inline code, https/mailto link, other link (5), ul nesting, ol nesting and start, blockquote, table header, thead, colspan, pipe, allowed image, other image (4), checkbox input, other element |
| A `script` body does not appear. | `a script body does not appear`, `a style element and its text are dropped` |
| Escaping happens only where a character would start syntax. | `escaping happens only where a character would start syntax` (19), `escaped text renders as the original text` (20, parsed back by cmark) |
| A colspan cell puts its content in the first cell and empty cells after it. | `a colspan cell puts its content in the first cell and empty cells after it`, golden `15-colspan-report` |
| A golden corpus of 20 clipboard samples converts to fixed output. | `each clipboard sample converts to its golden Markdown` (20; expected files written by hand) |
| The converter runs under a 10-minute fuzz test in CI with no crash. | CI step `just fuzz`; local run: `fuzz: 1073107 samples in 600.0 s`, passed. The first local run trapped at sample 664,507 (NUL bytes before a code span drove the aligner's search range backwards); the input is now `a text with NUL bytes and control characters builds` |
| A relative path inside the directory is local. | `a relative path inside the document folder is local` (6) |
| `../` outside the directory is refused. | `a path that leaves the document folder or is not a plain relative path is refused` (6) |
| An untitled document refuses a local path. | `an untitled document refuses a local path` |
| https is remote. http is refused. | `https is remote`, `any other scheme is refused` (6) |
| Each blocklist form is refused, including the five named forms. | `each blocklist form is refused` (49), `a public host is allowed` (11) |
| A data URL is refused. | `any other scheme is refused` (`data:`) |
| A sibling `.MD` link is an in-app open. | `a sibling file with an accepted extension opens in the app` (6) |
| `#intro` resolves to the GFM slug. | `a fragment link names its decoded fragment`, `a heading slug follows the GFM rule` (9), `duplicate headings get numbered slugs`, `a fragment finds its heading block` |
| `javascript:` is none. | `any other link does nothing` (9) |
| The line diff gives the expected hunks; all "theirs" gives the second text. | `the line diff gives the expected hunks`, `applying every theirs choice gives the second text`, `applying every mine choice gives the first text`, `both keeps mine then theirs` |

**Mutations.** 82 one-clause mutants. The first survivors each got a test (an absolute path inside the folder, a bracketed public IPv6 host, `8.8.8.256`, a `thead` after the body), and six malformed mutants (an unused variable after the edit) were run again in valid form; all red. Equivalent survivors whose code was removed: the `//` scheme-relative branch (the folder rule refuses a leading `/`), octal parsing (a non-canonical form is refused on its form), the per-base slug count (the taken set gives the same slugs), the implied `</p>` (the block walk renders a nested block the same), and the non-empty test on an IPv4 part (an empty part now blocks the host, which is safer). One equivalent survivor stays: the `UInt8` parse of an octet next to the printed-back comparison (either one rejects 256). Two mutants are red only by a crash, which is the evidence: removing the depth cap overflows the stack, and an ungrouped hunk loop never ends.

**Coverage.** `HTMLNode` became a struct with an empty name for text, which removed enum accessors that no caller reached on text. `?? fallbacks` that cannot run became `reduce` (widths, backtick runs) or a justified force unwrap (heading level from `h1`…`h6`; byte slices cut at ASCII bytes are valid UTF-8).

**Simplify pass.** (1) The five equivalent clauses above were removed (about 25 lines). (2) The raw-text end check compares bytes case-folded instead of decoding a slice. (3) The IPv4 check is two branches (hex or digits) and one canonical test. (4) Not shrunk: the tokenizer keeps separate readers for tags, names, attributes, and values; each maps to one HTML rule the fuzz test exercises.


### 1f — Views, modes, host protocol, cards, accessibility

Branch `stage/1f-views`, stacked on `stage/1e-paste`. Format commands (1d steps 5–6) were built here as base commands ahead of WAIT-2 (`decision:fortkeeps-markdown-1f-scope-2026-10-26`): each command adds its format and a second run removes it; the exact WAIT-2 cases are not built.

**Files.** `Sources/MarkdownViews`: `MarkdownHost.swift` (protocol, `ImageRequest`, `ImageResult`, `ImageFailure`, `LinkActivation`, `LinkModifiers`, `TextChange`, `MarkdownMode`), `MarkdownTextController.swift` and `+Links.swift` (the one owner of view behavior: text, mode, edits, undo groups, checkboxes, links, copy, image requests), `MarkdownDisplay.swift` (keeps a text storage in step with the controller: styled source, rendered text, neighborhood restyle, 300 ms full restyle up to 20 MB, image attachments), `MarkdownAttributedText.swift` (tokens and blocks to attributes), `MarkdownTheme.swift` (Design fonts, sizes, colors, Increase Contrast, Dynamic Type), `MarkdownLayoutFragment.swift` (draws checkboxes, bullets, numbers, quote bars, code block backgrounds, rules), `FormatActions.swift` (the commands, shortcuts, and bar buttons in one table), `ImageCardContent.swift` and `ImageAttachment.swift` (what each `ImageResult` draws), and per platform `MarkdownView+AppKit.swift`/`+UIKit.swift`, `MarkdownNSTextView.swift`/`MarkdownUITextView.swift`, `FormatBar+AppKit.swift`/`+UIKit.swift`, `ImageCardView+AppKit.swift`/`+UIKit.swift`. `MarkdownCore`: `RenderedText.Block.listMarker` (bullet or number of an item's first block), `MarkdownStyler.styleText(_:entering:caret:)`, `RenderedText.spans` (inline styles in rendered offsets). Tests: `MarkdownTextControllerTests`, `MarkdownTextControllerModeTests` (both against `RecordingHost`), `MarkdownViewMacTests`, `MarkdownViewIOSTests`, `ImageCardContentTests`. `Justfile`: `ios-test` (in `check`), `scripts/ios-test.sh` (first available iPhone simulator, or `FORTKEEPS_IOS_SIMULATOR`).

**Design.** The controller holds the working text and every rule; the platform views are thin. A typed edit is applied by the text view and reported to the controller (`textViewDidReplace`); every other change (format command, Return in a list, checkbox, undo, redo, reload, a byte-limit cut) is applied by the controller and the display syncs the changed stretch. Undo is the controller's `UndoManager` with `UndoGrouping` groups; NSTextView's own undo is off, and UITextView's `undoManager` returns the controller's. The rendered string keeps `RenderedText` offsets exactly: markers and checkboxes are drawn by the layout fragment, and each image is its U+FFFC with an attachment view, so the source map, copy, and anchors need no second map.

**Implementer choices for the deep review.**

- `.refused` draws the "can't be shown" card with the `.text` fallback and the `Image: {alt}` link with `.link`. Design's host table says the card; Round 1 and `imageFallback` say `Image: {alt}`. Only `.link` copies `Image: {alt}`.
- Clicking a card, Load Image, Try Again, or the folder-access placeholder calls `image(for:)` again. The protocol has no "the person asked" signal, so the host tells a click from its own state (a second request for the same destination).
- Failure reasons read "Too large", "Timed out", "Unsupported format", "Network error" (`img.reason.*`); the `Image: {alt}` link is `img.link`. These keys are not in the screens doc.
- The format bar's Heading button opens a menu of Heading 1–3 and Body. A shortcut works when the view's text view is first responder; `perform(_:)` is public for the host's menus.
- A list item's bullet or number is drawn, not a character, so rendered copy has no bullets (Design lists no rule). Each list or quote level indents 22 pt; each quote level draws its bar 4 pt into its indent.
- A checked task's words are `text3` in the editor too.
- Undo puts the caret at the end of the restored text.
- `isEditable` false on Mac makes the text view non-editable, so a typed key beeps by AppKit's default.
- Edit › Substitutions is the host's menu; the view only starts with smart quotes and dashes off.

**Not built in 1f (needs a decision or belongs to plan 02).**

- The editor does not draw images or cards, and `![alt](url)` does not collapse to one line. Images draw in rendered mode only. Drawing under a source line in TextKit 2 needs reserved height that no character carries; this needs a layout choice.
- A code block wraps and a wide table wraps; neither scrolls horizontally. One text container cannot scroll one paragraph sideways; this needs a layout choice (an attachment view per block would break selection and copy across blocks).
- The view reserves an image's height only after the bytes arrive (from the decoded size), not from the file header.
- Full Keyboard Access Tab order for reading-view links and checkboxes, Return on a focused link, Space on a focused checkbox, and Mac ⌃F6 into the format bar. VoiceOver press works on checkboxes and cards.
- Heading levels reach VoiceOver on iOS (`accessibilityTextHeadingLevel`); the Mac view does not expose them. Lists, tables, and quotes have no announcement attribute.
- Link underline on hover is Mac only; focus underline and iOS pointer hover are not built.
- iOS Auto-Play Animated Images is not read; only Reduce Motion stops a gif.
- `performAccessibilityAudit()` runs in the apps' UI tests (plan 02). Whether UIKit also registers its own typing undo in the controller's manager can only be checked with a real keyboard, in the app's UI tests.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| A view test double records an image request for a near block and a cancellation for a discarded block. | `an image near the viewport is requested and a discarded one is cancelled` (`RecordingHost`) |
| `open(_:)` on Command-click in `.editor` and click in `.editorLocked`; nothing on a plain click in `.editor`. | `a Command-click in the editor opens the link`, `a click opens the link in the locked editor and in rendered mode` (2), `a plain click in the editor opens nothing` |
| A checkbox click reports `checkbox`. In `.editorLocked`, the checkbox reports not enabled. | `a checkbox click flips the byte and reports checkbox`, `in the locked editor a checkbox is not enabled and a click changes nothing`, and on the drawn box: `a click on a drawn checkbox toggles the task` (Mac, 2 modes), `a tap on a drawn checkbox toggles the task` (iOS, 2 modes) |
| Editor → rendered → editor keeps the caret and the first visible line within one line; Undo restores the pre-switch edit. | `a switch to rendered and back keeps the caret, the first visible line, and Undo` (Mac and iOS, real layout), `a switch from editor to rendered to editor keeps the caret offset and undo restores the edit` |
| `reload(text:)` clears Undo and reports `reload`. | `reload replaces the text, clears undo, and reports reload` |
| The format bar buttons report the same text as the shortcuts. | `each format bar button gives the same text as its shortcut` (Mac: button vs key event, 11; iOS: button vs `UIKeyCommand`, 11) |
| The checkbox accessibility value is `done` or `not done`. | `the checkbox accessibility value is done or not done and its label is the task text` |
| The editor spellchecks. Rendered mode does not. | `the editor spellchecks and rendered mode does not` (controller, Mac, iOS) |
| `~~` is dimmed only when `strikethrough` is true. | `tildes are dimmed only when strikethrough is on` (Mac and iOS, the drawn color in the light appearance) |
| Copy separates blocks with one newline. | `copy in rendered mode separates blocks with one newline` |
| Select All and Copy on a 2 MB document equal the model copy string. | `select all and copy on a 2 MB document equal the model copy` (Mac `writeSelection`, iOS `copy(_:)` into a named pasteboard) |
| With Reduce Motion on, a gif reports not animating. | `with Reduce Motion on a gif reports not animating` |

Also: smart quotes and dashes off (Mac, iOS), a typed edit and its Undo, the byte-limit cut through the text view, Return in a list (iOS), the format bar only in the editor (iOS), the card for each `ImageResult` and the empty-alt rule (`ImageCardContentTests`), Increase Contrast (`increase Contrast maps text3 to text2 and line2 to text3`).

**iOS.** `just ios-test` runs the view tests on the simulator (iOS 27.0 runtime installed with `xcodebuild -downloadPlatform iOS`): every MarkdownViews test passes on iPhone 18 Pro (iOS 27.0). UIKit consults the text view delegate only for keyboard input, which a logic test without a host app cannot send, so `MarkdownViewIOSTests.type(_:in:)` calls the delegate in UIKit's order. A byte-limit cut is applied by the controller (`replaceCut`), not by a second insert inside the delegate callback; the first version crashed on iOS when UIKit then moved the caret by the full proposed length, and view selections are now clamped to the text.

**Mutations.** 50 one-clause mutants over the controller, its links and images extension, the core additions (list markers, `styleText` entering state, the inline style lookup), the theme, the card content, and the shortcut match. Twelve first survived and each got a test: a format command and Return while not editable, a caret move ending the typing run, a checkbox after a BOM, the rendered checkbox of the second task, copy in the locked editor, the `Image: {alt}` copy only with `.link`, an image one viewport below the visible range, a refresh clearing the cached result, a cancelled request leaving no result, and a shortcut typed with Shift. Eight mutants did not build (an unused variable after the edit) and were run again in valid form; four of those then survived and got tests (a selection past the end, unchecking a checked task, a non-empty selection across a mode switch, a Command-click on a link's destination). The mode-switch test found a bug: the selection end mapped back with forward affinity and took the closing `**`; the end now uses backward affinity, as `snappedSelection` does. One survivor was equivalent and removed: resetting the open undo group after an own group (UndoGrouping opens a new group after one anyway). The iOS-only crash (a cut caret past the end) is covered on iOS by `an insertion past the byte limit keeps the prefix that fits`.

**Simplify pass.** (1) The host API both views share (`text`, `anchor`, `reload(text:)`, `refreshImage(destination:)`, `perform(_:)`) is one extension in `MarkdownView+Shared.swift`; only one `MarkdownView` compiles per platform, so no protocol is needed. (2) A mode switch redraws once: `setMode` no longer calls `onDisplayChange`, since the view rebuilds for the new mode. (3) The equivalent undo-group clause above was removed. (4) The byte-limit cut goes through the controller on both platforms instead of a re-entrant insert. (5) Not shrunk: the two platform views keep their own event wiring (delegate callbacks, gestures, key commands); they share no types to factor.

**Coverage.** MarkdownCore stays at 100% lines and functions. Two short-circuit autoclosures in `FormatCommands.prefixLines` were reached only by empty lines and now have tests (`a line command keeps an empty line inside a selection empty`, `a line command on one empty line adds its prefix`). The inline styles moved into one lookup in `walkInlines`'s default branch, which removed an unreachable `default`. MarkdownViews has no coverage gate; its tests are the must-pass list above.

### 1g — Review changes (log 001 revision 5)

Built on `stage/1f-views` after Itay's plan 01 review. Decisions: `decision:fortkeeps-markdown-plan01-review-2026-10-27`, `-plan01-review-2-`, `-plan01-review-3-`, `-rev5-grill-`, `-rev5-cards-`, `-rev5-boxes-2026-10-27`. Revision 5 of log 001 records them (Round 9).

**Files.** `Sources/FortkeepsCards` (`FortkeepsCard`, `SavedLink`, moved from `MarkdownCore`) and `Tests/FortkeepsCardsTests` (card tests, saved-link tests, `Log010CardTests`); `scripts/check-coverage.py` and `scripts/check-core-modules.sh` gate both modules. `MarkdownCore`: `RenderedText.Block.copyPrefix`, `copyText(_:imagesDrawnAsText:listMarkers:)`. `MarkdownViews`: `MarkdownHost.imageActivated(_:)`, `MarkdownTextController.activateImage(destination:)`, `ImageCardContent` (the Image cards table), `EditorImages.swift` (editor cards and thumbnails), `BoxView+AppKit.swift`/`+UIKit.swift` and `MarkdownAttributedText+Blocks.swift` (boxes), `MarkdownTextController+Focus.swift`, `KeyboardFocus.swift`, `KeyboardFocus+AppKit.swift`/`+UIKit.swift` (keyboard access), `BlockElement` in `MarkdownNSTextView.swift` (VoiceOver blocks). Tests: `KeyboardFocusMacTests`, `KeyboardFocusIOSTests`, `MarkdownViewMacLayoutTests`, and additions to the existing suites.

**Design of the hard parts.**

- Editor images: the line that holds an image source gets paragraph spacing equal to its cards and thumbnails, so the space is part of layout and every caret and selection rectangle stays exact. The layout fragment draws the marks in that space. A click hit-tests the fragment above the point too, since the spacing lies below the fragment's frame. While typing, the neighborhood restyle parses only its three lines to find their images.
- Boxes: a probe showed TextKit 2 clamps caret and selection rectangles to the text container and ignores a shifted fragment frame or a negative indent, so a line cannot scroll sideways inside the document's text view. Rendered mode lays a box's lines out unwrapped (`byClipping`) and places a box view over each laid-out box wider than the column; the box view scrolls its own copy of the characters, draws the fade, and mirrors the main selection. The document text underneath keeps every offset, so copy and the source map are unchanged. Itay chose to keep the editor wrapping (`-rev5-boxes-`).
- Keyboard: the controller lists the focusable elements in reading order; each view keeps a focused element, draws the ring, and routes Tab, Shift-Tab, Return, Space, the arrows, and Esc. A box that fits the column is skipped when Tab reaches it.

**Implementer choices for the deep review.**

- A selection that starts inside a list item copies no marker for that item; a block whose start is in the selection copies its prefix. Design states the prefix, not partial selections.
- A line that holds an image source and other text keeps wrapping; only a line that is only the image source truncates to one line. Truncating a mixed line would hide its text.
- The rendered `Image: {alt}` copy also reads "Image" for an empty alt, to match the drawn link. `FortkeepsCards` keeps its marker-free visible text for `visibleLength`.
- A card in the editor uses the `.text` fallback: the editor draws the refused card, not the link.
- The focus ring starts at the first element; Tab does not start from the caret.
- Mac heading elements use the `AXHeading` role with the level as the value on macOS 26, and a role description "heading level N" before it. Lists, tables, and quotes are accessibility elements near the viewport. On iOS, heading levels and block kinds are text attributes (`accessibilityTextHeadingLevel`, `accessibilityTextCustom`).
- The image size comes from the header (ImageIO, 72 dpi as 1x); a reflow keeps the first visible line in place.

**Not built or not verifiable here.**

- ⌃F6 into the Mac format bar and its arrow keys are wired but not tested: they need a key window. Check them in plan 02's UI tests.
- Whether VoiceOver uses the Mac block elements and the iOS custom attributes as intended needs a person with VoiceOver; the tests check the elements and attributes exist with the right roles and values.

**Must-pass tests.**

| Must-pass test | Proof |
|---|---|
| A click on Load Image, Try Again, or the folder-access card records one `imageActivated(_:)` and no `image(for:)` call. `refreshImage(destination:)` records one `image(for:)` call. | `an activation tells the host once, draws loading, and does not ask for the image`, `a click on an editor card activates the image` (Mac), `a tap on an editor card activates the image` (iOS) |
| Each `ImageResult` draws the card of the Image cards table, with its strings and accessibility label. | `ImageCardContentTests` (12) |
| Rendered copy of a nested list with a task gives the markers, `[ ]`, `[x]`, and the marker-width indentation. | `copy writes list markers, task boxes, and the parent marker widths`, `copy from inside a list item has no marker for that item`, `an empty task item copies its marker and box` |
| In `.rendered` and `.editorLocked`, Tab visits the links, checkboxes, cards, and wide boxes in reading order, and then leaves the view. In `.editor`, Tab inserts a tab. | `tab visits links, checkboxes, cards, and wide boxes in reading order, then leaves`, `the locked editor focuses links and checkboxes, and the editor leaves tab to the text`, `return opens a focused link, space toggles ...`, `the arrows scroll a focused box and escape clears focus` (Mac); the iOS suite |
| In rendered mode, a code line wider than the column does not wrap, and its box scrolls sideways. Prose next to it wraps. The editor wraps the same line. | `a wide code block scrolls sideways in its own box in rendered mode`, `a code block that fits gets no box view`, `the editor wraps a wide code line` (Mac and iOS) |
| An editor image draws its card under the one-line source, and a thumbnail at most 120 pt tall once the result is `.image`. | `an editor image draws its card under its one-line source`, `an editor image becomes a thumbnail at most 120 points tall`, `the caret inside an image source lets it wrap` |
| The Mac view exposes each heading level to VoiceOver. | `voiceOver reads each heading with its level, and lists, tables, and quotes` (Mac); `voiceOver reads heading levels and the kind of a list, table, or quote` (iOS) |
| `FortkeepsCards` passes the log 010 card checks at 100% coverage. `MarkdownCore` computes no card field. | `Log010CardTests` (30 cases); `coverage gate: OK (MarkdownCore and FortkeepsCards 100%)`; a probe function added to `SavedLink.swift` failed the gate |
| `text3` on `pane` meets 4.5:1 in light and dark. | `text3 on pane meets 4.5 to 1 in light and dark` (5.91 and 6.41) |

Also: `an image size comes from its header`, `link text is underlined and its destination is not` (iOS, both modes).

**Gate.** `just check` passes: 275 MarkdownCore, 17 FortkeepsCards, and 93 MarkdownViews tests on macOS; the MarkdownViews tests on the iPhone 18 Pro simulator; coverage 100% for both pure modules; the module trace on macOS and iOS for both; lint and format.

**Mutations.** 28 one-clause mutants over the copy prefix, the card table, the activation, the focus targets and keys, the editor images, the boxes, and the layout offset. Five first survived and each got a test: Space on a link and Return on a checkbox do nothing, Return on a `.link`-fallback image opens its destination, a card without a button does nothing, and an image drawn as text with an empty alt copies "Image". One mutant did not build (code the compiler proved dead) and was run again in a valid form; it is red, with `a table's rows are one box`. A coverage gap found one more: the empty-task copy branch only runs for an empty task item between other blocks (`- [ ]` with nothing after it is not a task in GFM), and the test now uses that case.

**Review Notes (second opinion, 2026-10-27).** Reviewed 73a5c48 in a clean worktree against the six decisions in the marker. Gate green before and after the fixes: `just check` with 101 macOS MarkdownViews tests, 275 MarkdownCore, 17 FortkeepsCards, coverage 100%, the module trace, and the iOS simulator tests.

- Bug (from 1f): every table body row lost its column tab stops. The block loop set each row's paragraph style after the header row had tabulated the whole table, so only the header aligned. Tables are tabulated in `markBoxes` after the loop. Test: `a table's body rows take its header row's column stops`.
- Bug: two adjacent tables were one box, one Tab stop, and one column set. `BoxMark.runs` starts a table at a header row and is the one grouping for boxes, columns, and focus. Tests: `two adjacent tables are two boxes`, `two adjacent tables are two focus boxes`.
- Bug: `headerSize` ignored EXIF orientation, so a phone photo (orientation 6) reserved 400x300 and drew 300x400. Orientations 5 to 8 swap the sides. Test: `an image size from its header follows a quarter-turn orientation`.
- Simplify: one `updateBoxes` for both views (`BoxGeometry.isWide` replaces three copies of the width check; `BoxView.update` loses the `padding` that was always 0); `ImageCardContent.cardSize` replaces two copies of the card height; `FocusKey` removed (activate takes `FocusInput`); the editor-image click rule moved to the controller (`click(_:)`); `refreshImage` notifies through `onImageChange`, so the public refresh keeps the first visible line. Sources net -25 lines.
- Performance: an image result in the editor ran a full synchronous restyle of the whole document, with no 20 MB limit. It now redecorates only the lines that hold that destination.
- Mutations: 18 one-clause mutants over the fixes and the moved code. Four survived and got tests: a click away from an editor card returns false, the card height per line, Space on a card with a button, and the refresh notification. One is equivalent and stays: `lineBreakMode` is set both ways in `decorateEditorImages`, because every caret move already restyles the old and new lines.
- Grill: Itay accepted the four implementer choices (no marker for a partial list item, mixed image lines keep wrapping, Tab starts at the first element, the Mac heading role description before macOS 26). Recorded as `decision:fortkeeps-markdown-1g-review-2026-10-27`.
- Keystroke restyle (fixed 2026-10-28, Itay asked). `restyle(around:)` copied the whole text into `Array(text.utf16)` and counted newlines with a generic count, and `MarkdownStyler.neighborhood` scanned the whole text twice. `StylerTimingTests` ran the neighborhood and the copy outside its clock, so the budget test could not see them. Now `neighborhood` scans only its three lines (a differential run against the old version agreed on 37,527 random texts and offsets, with emoji, CRLF, and offsets past the end), the region is sliced from the string, and `MarkdownDisplay.newlines` counts line feeds with a plain loop over the UTF-8 buffer. p95 per keystroke through the display, release build, M1 Max (`DisplayTimingTests`, plus one probe run at the larger sizes): 64 KiB 2.5 ms to 0.4 ms; 2 MB 13 ms after; 20 MB 855 ms to 125 ms. The rest is NSTextStorage: one attribute write costs about 5 to 12 ms at 20 MB, because its cost grows with the document's attribute runs. `just timing` now also runs `DisplayTimingTests` (64 KiB, the neighborhood lookup and the attribute writes inside the clock); it needs `-enable-testing` in the release build. Tests: `an offset just after a line feed is on the next line`, `the neighborhood counts UTF-16 units and stops past the end`, `newlines counts the line feeds before an index`, `newlines counts a bridged string the same way`, `a neighborhood restyle near a fence matches the full style` (2 carets; the first test of the fence state that enters a neighborhood). Mutants: 12 one-clause, all red after the tests; 3 survived the first run (the last byte before the index, the entering line off by one, the region start) and got the tests above.
- Not fixed, for later: a keystroke on a 2 MB text or larger is over the 8 ms budget because of NSTextStorage attribute writes; Design states the budget at 64 KiB. `EditorImageMark` decodes the image on every decoration of its line. iOS box views do not mirror the main selection (the Mac ones do). The whole-plan review below replaces the 300 ms full restyle.

## Whole-plan Review Notes (2026-10-29)

Whole-plan deep review of stages 1a–1g at 01d2575, with the simplicity and adversarial lenses. Commits 6629efc, 97bf4da, c8fa515 on `stage/1f-views`. Design log 001 revision 6 (Round 10) records Itay's answers: `decision:fortkeeps-markdown-plan01-whole-review-2026-10-29`. Not pushed; Itay chose to wait on the pull request.

**Hostile input (fixed, each with a test that a one-clause mutant turns red).**

- `<ol start="9223372036854775807">` with two items crashed the app (overflow on the next number). The start and every number stay in CommonMark's 0–999999999; a start of `-3` gave a paragraph, now `0.`.
- `colspan` was capped per cell, not per row: 5 KB of pasted HTML became 30 MB of Markdown. A row keeps its first 1000 columns (0.6 MB for the same paste).
- `MarkdownEscaper` built the rest of the text for each `&`: 32,000 `&amp;` took 25 s. It reads at most the longest entity (33 characters): 0.9 s, linear.
- A pasted `href="https://e.com/>)![x](https://t.example/p.png"` closed its `<…>` destination early and injected a remote image. A destination now drops tabs and line breaks, escapes its backslashes, and escapes `<` and `>` inside angle brackets; an alt text escapes its backslashes (`alt="a\"` broke the image).
- The image host blocklist passed `%31%32%37.0.0.1` and `127.0.0.1%2E`; a host with a percent escape is refused. It also passed IPv6 forms that carry an IPv4 address (`::127.0.0.1`, `64:ff9b::a00:1`, `2002:7f00:1::`); the carried address is now checked (Round 10). Not covered (Design): a public name that resolves to a private address.
- A task with 20,000 images (140 KB) took 20 s to open and Copy 16 s: each `U+FFFC` searched every image. `RenderedText` finds images and blocks by binary search; open 0.15 s, Copy 0.02 s.

**Performance (fixed).** Release build, Apple M1 Max.

- The editor's 300 ms full restyle took 5.7 s on a 2 MB text (styler 2.6 s, attribute writes 3.0 s) after every typing pause, up to 20 MB. Since 1g a scroll after an edit also parsed the whole text (0.3 s at 2 MB). Now the display restyles forward from the neighborhood while a line leaves a fence state different from the one stored for it (Round 10); the viewport parses only the lines near it; an image result redecorates only the lines whose marks show it. No editor path parses the whole text after open.
- Every keystroke copied the whole text: the controller's `apply` (79 ms at 20 MB), the format bar's 11 `isActive` checks (485 ms), `ByteLimit` (4 ms at 2 MB), and Return in a list. They now read only the lines they touch (`MarkdownStyler.lines(touching:in:)`): 0.2 ms and 0.1 ms at 20 MB.
- `tasks(in:)` first called a whole-text `copyText` per task, which made the 2 MB view test take 4 minutes; `copyText` now reads only its range.

**Correctness (fixed).** An image on a lazy or indented continuation line (`para\n   ![m](x.png)`, `- [ ] t\n![m](x.png)`) took cmark's shifted position, so the editor dimmed the wrong characters and drew its card under the wrong line. The image starts at its own `![` after the last run, with cmark's length before the cut at the text end. Task text reads an empty-alt image as `Image`, as copy does (it read `Image: `).

**Tests that found what review missed.** A seeded differential (`random line edits of fenced text leave the same styles as a full build`, 300 edits; 10 more seeds × 300 run once) compares the incremental display with a fresh build after each edit. It found the image position bug and the editor image region problem below. The full restyle had no test before; fence propagation now has six.

**Simplify.** One `partition` helper replaces four binary searches in `RenderedText`; `DocumentBuilder.visibleText` is gone (task text comes from `copyText`); one `ParsedMarkdown.literal(of:)`; the full-restyle machinery (`fullRestyleLimit`, the restyle task, `fullRestyle`) is gone; `imageDisplayOffset` (dead) is gone; `::` and `::1` need no special case (they carry 0.0.0.0 and 0.0.0.1); `Lines` lost its dead line-start search; the code command's ternary is two cases. Sources: 313 lines added, 192 removed, mostly the fixes. Not shrunk, noted: `HTMLNode.attribute(_:)` wraps a dictionary read; `clickCheckbox` is the same in both text views; the AppKit and UIKit image card views mirror each other; `ParsedMarkdown.html()` serves only the conformance tests.

**Mutations.** 54 one-clause mutants over every change. Survivors got tests (an empty task at a copy's start, `isActive` on a later line, a line split in its middle, the caret past the neighborhood, the entering state on line 1, a second edit below a new fence). Equivalent and kept: splicing the line states one line later (the shifted entry is either inside the restyled neighborhood or unknown, which restyles one more line). The mutation runner first reported a failed build as red (a test with a wrong enum label); it now requires a named failing test or a crashed test process, and each result without one was rerun in a form that builds.

**Gate.** `just check` passes on c8fa515: 117 MarkdownViews, 285 MarkdownCore, and 17 FortkeepsCards tests on macOS, coverage 100% for both pure modules, the module trace, the iOS build, the MarkdownViews tests on iPhone 18 Pro, lint, and format. `just timing`: the 64 KiB display restyle p95 is 0.60 ms; the styler alone 0.12 ms.

**Open, for Itay or plan 02.**

- Editor images are found by parsing only the restyled lines (with their code lines blanked). An inline that spans lines from above the region, such as a code span, can change what reads as an image until the region covers it. The differential uses whole-line edits for this reason.
- Opening a large text in the editor still styles it all at once (5.7 s at 2 MB). Design's progress indicator for files over 5 MB is plan 02. Its DRAFT status line "Large file: styling updates as you scroll" names a 20 MB rule that no longer exists in the editor.
- A keystroke at 2 MB takes about 13 ms and at 20 MB about 125 ms, in NSTextStorage attribute writes; Round 10 keeps the 8 ms budget at 64 KiB.
- `EditorImageMark` decodes its image on every decoration of its line; iOS box views do not mirror the main selection.
- `scripts/check-coverage.py` prints a traceback, not a message, when `llvm-cov show` fails (for example after a filtered test run).

