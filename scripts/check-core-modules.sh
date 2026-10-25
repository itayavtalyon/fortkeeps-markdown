#!/usr/bin/env bash
# Fails when compiling MarkdownCore loads AppKit, UIKit, or SwiftUI on macOS or
# iOS. The compiler's loaded-module trace lists every module the build read,
# so an indirect import (`import Cocoa`, `import WebKit`) fails too. The text
# scan in SourceGuardTests covers direct imports on platforms not built here.
set -euo pipefail

cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

check_trace() {
  local platform=$1 trace="${work}/$1.json" hits
  if [[ ! -s "${trace}" ]]; then
    echo "error: no module trace for ${platform}" >&2
    exit 1
  fi
  hits=$(grep -o '"name":"\(AppKit\|UIKit\|SwiftUI\)"' "${trace}" | sort -u || true)
  if [[ -n "${hits}" ]]; then
    echo "error: MarkdownCore loads a UI framework on ${platform}: ${hits}" >&2
    exit 1
  fi
  echo "ok: MarkdownCore loads no UI framework on ${platform}"
}

trace_flags=(-emit-loaded-module-trace -emit-loaded-module-trace-path "${work}/macos.json")
swift build --target MarkdownCore --build-path "${work}/spm" "${trace_flags[@]/#/-Xswiftc=}" >/dev/null
check_trace macos

# xcodebuild prints simulator-service noise even for a device build; show
# its log only when the build fails.
if ! xcodebuild -quiet build -scheme MarkdownCore -destination 'generic/platform=iOS' \
  -derivedDataPath "${work}/dd" \
  "OTHER_SWIFT_FLAGS=\$(inherited) -emit-loaded-module-trace -emit-loaded-module-trace-path ${work}/ios.json" \
  >"${work}/ios.log" 2>&1; then
  cat "${work}/ios.log" >&2
  exit 1
fi
check_trace ios
