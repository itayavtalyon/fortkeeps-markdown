# Review contract

The shape of the handoff is the Remember key `workflow:stage-review-handoff`. This file holds only the repo details.

- Gate: `just check` (build, test, the coverage gate of MarkdownCore, FortkeepsCards, and ScrollSupport, core module trace, iOS build, the MarkdownViews and ScrollSupport tests on an iOS simulator with the iOS-only coverage gate, the Mac app UI tests, the iOS app's document types and UI tests on an iPhone and an iPad simulator, lint, format check). The simulator steps need an iPhone simulator runtime (`xcodebuild -downloadPlatform iOS`), and the UI tests need an unlocked screen.
- Plans: `implementation-plans/NN-*.md`. Each stage is a `### <stage>` section. Its Implementation Notes are under `## Implementation Notes`.
- Design: `design-logs/001-markdown-library.md` Design section.
- Marker: `.claude/REVIEW_REQUEST` with `stage`, `plan`, `ref`, `decisions` lines. The marker is gitignored.
- A mutation that edits `Package.swift` or `Package.resolved` runs the built test bundle with `xcrun xctest`, because `swift test` re-resolves packages and deletes a stale `Package.resolved`.
