# Coloro — engineering handoff

**Last updated:** 1 Sep 2026.
Session records: `chat_history/`. Marketing: `marketing/MARKETING_PLAN.md`.

---

## Status

| | |
|---|---|
| **Google Play** | **LIVE.** Production = 1.0.7 (code 7); **1.0.8 (code 8) uploaded to production 1 Sep, in Google's update review** — adds Unity Ads mediation. Listing art = 1.0.7 palette. **Install campaign `Coloro-AC1-Install-Flight1` ENABLED 1 Sep** — no campaign edits until it completes 13 Sep. |
| **App Store** | Old-palette queue entry removed 1 Sep; **1.0.7 (build 7, fixed palette) submitted, Waiting for Review**, auto-release on approval. No mediation on iOS by design. |
| **Monetization** | **Unity Ads bidding live in 3 AdMob mediation groups** (banner/interstitial/rewarded, Android). AppLovin pending its SDK key (waterfall only — no AdMob bidding). House campaign `Coloro-House-CrossPromo` running (4/9 sizes). Baseline eCPM recorded pre-mediation. Details: `chat_history/2026-09-01-mediation-and-releases-session.md`. |
| **Git** | ✅ Clean and pushed. `39cc662` = 1.0.7 as shipped; `29f95a1` = 1.0.8 mediation. |

---

## ✅ Resolved 1 Sep: the tree is committed and pushed

The former warning here (33 uncommitted files, `lib/` + `levels.json`
coupling) is closed: `39cc662` committed the 1.0.7-as-shipped tree in one
piece after a 303/303 full sweep, and `29f95a1` added the 1.0.8 mediation
change. The `lib/` + `assets/levels/levels.json` matched-pair rule still
applies to any future palette/quantizer work.

## ▶ Where to resume (next session, in value order)

1. **AppLovin SDK key** (Ahmed was locked out of max.applovin.com; reset
   pending). When available: `applovin.sdk.key` meta-data in
   `AndroidManifest.xml` + AppLovin as a *waterfall* source in the three
   mediation groups (it does not bid on AdMob) → ship as 1.0.9.
2. **Check the reviews**: Play 1.0.8 rollout; Apple 1.0.7 (auto-releases).
   When iOS is live: declare the iOS platform in the Meta app
   (`marketing/docs/facebook-app-events.md` §1b) and plan iOS mediation
   behind a real ATT flow.
3. **13 Sep**: the Google Ads flight completes — read against
   `marketing/MARKETING_PLAN.md` §2.5 kill criteria. Until then: hands off.
4. **~8 Sep**: compare mediation vs the baseline table in
   `chat_history/2026-09-01-mediation-and-releases-session.md` §5.
5. Ahmed's own list: Unity payout profile; revoke the 3 unknown "Windows"
   browsers in the Claude extension; 5 remaining house-ad sizes (any
   session can click those through).

---

## What changed in 1.0.7

### 1. Fixed 12-colour palette — the "two greens" fix

`lib/data/game_palette.dart` is new and is now the only source of colour.
Levels no longer derive a palette from their art; every pixel snaps to one of
twelve.

Two constraints, both locked by `test/game_palette_test.dart`:

1. **One colour per 30° hue slot.** This is the one that answers the
   complaint. A distance metric will happily call a dark cyan and a light
   cyan "different"; a player reads them as one colour lighter.
2. **Maximum minimum separation** under the quantizer's own metric →
   **closest pair 62**, against the **52** at which the old code merged two
   colours outright.

`DisplayPalette.of()` is now a **pass-through**. Its lightness remap existed
to rescue dark art-derived palettes; applied to a fixed palette it compresses
the closest pair from 62 down to 21 and would undo the whole fix. It stays as
the single entry point every renderer goes through, which is what keeps a
flask and the pixels it drinks the same colour.

