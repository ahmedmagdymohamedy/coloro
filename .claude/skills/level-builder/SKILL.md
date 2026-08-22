---
name: level-builder
description: Build or modify Coloro level packs — procedural full-square pixel levels with difficulty ramps, shuffled trays, and a solver-backed solvability gate. Use whenever the user asks to add, regenerate, rebalance, or verify game levels.
---

# Coloro Level Builder

Read `docs/LEVEL_DESIGN_RULES.md` FIRST — it is the authoritative rule set.
This skill is the operating procedure.

## The mechanic (everything follows from this)

Docked bottles drink **only each column's lowest remaining pixel**, one at
a time, deepest row first. A bottle holds its slot until it fills. A bottle
whose color is nowhere on the bottom edge **starves**; all 4 slots starving
= level lost.

## Non-negotiable rules

1. Full-square PNGs `<n>.png` in `assets/levels/`, plus a `levels.json`
   entry recording name, gridSize, maxColors, hard, colors, cells, churn,
   shuffleWindow, dealSeed, bottles.
2. **5–10 colors**, each ≥56 apart in weighted RGB (below ~52 the runtime
   quantizer merges them and the palette silently collapses).
3. **Column coverage ≥ 55%** for every color — a color living in a few
   columns starves its bottle and hostages a slot. This is the #1 cause of
   unsolvable levels.
4. **Bottle capacity ≤ ~⅓ of that color's total** — big bottles for thinly
   spread colors are slot hostages. Small bottles keep slots turning over.
5. Difficulty = **vertical churn** (color changes up a column) + **tray
   shuffle window**, both ramped. NOT just "more colors".
6. 4 normal : 1 hard cadence; grids 15–40.
7. Never hand-edit generated PNGs or levels.json — change the generator.

## Procedure

1. Modify `tool/gen_levels.dart` for the request.
2. `dart run tool/gen_levels.dart` (takes several minutes — it runs
   thousands of solver checks and refuses to ship an unprovable level).
3. `flutter test test/stall_diagnostic_test.dart` — re-proves every sampled
   shipped deal and asserts the ramps. **Never weaken or delete the gate.**
4. `flutter test` — whole suite green.
5. Spot-check ~10 thumbnails across the range (`sips --resampleHeightWidthMax`).
6. Report: what changed, the ramp table (colors/churn/shuffle early vs
   late), gate results, sample images.

## Debugging an unsolvable level

`tool/debug_deal.dart <n>` prints the palette, cell counts, bottle count
and solvability at several shuffle windows for that level's scenes. If
window=1 is already unsolvable the fault is the ART or the SUPPLY (coverage
/ bottle sizing), not the shuffle.
