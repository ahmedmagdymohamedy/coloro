# Session record — fixed palette, ad fixes, playable v2

**When:** 28 Aug 2026, overnight, autonomous.
**Previous session:** `chat_history/2026-08-27-release-session.md`.
Plan lives in `marketing/MARKETING_PLAN.md`; engineering handoff in `HANDOFF.md`.

---

## 1. Headline: Coloro is LIVE on Google Play

Approved and published **27 Aug**. Production shows **1.0.6 (code 6)** active
in **177 countries**, 0 installs at time of writing. The `(unreviewed)`
placeholder name is gone. This opens the Google Ads gate (campaigns can only
target a live app).

Ahmed also committed and pushed the previous session's work — HEAD is
`9812c96 "V 6"`, the tree was clean, and the broken drain-order experiment is
gone from `origin/main`. **The git risk from last session is resolved.**
(The stray "6" message was about this commit.)

---

## 2. What was asked this session

1. Write a 6-month marketing plan as a checklist Claude executes → `marketing/MARKETING_PLAN.md`
2. Fixed colour palette — "the game sees two kinds of green"
3. Banner too big, and everything jumps when it appears
4. Playable must match the game, have sound, and a hand pointer
5. Ads escapable by pressing Home after losing
6. Create the Facebook app; create a Google Ads campaign (permission given)
7. Deploy both; submit **Android** for review; **iOS TestFlight only** —
   Apple already has a version in review, don't submit a new one
8. Target changed: **$10,000 net in 6 months**, budget **5,000 EGP ≈ $100/month**

---

## 3. The palette work (the big one)

### The problem
`quantizeImage` derived a palette per level from the source art by frequency.
Two colours only had to be **52** apart (`_mergeDistance`) to survive as
separate entries, so levels shipped with near-identical greens/purples.
Level 44 was the reported example.

### The design, and why it is what it is
New `lib/data/game_palette.dart` — **12 fixed colours**, every level maps onto
them. Two constraints, both locked by `test/game_palette_test.dart`:

1. **One colour per 30° hue slot.** This is the constraint that actually
   answers the complaint. A distance metric happily calls a dark cyan and a
   light cyan "different"; a player reads them as one colour lighter.
2. **Maximum minimum separation** under the quantizer's own metric, searched
   over lightness/saturation within each slot → **closest pair 62** (vs the 52
   merge threshold).

Getting there took four attempts, recorded because the failures are
instructive:
- Hand-picked candy colours → min **20.7** after the DisplayPalette lift
- Raw hand-picked, no lift → min **34.7**
- Free optimiser, no hue constraint → min 62 but it picked *two cyans and two
  magentas* (same hue, different lightness) — numerically fine, visually the
  exact bug being fixed
- Hue-slot constrained optimiser → **62.1**, all 12 hues distinct ✅

Every hand-tune afterwards made it worse (43–46), so the optimiser's output
ships unmodified.

### DisplayPalette is now a pass-through
Its lightness remap existed to rescue dark art-derived palettes. Applied to a
fixed palette it **compresses the closest pair from 62 to 21** — it would
undo the entire fix. It stays as the single entry point every renderer goes
through (that is what keeps flasks and pixels the same colour) but `of()`
returns the colour unchanged.

