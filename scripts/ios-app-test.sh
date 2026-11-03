#!/usr/bin/env bash
# Builds the iOS app with no warnings and runs its UI tests on an iPhone and an
# iPad simulator (plan 02, stage 2d): New, the back button, the iPad tab, and
# the accessibility audit. FORTKEEPS_IOS_SIMULATOR and FORTKEEPS_IPAD_SIMULATOR
# name the devices.
set -euo pipefail

scripts/check-document-types.py
xcodegen generate --quiet

iphone="${FORTKEEPS_IOS_SIMULATOR:-iPhone 18 Pro}"
ipad="${FORTKEEPS_IPAD_SIMULATOR:-iPad Air 11-inch (M4)}"
for device in "${iphone}" "${ipad}"; do
    log=$(mktemp)
    if ! xcodebuild test -project FortkeepsScroll.xcodeproj -scheme "Fortkeeps Scroll iOS" \
        -destination "platform=iOS Simulator,name=${device}" -derivedDataPath .build-xcode/app >"${log}" 2>&1; then
        grep -E 'error:|warning:' "${log}" >&2 || tail -40 "${log}" >&2
        exit 1
    fi
    if grep -E '^[^ ].*warning:' "${log}" | grep -v -e appintentsmetadataprocessor -e '\] : \[Internal\] ' >&2; then
        echo "error: the iOS app build has warnings" >&2
        exit 1
    fi
    echo "ok: the iOS app builds and its UI tests pass on ${device}"
done