**All 300 levels re-proved solvable** (303/303). 242 were unaffected, 58
needed a new deal, **0 unrepairable**. Only one lost difficulty (a weaker
shuffle window). Final colour spread: 4 colours on 12 levels, 5 on 63, 6 on
99, 7 on 78, 8 on 39, 9 on 9.

**Bottle capacity cap came down** (`bottle_factory.dart`): `min(40, total/3)`
→ `min(20, total/4)`. Merging near-identical colours makes each surviving
colour's cell count bigger, which under the old formula produced 40-capacity
bottles that sat in a slot starving. This was the single biggest cause of
levels becoming unwinnable after the palette change.

### 2. Ad fixes

| Report | Fix |
|---|---|
| Banner too big | It requested `getLargeAnchoredAdaptiveBannerAdSize` — the *large* variant, ~2× height. Now a fixed **320×50**. The plugin has deprecated the normal adaptive size in favour of large, so adaptive isn't an option; a banner that crowds the board costs more in retention than it earns. |
| Layout jumps when the banner appears | It reserved **zero** height until an ad loaded. The strip is now claimed as soon as ads unlock and painted panel-colour while empty. Still zero height during the ad-free onboarding levels. |
| Ad escapable via Home after losing | Menu was the only exit without an ad. All four exits — next, retry, replay, menu — now share one gate (level ≥ 4, 30s apart). Double-back is deliberately left alone. |

### 3. Playable v2 (`marketing/playable/coloro_playable.html`)

Rewritten to match the game: HUD with progress bar, machine frame, slot
holders, tray panel, the new palette, **WebAudio-synthesised sound** (no
files — the single-file/no-request rule still holds), a **cartoon hand** that
loops "move in and tap" on the bottle that has work until the first dock, and
a persistent CTA. Still one file, ~27 KB, zero network requests.

Verified through its own QA hook: wins with **0 cells left**, tutorial
dismisses on first dock, win card renders.

---

## New tools

| Tool | What it does |
|---|---|
| `tool/audit_palette.dart` | Reports what snapping does to all 300 levels, in seconds, without solving. Run this before any slow re-search. |
| `tool/render_level.dart N out.png` | Renders a level's quantized grid to a PNG so colour work can be eyeballed without launching the app. |
| `tool/reproof_deals.dart` | Re-proves all 300 levels and searches `dealSeed` → `shuffleWindow` → `maxColors` (cheapest knob first) for any that lost their winning line. |
| `tool/apply_deal_patch.py` | Applies the patch **line-surgically**. `levels.json` does not round-trip through `json.dumps`, so a full rewrite would bury the changed numbers. |
| `tool/probe_level.dart N` | Explains *why* one level is unsolvable — board shape, bottle sizes, and escalating search budgets. |

Two solver improvements worth knowing about, in `bottle_factory.dart`:

- **`_Solver.winningOrder()`** — deals used to come from a *greedy* witness,
  and when greedy failed the code fell back to the raw colour-sorted deal,
  which is almost never winnable. It now falls back to the dock order of a
  real backtracking solve.
- **`_baseOrder` is memoised** — it depends only on the board and the chunk
  seed, never on `shuffleWindow`/`dealSeed`. Without this the generator and
  the reproof tool redid the expensive fallback on every seed attempt.

---

## iOS: resolved 1 Sep — 1.0.7 is the build in Apple's queue

The old-palette submission (version record "1.0.5" carrying build 6) was
removed from review on 1 Sep; the record was renamed **1.0.7**, build 7
(fixed palette, from TestFlight) attached and submitted. Auto-release on
approval. The stores now differ only by minor version (iOS 1.0.7 vs Android
1.0.8) — mediation is Android-only on purpose (no App Store presence yet,
prior tracking-signal rejection, SPM-only build). iOS mediation is a future
release with a real ATT + UMP consent flow.

---

## Verification

```sh
flutter analyze lib/ test/ tool/
flutter test
COLORO_FULL_SWEEP=1 flutter test test/stall_diagnostic_test.dart   # all 300
dart run tool/audit_palette.dart                                   # colour spread
```
