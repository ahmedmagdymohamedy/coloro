# Coloro 🎨

A juicy pixel-art puzzle game built with Flutter. Dock paint flasks under
the picture and they drink it away row by row from the bottom edge — pick
the right colors, finish the image, unlock the next one.

## Run the app

```sh
flutter pub get        # first time only
flutter run            # runs on the connected device / asks if several
```

Or target a specific platform:

```sh
flutter run -d macos     # desktop window (phone-width play area)
flutter run -d chrome    # web browser
flutter run -d <id>      # phone/emulator — find ids with: flutter devices
```

Release build for stores: `flutter build apk` (Android) or
`flutter build ipa` (iOS, needs Xcode signing).

## How the game works

1. Every level is just an **image** in `assets/levels/` (any PNG/JPG).
2. At load time the image is decoded in a background isolate,
   **center-cropped to a full square**, scaled to the level's grid, and
   **re-rendered with a limited color palette** (quantization). Every cell
   is content — transparency is composited over a purple backdrop.
3. Each palette color's pixel total is split into **paint bottles** (10/20/30/40).
4. The player taps bottles in the tray → they dock into one of the machine's
   **4 slots** and **drink pixels from the BOTTOM EDGE only**: for
   each column, just the lowest remaining pixel is reachable. Erasing runs
   **in sequence** — one pixel at a time, always from the lowest remaining
   row, swept left → right, then the row above it — so the picture drains
   row by row from the bottom up. The flask's liquid rises until it pops,
   full. The picture starts fully bright; collected cells dim to sockets.
5. **Blocking:** a color sitting above other colors in every column cannot
   be reached yet. A bottle whose color shows nowhere on the bottom edge
   **starves** (red “!”) until other bottles drain a path down to it.
6. **Lose condition:** all 4 slots starving at once = *Machine Jammed* →
   retry. Read the bottom edge (and the columns above it) before docking.
7. **Hold to fast-forward:** press and hold any empty space for 2× speed.
8. Finishing a level shows the **completed picture** as the reward and
   unlocks the next one. No combos, no stars — the picture is the prize.

## Difficulty tuning

Difficulty lives in one object: `Level` (`lib/domain/models/level.dart`) with
two dials per level:

| Dial        | Meaning                                              |
|-------------|------------------------------------------------------|
| `gridSize`  | How many pixels the image is split into (longest side) |
| `maxColors` | How many colors the image is re-rendered with        |

Tune them in **`assets/levels/levels.json`**:

```json
{
  "levels": {
    "1.jpg": { "name": "Moon", "gridSize": 26, "maxColors": 5 }
  }
}
```

Any image not listed there gets an automatic ramp (bigger + more colorful as
level numbers grow) — so **adding a level is literally dropping an image into
`assets/levels/`**. Files are ordered by their numeric filename.

## Project structure

```
lib/
  app/          MaterialApp shell + page transitions
  core/
    audio/      SFX enum + low-latency round-robin player pool
    haptics/    exception-safe haptic wrappers
    theme/      candy palette + Fredoka typography
  data/         level catalog (asset scan + levels.json), image→grid
                processor (isolate), bottle factory, progress store
  domain/       plain models: Level, PixelGrid, PaintBottle, LevelResult
  game/
    game_controller.dart   pure simulation (unit-tested, no Flutter UI)
    game_events.dart       one-shot events the UI turns into juice
    vfx/        particle pool, flying pixels/bottles, screen shake, painter
    widgets/    bead atlas (drawAtlas batching), pixel canvas, slots, tray, HUD
  screens/
    menu/       animated menu, bouncing title, level preview card
    game/       game screen orchestrator + level-complete overlay
  shared/       bouncy CTA button
tool/
  gen_sfx.dart     synthesizes every .wav in assets/audio from scratch
  gen_levels.dart  generates the built-in pixel-art level images
```

## Levels (300-level campaign)

240 normal + 60 hard levels, interleaved 4:1 (every 5th level is hard),
both ramped easiest → hardest. Three dials ramp together:

| Dial | What it does | Normal | Hard |
|---|---|---|---|
| Grid | picture size | 15 → 39 | 20 → 40 |
| Colors | palette size | 5 → 9 | 7 → 10 |
| Churn | vertical interleaving — how often the color changes up a column | 0.30 → 0.58 | 0.45 → 0.70 |
| Shuffle | how far a bottle sits from where it is needed in the tray | 2 → 9 | 4 → 12 |

The tray is **shuffled**, not sorted: the bottle you need is rarely at a
front, so you must park bottles and keep a slot breathing. A shuffle can
make a level unwinnable, so every level ships with a `(shuffleWindow,
dealSeed)` pair proven beatable by a slot-constrained solver over the real
game (`BottleFactory.isDealSolvable`), and `levels.json` records every
number that defines the level.

Rules and structures in **docs/LEVEL_DESIGN_RULES.md**; solvability
enforced by `test/stall_diagnostic_test.dart`. In Claude Code, use the
**/level-builder** skill to add or rebalance levels.

## Regenerating assets

```sh
dart run tool/gen_sfx.dart     # sound effects
dart run tool/gen_levels.dart  # the 300-level campaign + levels.json
```

## Firebase & ads

**Firebase** (project `coloro-e4a4b`, bundle `com.megz.coloro`) is
initialized in `main.dart` and is *best effort* — if it fails the game
still runs, just without analytics. Events logged by
`lib/core/analytics/analytics_service.dart`:

| Event | When | Parameters |
|---|---|---|
| `game_started` | a level opens | `level`, `hard` |
| `game_won` | picture finished | `level`, `seconds` |
| `finish_level_5`, `_10`, `_15`… | every 5th level completed | `level` |
| `finish_level` | aggregate twin of the above | `level` |
| `game_lost_{n}` | machine jammed on level n | `level`, `progress` |
| `game_lost` | aggregate twin of the above | `level`, `progress` |
| `extra_slot_earned` | rewarded ad watched | `level` |
| `ad_shown` | any full-screen ad shown | `ad_format`, `level` |

The per-level names make funnels readable; the aggregate twins keep the
console usable once 300 levels are live (Firebase caps an app at 500
distinct event names — the campaign uses ~365).

**AdMob** (`lib/core/ads/`) — unit IDs live in `ad_ids.dart`, the lifecycle
in `ad_service.dart`:

- **Banner** — always pinned to the bottom via the `MaterialApp.builder`,
  so it shows on every screen. It reserves no space until an ad loads.
- **Interstitial** — between levels, from **level 3** onward, shown when
  the player taps NEXT LEVEL.
- **Rewarded** — offered on a jam: watch an ad to get a **5th slot** and
  resume from where the machine stopped (once per attempt). More slots can
  only make a level easier, so solvability proofs still hold.

Debug builds automatically use Google's **test** units; release builds use
the live ones. Ads are a no-op on desktop/web, so `flutter run -d macos`
keeps working.

## Tests

```sh
flutter test
```

Covers the quantization pipeline, bottle generation (exact sums + witness
schedules — levels are provably completable), the bottom-drain rules
(bottom-edge only, strict bottom-up row sequence, starvation/jam), and a
full simulated playthrough plus an end-to-end render test.
