#!/usr/bin/env bash
# Runs the MarkdownViews tests on an iOS simulator: the first available
# iPhone, or the one named in FORTKEEPS_IOS_SIMULATOR.
set -euo pipefail

name="${FORTKEEPS_IOS_SIMULATOR:-}"
if [[ -z "${name}" ]]; then
    name=$(xcrun simctl list devices available | sed -nE 's/^ +(iPhone[^(]*[^ (]) \(.*/\1/p' | head -1)
fi
if [[ -z "${name}" ]]; then
    echo "error: no iPhone simulator; install one with: xcodebuild -downloadPlatform iOS" >&2
    exit 1
fi

log=$(mktemp)
if ! xcodebuild test -scheme FortkeepsMarkdown-Package -destination "platform=iOS Simulator,name=${name}" \
    -derivedDataPath .build-xcode -only-testing:MarkdownViewsTests >"${log}" 2>&1; then
    grep -E '^✘|Fatal error|error:' "${log}" >&2 || tail -40 "${log}" >&2
    exit 1
fi
echo "ok: MarkdownViews tests pass on ${name}"
