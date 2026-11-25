#!/usr/bin/env python3
"""Audit every character the UI draws against the subsetted font.

Scans scripts/*.gd string literals and data/content.json, then reports any
character that assets/fonts/ui.ttf does not contain.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_font_glyphs import read_cmap  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "assets" / "fonts" / "ui.ttf"
CONTENT = ROOT / "data" / "content.json"


def script_strings() -> str:
    out = []
    for path in sorted((ROOT / "scripts").glob("*.gd")):
        text = path.read_text(encoding="utf-8")
        out.extend(re.findall(r'"([^"\n]*)"', text))
        out.extend(re.findall(r"'([^'\n]*)'", text))
    return "\n".join(out)


def content_strings() -> str:
    data = json.loads(CONTENT.read_text(encoding="utf-8"))

    def walk(value):
        if isinstance(value, str):
            yield value
        elif isinstance(value, list):
            for item in value:
                yield from walk(item)
        elif isinstance(value, dict):
            for key, item in value.items():
                yield key
                yield from walk(item)

    return "\n".join(walk(data))


def main() -> None:
    covered = read_cmap(FONT)
    print(f"font: {FONT.name}  codepoints: {len(covered)}")

    for label, blob in (("scripts", script_strings()), ("content", content_strings())):
        missing = {}
        for ch in blob:
            if ch in "\n\r\t":
                continue
            if ord(ch) not in covered:
                missing[ch] = missing.get(ch, 0) + 1
        print(f"\n--- {label}: {len(missing)} distinct missing glyph(s) ---")
        for ch, count in sorted(missing.items(), key=lambda kv: -kv[1]):
            print(f"   {ch!r}  U+{ord(ch):04X}  x{count}")


if __name__ == "__main__":
    main()
