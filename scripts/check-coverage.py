#!/usr/bin/env python3
"""Fail unless every Swift file in Sources/MarkdownCore has 100% line and function coverage.

Usage: check-coverage.py <codecov json from `swift test --show-codecov-path`>

An uncovered line passes only when it ends with `// coverage:ignore - <reason>`.
A MarkdownCore file that is missing from the report fails, so a new file cannot skip the gate.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GATED = ROOT / "Sources" / "MarkdownCore"
IGNORE = re.compile(r"// coverage:ignore - \S")
UNCOVERED = re.compile(r"^\s*(\d+)\|\s*0\|(.*)$")


def uncovered_lines(products: Path, source: Path) -> list[str]:
    """Return the `llvm-cov show` lines with a zero count for one source file."""
    binary = products / "MarkdownCoreTests.xctest" / "Contents" / "MacOS" / "MarkdownCoreTests"
    shown = subprocess.run(  # noqa: S603 - fixed argv built from build paths
        [  # noqa: S607 - xcrun is the toolchain entry point
            "xcrun",
            "llvm-cov",
            "show",
            str(binary),
            f"-instr-profile={products / 'codecov' / 'default.profdata'}",
            str(source),
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return [f"{m.group(1)}: {m.group(2).strip()}" for line in shown.splitlines() if (m := UNCOVERED.match(line))]


def check(report_path: Path) -> list[str]:
    """Return one error message per gate violation."""
    try:
        files = json.loads(report_path.read_text())["data"][0]["files"]
        summaries = {Path(f["filename"]).resolve(): f["summary"] for f in files}
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        return [f"cannot read coverage report {report_path}: {error!r}"]
    products = report_path.parent.parent
    gated = sorted(GATED.rglob("*.swift"))
    if not gated:
        return [f"no Swift files under {GATED}"]

    errors = []
    for source in gated:
        name = source.relative_to(ROOT)
        summary = summaries.get(source.resolve())
        if summary is None:
            errors.append(f"{name}: not in the coverage report")
            continue
        functions, lines = summary["functions"], summary["lines"]
        if functions["covered"] < functions["count"]:
            errors.append(f"{name}: {functions['count'] - functions['covered']} uncovered function(s)")
        if lines["covered"] == lines["count"]:
            continue
        found = uncovered_lines(products, source)
        if not found:
            missed = lines["count"] - lines["covered"]
            errors.append(f"{name}: report says {missed} uncovered, llvm-cov show found none")
        errors += [f"{name}:{line}" for line in found if not IGNORE.search(line)]
    return errors


def main() -> int:
    """Run the gate and print the result."""
    if len(sys.argv) != 2:  # noqa: PLR2004 - one argument
        sys.stderr.write("usage: check-coverage.py <codecov json>\n")
        return 2
    errors = check(Path(sys.argv[1]))
    for error in errors:
        sys.stderr.write(f"error: {error}\n")
    sys.stdout.write("coverage gate: FAIL\n" if errors else "coverage gate: OK (MarkdownCore 100%)\n")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
