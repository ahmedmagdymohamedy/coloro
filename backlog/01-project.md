# What Coloro is, and what we are trying to do

## The game

A Flutter pixel-art painting arcade game, in the lineage of *Pixel Flow*.
Level art is quantised to a pixel grid and a limited palette. The player taps
paint bottles from a tray; a tapped bottle docks into one of **4 machine
slots** and drinks its own colour off the picture.

The mechanic that makes it a puzzle rather than a toy:

- **Bottles drink from the bottom edge only** — each column's lowest remaining
  pixel, deepest row first, left to right, one pixel per take. Fully
  deterministic; no randomness in the drain.
- **The picture therefore paints outside-in.** A bottle whose colour is not on
  the current frontier has nothing to drink.
- **A starving bottle jams its slot.** All four slots starving past a 1.4s
  grace = **Machine Jammed**, and the level is lost.

That fail state is deliberate — the game needs a way to lose. It is also,
as it turned out, the single biggest thing standing between a new player and
the rest of the game (see decision **D-14**).

**Every level is provably winnable.** `BottleFactory.isDealSolvable` runs a
slot-constrained search over the real game rules, and each of the 300 levels
ships with a `shuffleWindow` + `dealSeed` pair that has been proven to have a
winning line. `COLORO_FULL_SWEEP=1 flutter test test/stall_diagnostic_test.dart`
re-proves all 300 and is the gate on any release.

## The business

| | |
|---|---|
| **Goal** | $10,000 **net** revenue in 6 months (28 Aug 2026 → 28 Feb 2027) |
| **Budget** | 5,000 EGP/month ≈ $100/month, $600 total. **Ahmed's one hard red line: never exceed it.** |
| **Model** | Free, ad-supported. AdMob banner + interstitial + rewarded, with AdMob mediation. No IAP. |
| **Owner** | Claude runs the marketing plan and makes the calls; Ahmed provides Chrome access and does anything requiring a password or a payment method. |

**The honest forecast, stated at the start and unchanged:** $600 buys roughly
2,000 installs at a $0.30 CPI — about 5% of what $10k needs. **So ~95% of the
target has to come from free installs** (ASO and cross-promotion). A realistic
good outcome for a first casual title is **$1,500–$4,000**; $10,000 needs a
breakout. As of the first flight, both free channels are delivering ~zero, so
the honest number is lower still — see `03-metrics.md`.

## Who does what

**Ahmed Magdy** (he/him) — owner, Megz Games. Prefers short answers, delegates
broadly, cares about revenue outcomes over process. Works through the Claude
Chrome extension for all console work.

**Things only Ahmed can do:** anything needing a password, a payment method,
or a monetary value typed into an ad platform. Notably: App Store Connect
submission, AdMob bank details, and ad-campaign budgets.

## Reference — accounts and IDs

Scattered across session records until now; collected here so no future
session has to go hunting.

### Google Play
- Developer account **9004145411394454957** (Megz Games)
- App id **4973484828510117385**, package **`com.megz.coloro`**
- Internal test opt-in: `https://play.google.com/apps/internaltest/4701727256833733267`
- Console renders in **Arabic / RTL** for this account — coordinate clicks
  land badly; prefer `find` and ref clicks

### AdMob
- Publisher **ca-app-pub-3208735875691916**
- Android app id `ca-app-pub-3208735875691916~6620295929`
- Ad units — banner `/8934478391`, interstitial `/5307214257`, rewarded `/2681050910`
- Mediation groups (Android): Banner **6191461226**, Interstitial **9059841517**, Rewarded **3373720499**
- House campaign `Coloro-House-CrossPromo` **24196628355**; second campaign `Coloro` **24197514460**
- Lives at **admob.google.com** — `apps.admob.com` is a dead host

### Google Ads
- Account **806-993-4443**, currency EGP
- Campaign `Coloro-AC1-Install-Flight1` **24202059293**

### Firebase / Analytics
- Project **coloro-e4a4b**
- GA4 property **551039054**, account **a217305189**

### Unity
- Org **11270006112895**, project **7ce026b1-7c1c-4d4d-ab97-4c9fbc2a222a**
- Game ID Android **6183792** (iOS 6183793, unused)

### Apple
- Team **7TR5648CPX**, Apple ID `ahmedmagdymohamedy@gmail.com`

### Elsewhere
- Privacy policy Play points at: `https://sites.google.com/view/ammegz`
  — **this is a generic Megz-wide policy, not Coloro's.** The accurate one is
  `aso/privacy_policy.md` and has never been hosted. See **D-11**.