### Impact on the campaign
`tool/audit_palette.dart` (new, runs in seconds, no solving):
- 121/300 levels keep the same colour count; 179 lose some (that's the point)
- **only 12 levels drop to 4 colours**, all early ones; nothing goes lower
- distribution after snapping: 4→12, 5→60, 6→84, 7→79, 8→53, 9→12

Visual check via `tool/render_level.dart` (new): level 44 and level 250 both
read as clearly separated colours.

### Final result

**303/303 tests pass — all 300 levels re-proved solvable** under the fixed
palette. Getting there took four knobs, applied cheapest-first:

| Outcome | Levels |
|---|---|
| Already solvable, untouched | 242 |
| Repaired (new dealSeed / colours / gridSize) | 58 |
| Unrepairable | **0** |

Of the repairs, only **1** lost difficulty (a weaker shuffle window); the rest
kept their shuffle and changed how many colours the picture keeps.

The last holdout was **level 291**, and it is worth remembering why: its
palette was extremely lopsided — two colours held 68% of a 38-wide board
while several others held under 60 cells. Those tiny colours starve, because
a bottle of a colour that barely appears on the bottom edge just sits in a
slot. The search only went down to `maxColors - 2`; the level needed
`9 -> 5`, i.e. merging the slivers away entirely. Colour offsets now reach
`-4`.

### Solvability fallout, and the fix
Snapping changes the boards, so deals had to be re-searched.
- First reproof: **38/300 unrepairable**
- Diagnosis: deals derive from `witnessOrder()`, a *greedy* solve. When greedy
  fails, the old code fell back to the raw colour-sorted deal, which is almost
  never winnable — so "unrepairable" mostly meant "greedy gave up".
- Fix: `_Solver.winningOrder()` — reads the dock order straight out of a
  successful **backtracking** search, used as the fallback.
- Second problem: that fallback ran inside the seed-search loop, making the
  reproof crawl. `_baseOrder` is now **memoised** — it depends only on the
  board and the chunk seed, never on `shuffleWindow`/`dealSeed`.

**A cache bug caught by an inconsistency, not by a test.** The memo above was
first keyed by a *content hash* of the grid's cells. A straggler re-run then
repaired level 130 using the exact parameters that had failed for it minutes
earlier — a deterministic search giving two different answers. The cause was
the key: two different boards can hash to the same string, and a collision
hands back a base order computed for a *different board*, i.e. a deal that
does not match the level being played. It is now keyed by the grid **object**
through an `Expando`, which cannot collide and needs no eviction.

Worth noting how it surfaced: no test failed. The only signal was "this
result contradicts the earlier one", which is why the earlier pass's results
were thrown away and the whole 300-level sweep re-run from scratch rather
than patched on top.

`tool/apply_deal_patch.py` (new) applies the resulting patch **line-surgically**
— `levels.json` does not round-trip through `json.dumps`, so a full rewrite
would bury the handful of changed numbers in a huge diff.

---

## 4. The other fixes

| Report | Fix |
|---|---|
| Banner takes too much space | It was requesting `getLargeAnchoredAdaptiveBannerAdSize` — the *large* variant, ~2× height. Now fixed **320×50** (`AdSize.banner`). The plugin has deprecated the normal adaptive size in favour of large, so adaptive is not an option here; a banner that crowds the board costs more in retention than it earns. |
| Everything jumps when the banner appears | It reserved **zero height** until an ad loaded. The strip is now claimed as soon as ads unlock, painted panel-colour while empty, so the layout never moves. Still zero height during the ad-free onboarding levels. |
| Can escape the ad by pressing Home after losing | Menu was the one exit with no ad. All four exits (next / retry / replay / menu) now share one gate (`_showExitInterstitial`, level ≥ 4, 30s apart). Double-back is left alone. |
| Playable must match the game, have sound, a hand pointer | Rewritten: game HUD + progress bar, machine frame, slot holders, tray panel, the new 12-colour palette, **WebAudio-synthesised** sound (no files — the single-file/no-request rule), a **cartoon hand** that loops "move in and tap" on the bottle that has work until the first dock, and a persistent CTA. Verified winnable through its QA hook: 20 bottles, 0 cells left, tutorial dismisses on first dock. |

---

## 5. Blocked, again, on the same wall

**Facebook:** configured to the final "Create app" click; Meta demanded the
account password. Cancelled cleanly — verified afterwards: still 16 apps, no
Coloro, nothing half-created. This is the second attempt; not looping on it.

---

## 6. Google Ads — prepared, deliberately not launched

Account `806-993-4443`, currency **EGP**, **billing already active**
(E£49.28 spent, 425 clicks, 4 existing campaigns) — so no payment details
were needed, and none were entered. No Coloro conversions imported yet;
Firebase is not linked.

Permission to launch was given and the gate is open. I did not launch:

1. **1.0.7 replaces the build within hours** and fixes the exact thing the ads
   would be selling. Paying to show people the defect is backwards.
2. **Mediation isn't configured** — every impression those installs generate
   would earn 30–80% less than it will next week.
3. **No video creative yet**, and App campaigns spend most of their budget on
   video.

Full reasoning is in `marketing/MARKETING_PLAN.md` §2.2b, with the launch
checklist ready to execute.

---

## 7. Ship

`./scripts/deploy_mobile_version.sh` — clean in **7m 44s**:

- **Google Play** — versionCode **7** uploaded, assigned to internal, committed
- **TestFlight** — IPA validated, `UPLOAD SUCCEEDED`, delivered

Then in the Play Console: production release created with version 7, release
notes written, saved, and **submitted for review**.

**iOS was deliberately NOT submitted** — per instruction, the build goes to
TestFlight only because Apple already has a version in review. Submitting a
second one would replace it in the queue and restart the clock.

Store art was regenerated from the updated game before deploying
(`ASO_OUT=aso flutter test test/aso_generator_test.dart`), so the screenshots
show the new palette rather than the near-identical purples.

### Verification before shipping

```
flutter analyze lib/ test/ tool/                              clean
flutter test                                                  66/66
COLORO_FULL_SWEEP=1 flutter test test/stall_diagnostic_test   303/303
```

---

## 8. Still open

1. **Facebook app** — blocked on the account password, twice now. ~2 minutes
   for Ahmed; the SDK work after it is a small Android-only change.
2. **Google Ads campaign** — prepared but deliberately not launched; see §6
   and `marketing/MARKETING_PLAN.md` §2.2b. The gate is open whenever
   mediation and the video creative are ready.
3. **AdMob mediation** — the highest-value remaining task, and a prerequisite
   for spending anything on ads.
4. **Play listing art** — the live listing still shows pre-1.0.6 screenshots.
   Upload `aso/screenshot_1..5.png` + `aso/feature_graphic.png` once 1.0.7 is
   approved. Not done mid-review because changing listing assets can restart
   the review clock.
5. **iOS divergence.** Apple is reviewing 1.0.6 — the *old palette* build.
   1.0.7 is TestFlight-only per instruction. Until Ahmed submits 1.0.7 after
   Apple's current review resolves, the App Store ships the "two greens"
   version while Play ships the fix.
6. **The tree is uncommitted, and `lib/` + `assets/levels/levels.json` must be
   committed together** — the deals were searched against this exact
   quantizer, so a split commit rebuilds the unwinnable state.
