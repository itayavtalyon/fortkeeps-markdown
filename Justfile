# The gate: `just check` runs locally before a push and in CI.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Pin the Xcode toolchain and its macOS SDK; the Command Line Tools SDK can
# differ from the compiler Xcode ships.
export DEVELOPER_DIR := `xcode-select -p`
export SDKROOT := `xcrun --sdk macosx --show-sdk-path`

# SwiftPM build outside iCloud Drive; File Provider xattrs on `.build/` break codesign.
spm_build := env_var_or_default("FORTKEEPS_MARKDOWN_BUILD", env_var("HOME") / "Library/Caches/fortkeeps-markdown-spm")

default: check

check: build test coverage-check core-modules ios-build lint format-check

# iCloud Drive conflict copies ("Foo 2.swift") compile as a second type.
icloud-clean:
    find Sources Tests -name '* [0-9].swift' -delete
    find Sources Tests -name '* [0-9][0-9].swift' -delete

build: icloud-clean
    swift build --build-path '{{spm_build}}'

test: icloud-clean
    swift test --enable-code-coverage --build-path '{{spm_build}}'

# Reads the coverage of the last `just test`.
coverage-check:
    scripts/check-coverage.py "$(swift test --show-codecov-path --build-path '{{spm_build}}')"

core-modules:
    scripts/check-core-modules.sh

ios-build:
    #!/usr/bin/env bash
    set -euo pipefail
    log=$(mktemp)
    if ! xcodebuild -quiet build -scheme FortkeepsMarkdown-Package -destination 'generic/platform=iOS' \
        -derivedDataPath .build-xcode >"${log}" 2>&1; then
        cat "${log}" >&2
        exit 1
    fi
    echo "ok: package builds for iOS"

# The 8 ms restyle budget (design log 001 › Editor): release build, Apple silicon.
timing:
    FORTKEEPS_TIMING=1 swift test -c release --build-path '{{spm_build}}-release' --filter StylerTimingTests 2>&1 | grep -E 'timing:|passed|failed|error'

lint:
    swiftlint lint --strict --quiet
    shellcheck scripts/*.sh
    ruff check scripts

format:
    swiftformat .
    ruff format scripts

format-check:
    swiftformat --lint .
    ruff format --check scripts
