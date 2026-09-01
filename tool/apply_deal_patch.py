#!/usr/bin/env python3
"""Apply tool/deal_patch.json to assets/levels/levels.json.

Patches shuffleWindow, dealSeed, maxColors and colors — whichever the patch
carries for a given level.

Line-surgical on purpose. levels.json does NOT round-trip through
json.dumps (checked), so rewriting the whole file would produce a huge
spurious diff and bury the handful of numbers that actually changed. This
edits only the `shuffleWindow` and `dealSeed` lines inside the blocks named
by the patch, and leaves every other byte alone.

    python3 tool/apply_deal_patch.py            # dry run, shows the diff
    python3 tool/apply_deal_patch.py --write
"""
import json
import re
import sys
from pathlib import Path

LEVELS = Path("assets/levels/levels.json")
PATCH = Path(sys.argv[2]) if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else Path("tool/deal_patch.json")


def main() -> int:
    write = "--write" in sys.argv
    if not PATCH.exists():
        print(f"no patch at {PATCH} — nothing to do")
        return 0

    patch = json.loads(PATCH.read_text())
    if not patch:
        print("patch is empty — nothing to do")
        return 0

    lines = LEVELS.read_text().split("\n")
    key_re = re.compile(r'^\s*"(\d+\.png)"\s*:\s*\{')
    field_re = re.compile(
        r'^(\s*)"(shuffleWindow|dealSeed|maxColors|colors|gridSize|cells|bottles)"(\s*:\s*)(-?\d+)(,?)\s*$'
    )

    current = None
    changes = []
    for i, line in enumerate(lines):
        m = key_re.match(line)
        if m:
            current = m.group(1)
            continue
        if current is None or current not in patch:
            continue
        f = field_re.match(line)
        if not f:
            continue
        indent, field, sep, old, comma = f.groups()
        if field not in patch[current]:
            continue
        new = patch[current][field]
        if int(old) != new:
            lines[i] = f'{indent}"{field}"{sep}{new}{comma}'
            changes.append(f"  {current:>9}  {field:<13} {old} -> {new}")

    seen = {c.split()[0] for c in changes}
    missing = [k for k in patch if k not in seen]

    print(f"levels in patch : {len(patch)}")
    print(f"lines changed   : {len(changes)}")
    for c in changes:
        print(c)
    if missing:
        print(f"\n!! no change applied for: {', '.join(sorted(missing))}")
        print("   (already at the patched value, or the key was not found)")

    if not write:
        print("\ndry run — pass --write to apply")
        return 0

    LEVELS.write_text("\n".join(lines))
    # Re-parse so a malformed edit fails here rather than in the game.
    json.loads(LEVELS.read_text())
    print(f"\nwrote {LEVELS} (re-parsed OK)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
