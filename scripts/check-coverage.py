#!/usr/bin/env python3
"""Fail unless every Swift file in the gated modules has 100% line and function coverage.

Usage: check-coverage.py <codecov json from `swift test --show-codecov-path`>

An uncovered line passes only when it ends with `// coverage:ignore - <reason>`.
The gated modules are MarkdownCore and FortkeepsCards. A gated file that is missing
from the report fails, so a new file cannot skip the gate.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Each gated source folder, with the test bundle whose run covers it.
GATED = {"MarkdownCore": "MarkdownCoreTests", "FortkeepsCards": "FortkeepsCardsTests"}
IGNORE = re.compile(r"// coverage:ignore - \S")
UNCOVERED = re.compile(r"^\s*(\d+)\|\s*0\|(.*)$")


class CoverageError(Exception):
    """`llvm-cov show` failed. The message is the gate's line, not a traceback."""


def uncovered_lines(products: Path, bundle: str, source: Path) -> list[str]:
    """Return the `llvm-cov show` lines with a zero count for one source file."""
    binary = products / f"{bundle}.xctest" / "Contents" / "MacOS" / bundle
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
        check=False,
    )
    if shown.returncode != 0:
        detail = (shown.stderr or shown.stdout).strip() or f"exit {shown.returncode}"
        raise CoverageError(detail)
    return [f"{m.group(1)}: {m.group(2).strip()}" for line in shown.stdout.splitlines() if (m := UNCOVERED.match(line))]


def check(report_path: Path) -> list[str]:
    """Return one error message per gate violation."""
    try:
        files = json.loads(report_path.read_text())["data"][0]["files"]
        summaries = {Path(f["filename"]).resolve(): f["summary"] for f in files}
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        return [f"cannot read coverage report {report_path}: {error!r}"]
    products = report_path.parent.parent
    errors = []
    for module, bundle in GATED.items():
        folder = ROOT / "Sources" / module
        sources = sorted(folder.rglob("*.swift"))
        if not sources:
            errors.append(f"no Swift files under {folder}")
        errors += check_files(sources, summaries, products, bundle)
    return errors


def check_files(sources: list[Path], summaries: dict, products: Path, bundle: str) -> list[str]:
    """Return the gate violations of one module's files."""
    errors = []
    for source in sources:
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
        try:
            found = uncovered_lines(products, bundle, source)
        except CoverageError as error:
            errors.append(f"{name}: llvm-cov show failed: {error}")
            continue
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
    passed = "coverage gate: OK (MarkdownCore and FortkeepsCards 100%)\n"
    sys.stdout.write("coverage gate: FAIL\n" if errors else passed)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
