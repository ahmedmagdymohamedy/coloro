#!/usr/bin/env python3
"""Merge deal patches from several reproof passes into one.

The reproof tool writes a fresh tool/deal_patch.json each run, so a
follow-up pass over stragglers (`--only=...`) would otherwise throw away the
first pass's repairs. Later files win on conflict.

    python3 tool/merge_patches.py a.json b.json > tool/deal_patch.json
"""
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    merged: dict = {}
    for arg in sys.argv[1:]:
        data = json.loads(Path(arg).read_text())
        merged.update(data)
        print(f"{arg}: {len(data)} levels", file=sys.stderr)
    print(f"merged: {len(merged)} levels", file=sys.stderr)
    print(json.dumps(merged, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
