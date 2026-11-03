#!/usr/bin/env bash
# Generates the app project, builds Fortkeeps Scroll with no warnings, and runs
# its keyboard and accessibility-audit UI tests (design log 004, Round 3).
# The UI tests take the screen for about a minute and need it unlocked.
set -euo pipefail

xcodegen generate --quiet

if ioreg -n Root -d1 -a | plutil -extract IOConsoleUsers xml1 -o - - | grep -A1 CGSSessionScreenIsLocked | grep -q true; then
    echo "error: the screen is locked; the UI tests need it unlocked" >&2
    exit 1
fi

log=$(mktemp)
if ! xcodebuild test -project FortkeepsScroll.xcodeproj -scheme "Fortkeeps Scroll" \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath .build-xcode/app >"${log}" 2>&1; then
    grep -E 'error:|warning:' "${log}" >&2 || tail -40 "${log}" >&2
    exit 1
fi
# XCTest reports priority inversions in its own threads as `[Internal]` warnings.
if grep -E '^[^ ].*warning:' "${log}" | grep -v -e appintentsmetadataprocessor -e '\] : \[Internal\] ' >&2; then
    echo "error: the app build has warnings" >&2
    exit 1
fi
echo "ok: Fortkeeps Scroll builds and its UI tests pass"
