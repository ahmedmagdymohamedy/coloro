# Flight 1 — first read, 3 Sep 2026

**Window:** campaign enabled 1 Sep; this reads the two complete days **1–2 Sep**
(Google Ads reports on complete days only). AdMob/GA4 figures noted per row.
**Nothing in any console was changed while producing this.**
Measured against `MARKETING_PLAN.md` §2.5 (kill criteria) and §5 (month-1 gate).

---

## 1. Acquisition — working, and cheaper than planned

| | Impressions | Clicks | CTR | Installs | Cost |
|---|---|---|---|---|---|
| **Google Ads** `Coloro-AC1-Install-Flight1` | 24,046 | 2,213 | **9.2%** | **112** | **≈E£1,700 (≈$34)** |
| **AdMob house cross-promo** (7d) | 511 | 3 | 0.59% | **0** | E£0.06 |

**CPI = E£15.18 ≈ $0.30** — exactly the tier-3 CPI §0 assumed, and 3× better
than the $0.90 kill line. Bid strategy still in learning; spend paced at
≈E£850/day against a E£500/day budget, which is inside Google's normal 2×
overdelivery and self-corrects over the flight.

The creative is not the problem. A 9.2% CTR on an app campaign is strong.

**The house campaign is delivering nothing** — 511 impressions and 0 installs
in a week, against §1.2's target of 500–1,500 installs/month. Google-optimized
backfill only serves inventory that would otherwise go unfilled, and only 4 of
9 ad sizes are uploaded. As configured this channel is not a channel.

## 2. The funnel — where the money actually goes

GA4, `coloro-e4a4b`, 6 Aug – 2 Sep (99 `first_open`; the large majority are
the campaign cohort):

| Step | Users | % of opens |
|---|---|---|
| `first_open` | 99 | 100% |
| `game_started` | 70 | 71% |
| lost level 1 (`game_lost_1`) | 36 | 36% |
| **won any level** (`game_won`) | **24** | **24%** |
| **reached level 5** (`finish_level_5`) | **8** | **8%** |
| **saw any ad** (`ad_shown`) | **8** | **8%** |

Sessions per user: **1.7**. Losses: 291 across 46 users — **6.3 losses each**.

Two things follow, and they are the whole story:

1. **The wall is at level 1–3, not later.** Players are not bored, they are
   stuck: 36 of the 70 who start lose level 1, and the average loser tries six
   times. Past the wall the game holds people well — 8 → 6 → 4 → 4 → 3 → 3 →
   3 → 3 users at levels 5/10/15/20/25/30/35/40, and one at 45.
2. **Ads unlock at level 4, so ~92% of every dollar buys a user who never sees
   a single ad.** The ad-free onboarding is protecting retention we do not have.

## 3. Revenue — 1/120th of spend

| | Impressions | eCPM | Revenue |
|---|---|---|---|
| AdMob, Coloro, 1–3 Sep | 56 | $5.05 | **$0.28** |
| AdMob, Coloro, last 30d | 256 | $3.24 | $0.83 |
| **Unity Ads, Coloro** | **0** | — | **$0.00** |

**≈$34 spent, $0.28 earned — about $121 of ad spend per $1 of ad revenue.**

**ARPDAU ≈ $0.002 against the $0.03 modelled in §0 — roughly 15× short.**
That single number is why the six-month arithmetic no longer works.

Unity Ads has served **zero** impressions. That is not a mediation fault:
1.0.8 (which carries the adapter) only went live on 1 Sep, and with 56 total
impressions in the app there is nothing for Unity to win. Mediation cannot be
evaluated until impression volume exists. It is not the bottleneck and fixing
it will not move revenue.

## 4. Gate check — the plan's own criteria

| §2.5 criterion | Result | |
|---|---|---|
| CPI > $0.90 → pause geo | $0.30 | **PASS** |
| `finish_level_5` ≥ 15% of installs | **0%** ad-attributed; 8% all-time | **FAIL** |
| Cost per `finish_level_5` < $3.00 | ≈$4.25 even counting all 8 all-time | **FAIL** |

§5 month-1 gate (D1 retention < ~30% → stop spend, work §4): cohorts are too
small for a clean D1 read, but every proxy agrees — 1.7 sessions/user, 29%
never start a level, 76% never win one.

**The plan's own verdict: the ad is not over-promising, the game is
under-delivering. §2.5 says in that case "fix the creative, not the bid" — the
data says fix the game, not the creative.**

---

## 5. Recommendation

### Stop the flight now. Do not run it to 13 Sep.

This knowingly overrides §2.3's "do not touch it for the full 10 days". That
rule exists to protect *bid learning*, and no amount of bid learning fixes a
product that loses 92% of its users before the ad gate. §2.2b already
established the governing principle when it refused to launch on 1.0.6:
**buying installs onto a build with a defect means paying to show people the
defect.** The onboarding wall is that defect today.

Stopping does not cost us the retention read — we keep the 112-user cohort and
let it age. It saves roughly **E£4,800–6,500 (≈$96–130)** of the flight.

### Then, in value order — all of it is §4 work the plan already anticipated

1. **Rewarded "skip this level" after 2–3 losses.** Highest value by far: it
   converts the 291 failures into rewarded impressions *and* rescues players
   past the wall. It fixes the revenue problem and the retention problem with
   one surface.
2. **Ease levels 1–5.** 36 of 70 starters lose level 1. Lower grid/colours/
   churn and soften or remove the jam fail state for the first few levels.
3. **Move the ad gate earlier** — banner from level 1–2 rather than 4. With
   1.7 sessions per user there is little retention left to protect.
4. **In-app review prompt** after a win streak — ratings feed ASO, which §0
   says must carry 95% of the target.
5. **Fix or replace the house campaign** — upload the remaining 5 sizes, and
   prefer a real in-game "More Games" button over backfill-only inventory.

### Re-run paid only when this passes

**Gate for flight 2: `finish_level_5` ≥ 15% of installs on organic traffic.**
Same creative — it works. Until that gate passes, paid spend is buying users
the game cannot keep or monetise.

## 6. Is $10,000 net still on?

**No — and it never rested on the ad budget.** §0 said as much: $600 buys ~2,000
installs, about 5% of what the target needs, so 95% was always meant to come
free from ASO and cross-promo. Both free channels are currently at ~zero.

Current gross run-rate is roughly **$3/month** against a month-1 target of
**$200**. The gap is about three orders of magnitude, and no reallocation of
$600 closes it.

What is still reachable is §0's honest base case of **$1,500–$4,000**, and it
runs entirely through ARPDAU: $0.002 → $0.03 is a 15× move, and items 1–3
above are aimed exactly at it. The game past level 5 is good — people who get
in keep playing to level 40. Everything hinges on getting more of them in.

## 7. Blocked on Ahmed

- **AdMob payouts:** bank account details still not added, so earnings cannot
  be paid out (identity verified, threshold reached).
- **Unity payout profile:** still not set up.
- Neither blocks the work above; both block money actually arriving.
