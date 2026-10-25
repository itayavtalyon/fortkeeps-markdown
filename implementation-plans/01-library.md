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
| 1a | Package, license, fonts, colors, CI guards | In review | — |
| 1b | Parser, features, presentation | Not started | — |
| 1c | Document model, anchor, copy text | Not started | — |
| 1d | Styler, edits, format commands, undo, byte limit | Not started | WAIT-2 (steps 5–6 only) |
| 1e | Paste, image and link classifiers, line diff, HTML policy | Not started | WAIT-1 (step 8 only) |
| 1f | Views, modes, host protocol, cards, accessibility | Not started | — |

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
- The GFM spec tests pass with the defaults.
- Log 010 cases 01–30 pass with the Fortkeeps value and `titleLine .hidden`.

### 1c — Document model, anchor, copy text

1. Build the block list, the heading levels, and each task's byte offset, excluding a leading BOM.
2. Build the base direction of each block.
3. Build the rendered-mode copy string for any selection.
4. Build the line-1 title rule for `titleLine .hidden`.
5. Build `MarkdownAnchor` as a `Codable` value in source byte offsets.
6. Build the map from a source offset to a rendered position and back.
7. Snap a selection on hidden syntax to the nearest content character.
8. Treat a soft break as a space or as a line break by `softBreakAsLine`.

Must-pass tests:

- A task offset points at the byte between the brackets, with and without a BOM.
- A toggle of that byte, then a second toggle, restores the text.
- A Hebrew block is RTL. A Latin block is LTR. A Hebrew task list puts the checkbox on the trailing edge.
- The copy of a heading, a link, a code span, and a fence matches Design. The copy has no direction marks.
- A drawn image adds no copy characters.
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

