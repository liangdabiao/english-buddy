#!/usr/bin/env python3
"""Read the cmap of a TrueType font and report which codepoints it covers.

Pure stdlib (no fontTools needed). Used to check that assets/fonts/ui.ttf
contains every character the UI actually draws.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path


def read_cmap(path: Path) -> set[int]:
    data = path.read_bytes()
    num_tables = struct.unpack(">H", data[4:6])[0]
    tables = {}
    for i in range(num_tables):
        off = 12 + i * 16
        tag = data[off:off + 4].decode("latin-1")
        toff, tlen = struct.unpack(">II", data[off + 8:off + 16])
        tables[tag] = (toff, tlen)

    if "cmap" not in tables:
        return set()
    coff = tables["cmap"][0]
    n_sub = struct.unpack(">H", data[coff + 2:coff + 4])[0]

    codepoints: set[int] = set()
    for i in range(n_sub):
        rec_off = coff + 4 + i * 8
        platform, encoding, sub_off = struct.unpack(">HHI", data[rec_off:rec_off + 8])
        sub = coff + sub_off
        fmt = struct.unpack(">H", data[sub:sub + 2])[0]
        if fmt == 4:
            seg_x2 = struct.unpack(">H", data[sub + 6:sub + 8])[0]
            seg = seg_x2 // 2
            ends = struct.unpack(">%dH" % seg, data[sub + 14:sub + 14 + seg_x2])
            starts_off = sub + 16 + seg_x2
            starts = struct.unpack(">%dH" % seg, data[starts_off:starts_off + seg_x2])
            deltas_off = starts_off + seg_x2
            deltas = struct.unpack(">%dh" % seg, data[deltas_off:deltas_off + seg_x2])
            range_off_pos = deltas_off + seg_x2
            range_offs = struct.unpack(">%dH" % seg, data[range_off_pos:range_off_pos + seg_x2])
            for s in range(seg):
                for c in range(starts[s], min(ends[s], 0xFFFF) + 1):
                    if c == 0xFFFF:
                        continue
                    if range_offs[s] == 0:
                        g = (c + deltas[s]) & 0xFFFF
                    else:
                        gidx_off = range_off_pos + s * 2 + range_offs[s] + (c - starts[s]) * 2
                        if gidx_off + 2 > len(data):
                            continue
                        g = struct.unpack(">H", data[gidx_off:gidx_off + 2])[0]
                        if g:
                            g = (g + deltas[s]) & 0xFFFF
                    if g:
                        codepoints.add(c)
        elif fmt == 12:
            n_groups = struct.unpack(">I", data[sub + 12:sub + 16])[0]
            for g in range(n_groups):
                goff = sub + 16 + g * 12
                start, end, _gid = struct.unpack(">III", data[goff:goff + 12])
                for c in range(start, min(end, start + 0x10000) + 1):
                    codepoints.add(c)
    return codepoints


if __name__ == "__main__":
    font = Path(sys.argv[1])
    cps = read_cmap(font)
    print("font:", font, "codepoints:", len(cps))
    missing = []
    for arg in sys.argv[2:]:
        for ch in arg:
            if ord(ch) not in cps and ch not in ("\n", "\t"):
                missing.append((ch, hex(ord(ch))))
    if missing:
        print("MISSING GLYPHS:")
        for ch, code in missing:
            print("  ", repr(ch), code)
    else:
        print("ALL REQUESTED GLYPHS PRESENT")
