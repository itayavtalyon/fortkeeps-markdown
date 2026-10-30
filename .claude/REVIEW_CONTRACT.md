# Review contract

The shape of the handoff is the Remember key `workflow:stage-review-handoff`. This file holds only the repo details.

- Gate: `just check` (build, test with coverage, MarkdownCore coverage gate, core module trace, iOS build, MarkdownViews tests on an iOS simulator, lint, format check). The iOS step needs an iPhone simulator runtime (`xcodebuild -downloadPlatform iOS`).
- Plans: `implementation-plans/NN-*.md`. Each stage is a `### <stage>` section. Its Implementation Notes are under `## Implementation Notes`.
- Design: `design-logs/001-markdown-library.md` Design section.
- Marker: `.claude/REVIEW_REQUEST` with `stage`, `plan`, `ref`, `decisions` lines. The marker is gitignored.
- A mutation that edits `Package.swift` or `Package.resolved` runs the built test bundle with `xcrun xctest`, because `swift test` re-resolves packages and deletes a stale `Package.resolved`.
