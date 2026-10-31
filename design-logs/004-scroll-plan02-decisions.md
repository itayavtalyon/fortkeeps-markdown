# 004 - Fortkeeps Scroll plan 02 decisions

Revision 1, 2026-10-31. Written by the plan 02 implementer from Itay's answers to the plan 02 grill questions. Status: Design.
Logs 001, 002, and 003 stay as written. This log amends them. Each decision names the section it amends. Where this log and an earlier log differ, this log wins.
Each stage of plan 02 (`implementation-plans/02-apps.md`) adds its answers here as a new round.

## Background

Plan 02 builds the apps on the library of plan 01. Some plan 02 steps need a rule that logs 001 to 003 do not state.

## Problem

Stage 2a must save a checkbox change at once, also when Undo or Redo replays it. `TextChange` does not say which change an undo replays. Design also does not say what later saves write, whether an empty file gets a final newline, or where the save policy lives.

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

## Trade-offs

- **Chosen:** a `groupReason` field.
  - Pros: The view already knows the undo group. The host does not guess from the bytes.
  - Cons: Every place that makes a `TextChange` passes one more value.
- **Chosen:** normalize every save.
  - Pros: One write function. A file never holds a CR or lacks its final newline.
  - Cons: A person cannot save a file without a final newline.

## Verification Criteria

1. An undo and a redo of a checkbox click report `groupReason` `checkbox`. An undo and a redo of a typed edit report `edit`.
2. A save of an edited text ends with a newline and holds no CR.
3. An empty file and a BOM-only file open with no added newline.
