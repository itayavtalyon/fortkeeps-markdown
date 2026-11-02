#!/usr/bin/env python3
"""Fail unless the iOS app opens the same document types as the Mac app (plan 02, stage 2d).

Compares `CFBundleDocumentTypes` (without the Mac-only `NSDocumentClass`) and
`UTImportedTypeDeclarations` of the two Info.plist files.
"""

import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEYS = ("CFBundleDocumentTypes", "UTImportedTypeDeclarations")


def types(path: Path) -> dict:
    """Return the document-type keys of one Info.plist, without the Mac document class."""
    info = plistlib.loads(path.read_bytes())
    found = {key: info.get(key) for key in KEYS}
    for entry in found["CFBundleDocumentTypes"] or []:
        entry.pop("NSDocumentClass", None)
    return found


def main() -> int:
    """Print the first difference and return 1, or return 0."""
    mac = types(ROOT / "Apps" / "Mac" / "Info.plist")
    ios = types(ROOT / "Apps" / "iOS" / "Info.plist")
    for key in KEYS:
        if not mac[key] or mac[key] != ios[key]:
            sys.stderr.write(f"error: {key} differs between the Mac and iOS apps\n")
            return 1
    sys.stdout.write("ok: the iOS document types match the Mac types\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
