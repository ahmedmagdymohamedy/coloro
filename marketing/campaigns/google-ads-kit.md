# Google Ads — App campaign kit (ready to launch on approval)

Everything needed to build the campaign the moment both stores approve.
Nothing here has been submitted; per Ahmed's instruction the campaigns get
created only on his go-ahead.

---

## 1. The number first: what $10,000/year actually requires

This is the part worth reading before spending anything.

**Revenue = DAU × ARPDAU × 365.** For an ads-only casual puzzle:

| Input | Realistic range | Used below |
|---|---|---|
| ARPDAU, tier-3 heavy mix (MENA/SEA/LATAM) | $0.008 – $0.018 | **$0.012** |
| ARPDAU, mixed with 30% tier-1 | $0.025 – $0.045 | **$0.030** |
| CPI, casual puzzle, tier-3 | $0.25 – $0.70 | **$0.45** |
| CPI, casual puzzle, tier-1 | $1.20 – $3.00 | **$1.80** |

$10,000/yr = **$833/month**.

- At ARPDAU $0.012 → need **≈ 2,300 DAU** sustained.
- At ARPDAU $0.030 → need **≈ 930 DAU** sustained.

With a normal casual retention curve (D1 40%, D7 15%, D30 5%), each daily
install contributes roughly 8–12 DAU-days, so sustaining ~1,000 DAU needs
**~100 net new installs every day, all year** — roughly **35,000 installs**.

### The uncomfortable conclusion

At $0.45 CPI, 35,000 paid installs cost **~$15,750** to earn **~$10,000**.

**Paid user acquisition does not pay for itself at this app's current ARPU.**
Buying our way to the target loses money. Anyone who tells you to just "run
ads and scale" is skipping this arithmetic.

So the plan below is deliberately ordered:

1. **Organic first** (ASO, store conversion) — free installs, positive margin.
2. **Raise ARPU** before scaling spend — this is the real lever.
3. **Paid only as a bounded test**, to find one geo × creative pocket where
   LTV > CPI. Scale only that pocket, only if it proves out.

### Raising ARPU is the highest-leverage work (do this first)

| Lever | Expected effect | Effort |
|---|---|---|
| **AdMob mediation** (add AppLovin, Unity, ironSource, Meta bidding) | **+30–80% eCPM.** Single biggest win available. One SDK config, no game changes. | 1 day |
| Interstitial on retry *(shipped this release)* | +15–30% impressions/session — losing is the most common transition | done |
| Rewarded promoted to primary on the fail card *(shipped)* | rewarded is the highest-eCPM format by far | done |
| Faster levels *(shipped: fill rate 4.5 → 7.0)* | more levels/session → more interstitials | done |
| Rewarded "skip this level" offer after 3 losses | new rewarded surface at the moment of highest intent | 0.5 day |
| Daily-reward rewarded video on the menu | +1 guaranteed rewarded view per DAU | 1 day |

**Do mediation before spending a dollar on ads.** Going from $0.012 to
$0.022 ARPDAU halves the DAU needed to hit the target.

---

## 2. Campaign structure

Google App campaigns (AC) don't take keywords or placements — Google's
models optimise on assets and the conversion signal. So the only real levers
are **asset quality**, **the conversion event**, and **geo × budget**.

| | Campaign 1 — Install volume | Campaign 2 — Value test |
|---|---|---|
| Type | App campaign (AC) | App campaign for engagement/actions (ACe) |
| Goal | Install volume | In-app action |
| Conversion event | `first_open` | **`finish_level_5`** (Firebase → imported) |
| Bidding | Target CPI | Target CPA |
| Start budget | $15/day | $15/day |
| Geo (wave 1) | EG, SA, AE, MA, DZ, IQ, JO | same |
| Geo (wave 2, only if wave 1 clears CPI) | ID, PH, VN, BR, MX, TR | same |
| Run before judging | 14 days minimum | 14 days minimum |

**Do not touch either campaign for the first 14 days.** AC needs ~100
conversions to leave the learning phase; editing resets it. This is the
single most common way small budgets get wasted.

**Wire `finish_level_5` as a conversion first:** Firebase console → Analytics
→ Events → mark `finish_level_5` as a conversion → link Firebase to Google
Ads → import it. That event already ships (see
`lib/core/analytics/analytics_service.dart`). Optimising toward an install is
optimising toward the cheapest install; optimising toward level 5 is
optimising toward a player who might stay.

