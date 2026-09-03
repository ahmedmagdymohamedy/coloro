# Coloro — engineering handoff

**Last updated:** 1 Sep 2026 (evening — after the Play data-safety rejection).
Session records: `chat_history/`. Marketing: `marketing/MARKETING_PLAN.md`.

---

## Status

| | |
|---|---|
| **Google Play** | **Live to users = 1.0.8** (approved 3 Sep after the data-safety fix). **1.0.9 (code 9) uploaded to production 3 Sep and IN REVIEW**; the same bundle is **live on internal testing now** — installable via https://play.google.com/apps/internaltest/4701727256833733267. Listing art = 1.0.7 palette. |
| **TestFlight** | **1.0.9 (build 9) uploaded 3 Sep** — validated and delivered (UUID `7cd97c4a-35ea-442e-b9a4-2490e9ad5cab`). **Not submitted for App Store review:** 1.0.7 has been Waiting for Review since 1 Sep and pulling it would forfeit that queue position. Submit 1.0.9 once 1.0.7 is through — needs Ahmed's ASC login. |
| **Flight 1** | Ran 1–2 Sep, **PAUSED 3 Sep** at ≈E£1,700 (~$34) spent. CPI $0.30 was on plan; both value gates failed. Full read: `marketing/FLIGHT1_READ_2026-09-03.md`. **Restart planned at E£100/day — BLOCKED, needs Ahmed** (see below). |
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

**1.0.9 followed it.** It went to production directly because Ahmed asked for
a new version submitted to both stores, and the internal release was added by
hand the same night from the same code-9 bundle — so there is something to
install while production sits in review.

## What 1.0.9 changes, and why (3 Sep, autonomous session)

Ahmed handed over the decisions with one red line — **never exceed the
budget** — and went to sleep. Three things happened:

1. **The ad flight was paused.** Spend stopped at ≈E£1,700 of ≈E£6,500.
2. **The ad gate moved down**: `adsFromLevel` 4 → 1 (banner),
   `interstitialFromLevel` 4 → 2. The old gate meant 92% of paid installs
   never saw an ad.
3. **Losing three times now has a door out**: a `SKIP THIS PICTURE` offer on
   the fail card, rewarded when inventory exists, granted either way. Skipped
   levels are unlocked but never counted as completed.

**Two design decisions worth not re-litigating:**

- **The skip is granted even with no ad.** A player refused after three
  defeats churns, and a churned player earns nothing. The ad is the upside,
  not the toll.
- **The back-button exit was left alone.** It is unserved inventory and it was
  tempting, but "double-back is deliberately left alone" was a recorded
  decision, not an oversight.

**Deliberately NOT done: easing levels 1–5.** The obvious reading of "36 of 70
lose level 1" is that the early levels are too hard, but levels 1–4 are
already at the generator's floor — 15×15 grid, 5 colours, the minimum of the
ramp. The wall is the *mechanic* (bottles starve, slots jam), not the grid, so
regenerating art would have burned a long solver run to change nothing.
Anything real here means a tutorial or a more forgiving early jam rule, which
is a design change to make awake. The skip offer is the safety valve until
then.

Tune `_skipOfferAfterLosses` (game_screen.dart) against the new
`level_skipped` event, which carries the loss count that earned each skip.

## ⛔ Blocked on Ahmed — restarting the flight at E£100/day

The "restart when organic traffic clears 15%" gate was **wrong** — there is no
organic traffic, so it could never be met. Corrected reasoning and the dead
free-channel evidence are in `MARKETING_PLAN.md` §2.7.

**Two clicks needed in Google Ads** (account 806-993-4443, campaign
`Coloro-AC1-Install-Flight1`, id 24202059293):

1. Daily budget **E£500 → E£100**
2. Status **Paused → Enabled** (end date stays 13 Sep)

≈E£1,100 to 13 Sep ≈ 70 installs; September total ≈E£2,800 of the 5,000
budget. **A session agent cannot do step 1** — typing a monetary value into an
ad platform is refused by the permission layer, and it should stay that way.
The campaign is safely paused until then; nothing is spending.

Also worth 30 seconds while in AdMob: campaign **`Coloro` (24197514460)** is
an install campaign with a **max CPI of E£1.00** against a market rate of
~E£15. It cannot win an auction, and has served 285 impressions for 0
installs. Re-price it or pause it.

## ▶ Where to resume (next session, in value order)

0. **✅ 1.0.8 is approved and live** (verified 3 Sep). The data-safety fix
   worked. Nothing to watch there any more.
1. **Read `marketing/FLIGHT1_READ_2026-09-03.md`** — it is the current state
   of the whole marketing plan and the reasoning behind everything above.
   Then watch whether 1.0.9 moves the two numbers that matter:
   **`ad_shown` users / `first_open` users** (was 8%) and
   **`finish_level_5` / installs** (was 8%). Flight 2 restarts only when the
   second clears 15% on organic traffic.
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
