#!/usr/bin/env python3
"""Fail unless every iOS-only ScrollSupport file has 100% line and function coverage.

Usage: check-ios-coverage.py <xcresult of the ScrollSupportTests run on a simulator>

The files are `Sources/ScrollSupport/*+UIKit.swift`; they compile empty on macOS, so
check-coverage.py leaves them to this check. An uncovered line passes only when it
ends with `// coverage:ignore - <reason>`. A file missing from the report fails.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = "ScrollSupportTests"
IGNORE = re.compile(r"// coverage:ignore - \S")
LINE = re.compile(r"^\s*(\d+): (\d+)")


def xccov(*arguments: str) -> str:
    """Return the output of one `xcrun xccov view` call."""
    shown = subprocess.run(  # noqa: S603 - fixed argv built from build paths
        ["xcrun", "xccov", "view", *arguments],  # noqa: S607 - xcrun is the toolchain entry point
        capture_output=True,
        text=True,
        check=True,
    )
    return shown.stdout


def check(result: Path) -> list[str]:
    """Return one error message per gate violation."""
    report = json.loads(xccov("--report", "--json", str(result)))
    files = {
        Path(entry["path"]).resolve(): entry
        for target in report["targets"]
        if target["name"].startswith(BUNDLE)
        for entry in target["files"]
    }
    sources = sorted((ROOT / "Sources" / "ScrollSupport").glob("*+UIKit.swift"))
    errors = [] if sources else ["no iOS files under Sources/ScrollSupport"]
    for source in sources:
        name = source.relative_to(ROOT)
        entry = files.get(source.resolve())
        if entry is None:
            errors.append(f"{name}: not in the coverage report")
            continue
        errors += [f"{name}: uncovered function {f['name']}" for f in entry["functions"] if f["executionCount"] == 0]
        text = source.read_text().splitlines()
        counts = xccov("--archive", "--file", str(source.resolve()), str(result)).splitlines()
        for match in filter(None, map(LINE.match, counts)):
            number, count = int(match.group(1)), int(match.group(2))
            if count == 0 and not IGNORE.search(text[number - 1]):
                errors.append(f"{name}:{number}: {text[number - 1].strip()}")
    return errors


def main() -> int:
    """Run the gate and print the result."""
    if len(sys.argv) != 2:  # noqa: PLR2004 - one argument
        sys.stderr.write("usage: check-ios-coverage.py <xcresult>\n")
        return 2
    try:
        errors = check(Path(sys.argv[1]))
    except (subprocess.CalledProcessError, ValueError, KeyError) as error:
        errors = [f"cannot read coverage of {sys.argv[1]}: {error!r}"]
    for error in errors:
        sys.stderr.write(f"error: {error}\n")
    sys.stdout.write("iOS coverage gate: FAIL\n" if errors else "iOS coverage gate: OK (ScrollSupport iOS 100%)\n")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