### Kill criteria (decide in advance, honour them)

- CPI > $0.90 after 14 days → pause that geo, don't "give it more time".
- `finish_level_5` rate < 15% of installs → the ad is promising something
  the game isn't delivering; fix the creative, not the bid.
- Cost per `finish_level_5` > $3.00 → that geo cannot reach the target.

---

## 3. Text assets

Google needs 5 headlines and 5 descriptions. Every line below is within
limits and describes something the game actually does.

### Headlines (30 characters max)

```
Drain the Pixel Picture        (27)
Pick the Right Bottle          (21)
300 Levels, No Timers          (21)
Color Sort, But Prettier       (24)
Relaxing Offline Puzzle        (23)
```

### Descriptions (90 characters max)

```
Tap a bottle. Watch it drink the picture away, one pixel at a time. 300 levels.   (80)
No timers, no lives, no wifi. Just you, the picture, and the order you choose.    (77)
Every level is proven solvable. If you lose, there was a better line to play.     (76)
Pixel art that dissolves as you play. Simple to learn, genuinely hard to master.  (79)
Free color sort puzzle. Plays offline, anywhere, one-handed.                      (59)
```

### Notes on the copy

- **"Proven solvable" is a real differentiator.** Every competitor in color
  sort is accused of shipping impossible levels; the solver gate
  (`test/stall_diagnostic_test.dart`) means this claim is literally true and
  defensible. Lead with it in the value-test campaign.
- **"No timers, no lives, no wifi"** targets the biggest complaint about the
  category — energy meters. It is also all true.
- Avoid "best", "#1", "amazing" — Google disapproves superlatives without
  substantiation, and they convert worse than concrete claims.

---

## 4. Creative assets

### Ready now (in this repo)

| Asset | File | Use |
|---|---|---|
| HTML5 playable | `marketing/playable/coloro_playable.html` | AC playable slot + landing page demo |
| Phone screenshots ×5 | `aso/screenshot_1..5.png` (1080×1920) | portrait image asset |
| Feature graphic | `aso/feature_graphic.png` (1024×500) | landscape image asset |
| App icon | `aso/icon_512.png` | required |

All regenerated from the real game after this release's visual changes, so
no ad can show something the app doesn't do.

### Still to produce (before launch)

| Asset | Spec | Why |
|---|---|---|
| Landscape image | 1200×628 | AC will not serve some inventory without it |
| Square image | 1200×1200 | highest-volume slot in AC |
| Portrait video | 9:16, 15s | video is where AC spends most budget |
| Landscape video | 16:9, 15s | |

**Video script (15s), portrait — shoot as a screen capture:**

| Time | On screen | Caption |
|---|---|---|
| 0–2s | Full colourful board, finger taps a bottle | "Pick a bottle." |
| 2–6s | Bottle docks, drinks the bottom row, picture visibly drains | "It drinks the picture." |
| 6–9s | A bottle goes red, alarm ring pulses | "Pick wrong, it jams." |
| 9–12s | Fast-forward: board dissolves, completion sweep | "300 levels." |
| 12–15s | Icon + "No timers. No lives. Plays offline." + Install | CTA |

First two seconds carry ~80% of the outcome — the tap and the drain must
both be visible before 2s. Don't open on a logo.

---

## 5. Launch checklist (in order)

1. [ ] Both stores approved and live
2. [ ] **AdMob mediation configured** — before any spend
3. [ ] Verify live ads fill on a real device (banner, interstitial, rewarded)
4. [ ] Firebase ↔ Google Ads linked; `finish_level_5` imported as a conversion
5. [ ] Produce the 4 missing creatives above
6. [ ] Build Campaign 1 and 2, $15/day each, wave-1 geos
7. [ ] **Do not edit for 14 days**
8. [ ] Review against the kill criteria; scale only what clears them

---

## 6. Honest position on the $10,000 target

It is reachable, but not by advertising into it at today's ARPU — the
arithmetic in §1 shows paid installs cost more than they return. The
realistic path is:

**ASO and organic installs (free) + mediation lifting ARPDAU 30–80% + a
small, disciplined paid test that scales only where LTV beats CPI.**

The largest single risk is not the ad spend — it is retention. 300
solver-verified levels and no energy meter is a genuinely good retention
story for this category; whether it holds is what the first 30 days of
Firebase data will say. Revisit this whole plan against real D1/D7/D30
numbers before committing budget.
