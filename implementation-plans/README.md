# Implementation plans: Fortkeeps Scroll

Source of truth: [`design-logs/001-markdown-library.md`](../design-logs/001-markdown-library.md) revision 3, Design, and [`001-markdown-library-screens.md`](../design-logs/001-markdown-library-screens.md) where the log names it.
Do not invent a rule that Design does not state.
Do not edit remember-mac.
When a step depends on a WAIT item that is not yet written into Design, stop. Ask Itay with a structured question.

## Waiting items

| Tag | Item | Blocks |
|---|---|---|
| WAIT-1 | HTML native-support test result | The HTML part of 01 stage 1e |
| WAIT-2 | Exact format-command cases (Interface) | 01 stage 1d steps 5–6 |
| WAIT-3 | Final copy (Story Weaver) | Exact-string tests in 02 |
| WAIT-4 | `FK Scroll` icon (Interface) | Resolved: assets in `design/icon/` |
| WAIT-5 | Roadmap V1-42 | Fortkeeps adoption only |
| WAIT-6 | Roadmap V1-43 bundle ID prefix | Signing in 02 stages 2c and 2d |

Stages 1a, 1b, 1c, and 1f can start now. Stage 1d can start except steps 5–6. Stage 1e can start except the HTML policy step.

## Steps (do in order)

| # | Plan | Status |
|---|------|--------|
| 01 | [Library](01-library.md) | Not started |
| 02 | [Apps](02-apps.md) | After 01 |
| 03 | [Scroll decisions (log 002)](03-scroll-decisions.md) | Built inside the 01 and 02 stages it names |

## Definition of done (every stage)

A stage is done only when all of these hold:

1. Every step of the stage is built.
2. Every must-pass test of the stage was written before its production code, and it passes.
3. The full test suite passes with zero warnings.
4. The formatter has run last.
5. `MarkdownCore` stays at 100% line and function coverage. A skip needs a written reason.
6. The plan's Implementation Notes name the files, the tests, and every deviation.
7. The implementer has closed the in-session deep review.
8. The Chief Architect has closed the second review of `.claude/REVIEW_REQUEST`.
9. The stage table shows done.

Work each stage on a branch from `main`.
Open one pull request per stage after the second review.
Do not merge it. Itay merges it.
Do not start the next stage until that pull request is merged.
