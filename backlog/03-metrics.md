# Metrics over time

Every reading, dated, in one place — so the next one can be compared against
the last instead of re-derived from a dated file. Add a row; never edit an old
one.

Currency note: figures are quoted as measured. **E£50 ≈ $1** is the rate the
plan uses throughout.

---

## The two numbers that decide everything right now

Both were **8%** on the flight-1 cohort. 1.0.9 exists to move them.

| Date | Build | `ad_shown` users ÷ `first_open` users | `finish_level_5` ÷ installs | Source |
|---|---|---|---|---|
| 2 Sep | 1.0.7 / 1.0.8 | **8%** (8 of 99) | **8%** (8 of 99 all-time); **0%** ad-attributed | GA4 + Google Ads |
| *13 Sep* | *1.0.9* | *target: well above 8%* | *target: ≥15%* | *pending* |

The first should move on its own as existing players update to 1.0.9 — it
needs no new installs. The second needs the paid cohort bought under **D-16**.

## The funnel (GA4, 6 Aug – 2 Sep, 99 `first_open`)

| Step | Users | % of opens |
|---|---|---|
| `first_open` | 99 | 100% |
| `game_started` | 70 | 71% |
| lost level 1 (`game_lost_1`) | 36 | 36% |
| won any level (`game_won`) | 24 | 24% |
| reached level 5 (`finish_level_5`) | 8 | 8% |
| saw any ad (`ad_shown`) | 8 | 8% |

Sessions per user **1.7**. Losses **291 across 46 players — 6.3 each**.

Depth is fine once players are in: 8 → 6 → 4 → 4 → 3 → 3 → 3 → 3 users at
levels 5/10/15/20/25/30/35/40, and one at 45. **The wall is onboarding, not
depth.**

## Ad revenue

| Period | Build | Impressions | eCPM | Revenue | Notes |
|---|---|---|---|---|---|
| 4 Aug – 2 Sep (30d) | 1.0.6→1.0.8 | 256 | $3.24 | **$0.83** | 1,133 requests → 591 matched (52%) → 256 shown (43%) |
| 1–3 Sep | 1.0.8 | 56 | $5.05 | **$0.28** | 100% AdMob Network |
| any | — | **0** | — | **$0.00** | **Unity Ads** — zero impressions ever |

**Baseline recorded 1 Sep, before mediation** (last 7 days, AdMob Network, EGP):
interstitial eCPM 264.16 · rewarded 453.48 · banner 12.33 (match rate **40.98%**)
· blended **161.92**, 371 requests. Kept so mediation can be judged later —
but it cannot be judged yet, because there is no impression volume to judge it
with (**D-9**).

**ARPDAU: ~$0.002 against the $0.03 the plan models — 15× short.** This single
number is why the six-month arithmetic no longer works.

## Paid acquisition

| Flight | Dates | Budget | Impressions | Clicks | CTR | Installs | CPI | Spend |
|---|---|---|---|---|---|---|---|---|
| 1 | 1–2 Sep | E£500/day | 24,046 | 2,213 | **9.2%** | **112** | **E£15.18 (~$0.30)** | **≈E£1,700 (~$34)** |
| 1 (resumed) | 3–13 Sep | E£100/day | — | — | — | *~70 expected* | — | *≈E£1,100 expected* |

Geos: EG, SA, AE, MA, DZ, IQ, JO. Bidding: maximise installs, no target CPI.

**Against the plan's own kill criteria:** CPI **passed** ($0.30 vs $0.90 bar).
`finish_level_5` ≥15% **failed** (0% attributed / 8% all-time). Cost per
`finish_level_5` <$3 **failed** (~$4.25 even counting all 8 all-time).

## Free acquisition — currently zero

| Campaign | Configuration | Window | Impressions | Installs |
|---|---|---|---|---|
| `Coloro-House-CrossPromo` | Google-optimised backfill | 27 Aug – 2 Sep | 222 | **0** |
| `Coloro` (24197514460) | AdMob install, **max CPI E£1.00** vs ~E£15 market | 27 Aug – 2 Sep | 285 | **0** |

Target was 500–1,500 installs/month from cross-promotion alone. See **D-15**.

## Budget consumed

| Month | Budget | Spent | Committed | Notes |
|---|---|---|---|---|
| Sep 2026 | E£5,000 | **≈E£1,700** | ≈E£1,100 (to 13 Sep) | Landing near **E£2,800** |

Programme total is $600 ≈ E£30,000 over six months; ~E£2,800 of it used.

## Store state

| | |
|---|---|
| Play production | **1.0.9** live 3 Sep 05:14, 177 countries |
| Play internal testing | 1.0.9 |
| App Store | not yet live — **1.0.7 Waiting for Review since 1 Sep**; build 9 sits in TestFlight, unsubmitted on purpose |
| Play rating | — |
