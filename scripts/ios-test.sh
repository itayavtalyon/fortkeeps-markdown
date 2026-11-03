#!/usr/bin/env bash
# Runs the MarkdownViews and ScrollSupport tests on an iOS simulator: the first
# available iPhone, or the one named in FORTKEEPS_IOS_SIMULATOR. Then gates the
# coverage of ScrollSupport's iOS-only files.
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
result=.build-xcode/ios-test.xcresult
rm -rf "${result}"
if ! xcodebuild test -workspace . -scheme FortkeepsMarkdown-Package -destination "platform=iOS Simulator,name=${name}" \
    -derivedDataPath .build-xcode -only-testing:MarkdownViewsTests -only-testing:ScrollSupportTests \
    -enableCodeCoverage YES -resultBundlePath "${result}" >"${log}" 2>&1; then
    grep -E '^✘|Fatal error|error:' "${log}" >&2 || tail -40 "${log}" >&2
    exit 1
fi
echo "ok: MarkdownViews and ScrollSupport tests pass on ${name}"
scripts/check-ios-coverage.py "${result}"
