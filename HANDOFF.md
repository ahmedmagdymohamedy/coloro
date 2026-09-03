# Coloro — engineering handoff

**Last updated:** 1 Sep 2026 (evening — after the Play data-safety rejection).
Session records: `chat_history/`. Marketing: `marketing/MARKETING_PLAN.md`.

---

## Status

| | |
|---|---|
| **Google Play** | **LIVE — production = 1.0.8 (code 8), approved and available** (verified 3 Sep). It had been rejected 1 Sep for an invalid Data safety form; the corrected form cleared review — see "The data-safety rejection" below. Also on internal testing. Listing art = 1.0.7 palette. |
| **Flight 1** | Ran 1–2 Sep. **CPI $0.30 (on plan) but the funnel fails both value gates** — full read in `marketing/FLIGHT1_READ_2026-09-03.md`. **Recommendation to stop the flight is with Ahmed and not executed;** the campaign is still enabled. |
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

## ⚠ The data-safety rejection (1 Sep) — fixed, but read this before adding an SDK

Google rejected **version code 8** with *Invalid Data safety form*: it
detected user data leaving the device — "Device or other IDs", attributed to
`com.applovin:applovin-sdk` — that the form did not declare.

**Root cause: the form declared that the app collects _nothing at all_.**
Question 1 of the Data safety questionnaire ("does your app collect or share
any of the required user data types?") was answered **No**, and had been
since launch. That was already wrong for 1.0.7 — AdMob and Firebase both
transmit identifiers — and the AppLovin adapter in 1.0.8 is simply what made
Google's scanner notice.

**Fix (console only — no code change, no new version code).** The form was
completed from the SDKs' own published Play disclosures, taking the union of
Google Mobile Ads, Unity Ads, AppLovin, Firebase and Meta. All four types are
**collected _and_ shared**, none processed ephemerally, all required (no
in-app opt-out), and encryption in transit = yes:

| Data type | Purposes declared |
|---|---|
| Location → Approximate location | Advertising, Analytics, Fraud prevention |
| App activity → App interactions | Advertising, Analytics, Fraud prevention |
| App info and performance → Diagnostics | + App functionality |
| **Device or other IDs** (the flagged one) | + App functionality |

Also answered: no account creation, no external sign-in, no data-deletion
request mechanism.

**Rules this leaves behind:**

- **Adding any SDK means re-opening this form.** The scanner re-runs on every
  release and compares traffic against the declaration.
- **`aso/privacy_policy.md` must stay in step with the form** — Play policy
  requires the two to agree. It was rewritten the same day to name Unity Ads,
  AppLovin and Meta and to spell out the identifier/location collection.
- **The hosted policy is NOT this file.** Play points at
  `https://sites.google.com/view/ammegz`, a generic Megz-wide policy that
  names AdMob, Flurry, Google Analytics and Facebook Login and never mentions
  advertising IDs. **Ahmed's task:** paste `aso/privacy_policy.md` into that
  Google Site (or host it separately and swap the URL). This is the remaining
  inconsistency a human reviewer could still act on.

## 1.0.8 is now on internal testing too (1 Sep)

It was missing there because the 1.0.8 deploy ran
`deploy_mobile_version.sh --track production`. That flag makes the script
upload the bundle and assign it **straight to production** — it does not pass
through internal testing on the way, so the internal track sat on 1.0.7 (29
Aug) and there was nothing to test.

Fixed by creating an internal-testing release from the **same code 8 bundle**
already in the app-bundle library (Create release → *Add from library* →
code 8), so the build under review and the build being tested are byte
identical. Published immediately; the only warning was the known APK-size
advisory (Unity SDK ≈ +8 MB).

Tester opt-in link (list "My friends", 16 testers):
**https://play.google.com/apps/internaltest/4701727256833733267**

**Rule going forward:** the script's default track is `internal` for a
reason — ship there, test, then promote. Only pass `--track production` when
the build has already been tested, or expect to add the internal release by
hand afterwards.

## ▶ Where to resume (next session, in value order)

0. **✅ 1.0.8 is approved and live** (verified 3 Sep — production track shows
   "متوفر على Google Play", publishing overview clean, no policy issues). The
   data-safety fix worked. Nothing to watch here any more.
1. **The Flight 1 decision is Ahmed's and is open.** Read
   `marketing/FLIGHT1_READ_2026-09-03.md` first — it is the current state of
   the whole marketing plan. Headline: acquisition works (CPI $0.30, 9.2%
   CTR), the funnel does not (8% of installs reach level 5, 92% never see an
   ad, $34 spent → $0.28 earned). The recommendation is to **stop the flight
   and do the §4 game work** — rewarded skip-level after 2–3 losses, easier
   levels 1–5, earlier ad gate. **Do not act on it without Ahmed's word;** it
   overrides `MARKETING_PLAN.md` §2.3's hands-off-until-13-Sep rule.
2. **AppLovin SDK key** (Ahmed was locked out of max.applovin.com; reset
   pending). When available: `applovin.sdk.key` meta-data in
   `AndroidManifest.xml` + AppLovin as a *waterfall* source in the three
   mediation groups (it does not bid on AdMob) → ship as 1.0.9.
3. **Check Apple**: 1.0.7 (auto-releases). When iOS is live: declare the iOS
   platform in the Meta app (`marketing/docs/facebook-app-events.md` §1b) and
   plan iOS mediation behind a real ATT flow.
4. **13 Sep**: if the flight was left running, it completes — read against
   `marketing/MARKETING_PLAN.md` §2.5. (The 3 Sep read already failed two of
   the three gates; see item 1.)
5. **Mediation cannot be evaluated yet.** Unity has served *zero* impressions
   because the whole app only produced 56 in 1–3 Sep. Comparing against the
   baseline table in `chat_history/2026-09-01-mediation-and-releases-session.md`
   §5 is meaningless until impression volume exists — which is the funnel
   problem, not a mediation problem.
6. Ahmed's own list: **add AdMob bank details** (identity verified and
   threshold reached, but nothing can be paid out without them); **host the
   Coloro privacy policy** (above); Unity payout profile; revoke the 3 unknown
   "Windows" browsers in the Claude extension; 5 remaining house-ad sizes —
   though note the house campaign delivered 511 impressions and **0 installs**
   in a week, so more sizes may not be the fix (see the flight read §1).

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
