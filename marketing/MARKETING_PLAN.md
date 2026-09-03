# Coloro — 6-month revenue plan

**Target:** $10,000 **net** revenue in 6 months.
**Budget:** 5,000 EGP/month ≈ **$100/month** ($600 total).
**Owner:** Claude executes this. Ahmed gives Chrome access; no marketing
decisions are pushed back to him.
**Started:** 28 Aug 2026. **Deadline:** 28 Feb 2027.

> **Status 28 Aug 2026: Coloro is LIVE on Google Play.** Approved and
> published 27 Aug — production shows 1.0.6 (code 6) active in 177
> countries, 0 installs so far. The App-campaign gate in §2 is therefore
> **open**.
>
> This file is the operating plan and the running checklist. Tick boxes as
> they land. The reasoning behind each choice is here too — do not re-derive
> it, and do not skip a gate because it is inconvenient.

---

## 0. The honest arithmetic — read before spending anything

Net revenue = ad revenue − ad spend. Spend is fixed at $600, so the target
needs roughly **$10,600 gross in 6 months**.

Revenue ramps, so the realistic shape is something like:

| Month | Gross needed | DAU @ $0.03 ARPDAU | DAU @ $0.05 |
|---|---|---|---|
| 1 | $200 | 220 | 130 |
| 2 | $500 | 550 | 330 |
| 3 | $1,000 | 1,110 | 670 |
| 4 | $1,800 | 2,000 | 1,200 |
| 5 | $2,800 | 3,100 | 1,870 |
| 6 | $4,300 | 4,780 | 2,870 |

Sustaining ~3,000 DAU needs roughly **300 net new installs every day** by
month 6 — call it **35,000–50,000 installs** across the period.

**$600 buys about 2,000 installs at a $0.30 tier-3 CPI.** That is ~5% of what
the target needs. **So 95% of this plan has to be free installs.** Anyone
promising $10k out of a $100/month budget is selling something.

### What I actually expect

For a first casual title with $600 of spend, **$1,500–$4,000 in 6 months is a
good outcome**. $10,000 requires one of three breakouts:

1. **ASO breakout** — ranking top-10 for "color sort" / "water sort" in a few
   large-volume countries. Free, plausible, and the single best shot.
2. **A creative that beats the category CPI** — if one video hits ~$0.10 CPI in
   a cheap geo, $600 buys 6,000 installs instead of 2,000 and paid becomes
   worth scaling with revenue.
3. **Store featuring** — low odds, zero cost to be eligible; the checklist
   below keeps us eligible.

I am not going to quietly pretend the base case is $10k. I will run the plan
that maximises the odds and report real numbers monthly.

---

## 1. Do these before any spend (highest leverage, all free)

### 1.1 AdMob mediation — biggest single lever
Raises eCPM **30–80%** with no game changes. Going from $0.03 to $0.045
ARPDAU cuts the DAU needed by a third.

- [x] AdMob → Mediation → create groups for **banner / interstitial / rewarded**
      — done 1 Sep: Coloro-{Banner,Interstitial,Rewarded}-Android, Android only
- [ ] Add **AppLovin** — waterfall only (no AdMob bidding); blocked on the
      SDK key (Ahmed locked out of max.applovin.com, reset pending)
- [x] Add **Unity Ads** — done 1 Sep as a BIDDING source in all 3 groups
      (Game ID 6183792); adapter shipped in Android 1.0.8+8
- [ ] Add **Meta Audience Network** — *needs the Facebook app to exist first*
- [ ] Add **Liftoff/Vungle** + **ironSource** if setup time allows
- [ ] Enable **bidding** (not waterfall) wherever the network supports it
- [ ] Verify live fill on a real device for all three formats (after the
      1.0.8 rollout; Unity game IDs also take a day or two to warm up)
- [x] Record baseline eCPM per format **before** switching — recorded 1 Sep,
      table in `chat_history/2026-09-01-mediation-and-releases-session.md` §5
      (blended 161.92 EGP eCPM, banner match 40.98%)

### 1.2 Cross-promotion from the Megz portfolio — the only free install channel at scale
Ahmed owns **14 Play apps**. La3bangy alone: **6.74k active users, 11.3k
acquisitions/30d**. This costs nothing and starts immediately.

- [ ] List every portfolio app with live users and its monthly installs
- [ ] Add a **"More Games"/house-ad slot** promoting Coloro in the top 3–4 by MAU
- [x] Cheapest version: an AdMob **house campaign** (free inventory, no code)
      — **creatives done 29 Aug**: all nine AdMob image-ad sizes in
      `marketing/ads/`, generated from the real game art. Upload steps and
      the referrer-tagged destination URL are in `marketing/ads/README.md`.
      **Campaign LIVE 1 Sep**: `Coloro-House-CrossPromo`, Google-optimized
      backfill goal, all Android portfolio ad units (iOS apps excluded —
      the destination is the Play listing). 4/9 sizes uploaded (320x50,
      300x250, 320x480, 480x320); the other 5 are a 10-minute click-through.
- [ ] Better: a native cross-promo card on each game's menu/level-complete screen
- [ ] Track with a distinct UTM / referrer per source app
- [ ] Target: **500–1,500 installs/month** from this channel alone

### 1.3 ASO — the compounding free channel
Listing copy is written in `aso/listing_google_play.md` and
`aso/listing_app_store.md`.

- [ ] **After Play approval**, upload the regenerated art (`aso/screenshot_1..5.png`,
      `aso/feature_graphic.png`) — the live listing still shows the pre-1.0.6 look.
      *(Art regenerated 29 Aug against the new fixed palette and is on disk,
      ready to upload.)*
- [ ] Localise title + short description into **Arabic, Portuguese (BR), Spanish,
      Indonesian, Hindi, Turkish** — Play's biggest free reach lever
- [ ] Run a **store listing experiment** on the icon (A/B) once ~100 installs/day
- [ ] Run a second experiment on the short description
- [ ] Re-check keyword ranks monthly for: `color sort`, `water sort`, `pixel art`,
      `nonogram`, `ball sort`
- [ ] Ask for reviews in-app after a level-complete streak (see §4)

---

## 2. Google Ads — prep now, launch when live

**Gate: App campaigns can only target an app that is live on the store.**
Coloro is in review. Everything below marked *prep* can be done first.

### 2.1 Prep (doable before approval)
- [x] **Payment method confirmed present.** Ads account `806-993-4443`,
      currency **EGP**, with real spend already on it (E£49.28, 425 clicks,
      4 existing campaigns). Nothing had to be entered — and I never enter
      payment details regardless.
- [x] Link **Firebase ↔ Google Ads** — **done 1 Sep** via GA4 admin:
      property `coloro-e4a4b` (551039054) ↔ Ads `806-993-4443`, link shows
      "completed", personalized ads + auto-tagging on.
- [x] Mark `finish_level_5` as a **conversion** — **done 1 Sep**: key event
      in GA4, then imported into Ads as a **primary "Engagement"** conversion
      action (the value signal for §2.5's kill gates).
- [x] `first_open` — resolved 1 Sep: GA4's Android `first_open` is *not
      importable* by design; Google Ads tracks Android installs natively via
      Play and auto-creates the install conversion when the first App
      campaign is created. Nothing to do.
- [ ] Produce the missing creatives (§2.4) — *statics done 1 Sep; video is
      the open item*

### 2.2 Campaign structure (launch on approval)
| | Campaign 1 — Volume | Campaign 2 — Value |
|---|---|---|
| Type | App campaign (AC) | App campaign for engagement/actions |
| Conversion | `first_open` | **`finish_level_5`** |
| Bidding | Target CPI | Target CPA |
| Geo wave 1 | EG, SA, AE, MA, DZ, IQ, JO | same |
| Geo wave 2 | ID, PH, VN, BR, MX, TR | only if wave 1 clears CPI |

### 2.2a Decision, 29 Aug — still no launch, and the gate is now one item

Reviewed with 1.0.7 live. **Reason 1 below has cleared**: the build the ads
would sell is now the fixed one. Of the other two, only one is a real
blocker, and they should stop being quoted as a pair:

- **Video creative — blocking.** App campaigns spend most of a budget on
  video. Launching without it does not just underdeliver, it *contaminates
  the flight*: a bad CPI cannot be attributed to the geo, the bid, or the
  missing asset. At E£5,000/month there is exactly one flight per month, so
  a wasted flight costs a month, not $100. **This is the only thing holding
  the date.**
- **Mediation — NOT blocking, and it should stop gating this.** It changes
  revenue *per install*, not the flight's measurement, and it is waiting on
  Ahmed creating AppLovin and Unity accounts, which I will not create on
  anyone's behalf. If it is not done when the video is, **flight 1 launches
  anyway.**

#### Pre-flight checklist — all free, all before any spend
- [x] `finish_level_5` verified to fire in the shipped build
      (`AnalyticsService.gameWon`, every 5th level) — §2.5's kill criteria
      are therefore measurable
- [x] **Link Firebase to Google Ads** — done 1 Sep (see §2.1), and
      `finish_level_5` imported as a primary conversion the same day.
- [ ] Produce the 15s portrait video (script in §2.4)
- [ ] Confirm the Play listing shows the 1.0.7 art before sending traffic
      — *1.0.7 itself is approved and LIVE in production (confirmed 1 Sep,
      177 countries). Listing art replacement is scripted
      (`scripts/update_listing_art.sh`, Play API, service account) but the
      sandbox refused to exercise the credential — Ahmed runs it once:*
      `bash scripts/update_listing_art.sh`

### 2.2b Why no campaign was launched on 28 Aug

Permission to launch was given, and the gate is open. I did not launch, and
the reason is money rather than caution:

1. **1.0.7 replaces the build within hours.** It fixes the exact thing the
   ads would be selling — the unreadable near-identical colours. Buying
   installs onto 1.0.6 means paying to show people the defect.
2. **Mediation isn't configured** (§1.1). Every impression those installs
   generate would earn 30–80% less than it will next week. Acquiring users
   before mediation is the most expensive possible order to do it in.
3. **The creatives aren't finished** (§2.4). AC spends most of its budget on
   video, and there is no video yet — so the campaign would compete with one
   hand tied.

None of these takes more than a few days. Spending E£5,000 now buys worse
installs, monetised worse, against worse creative. **Launch after §1.1 and
§2.4 are done** — the checklist below is ready to execute as-is.

### 2.2c Session 1 Sep — flight built, parked one click from launch

Everything up to the ad-group assets is DONE and sitting in the account:

- **Video produced** — `marketing/ads/coloro_portrait_15s.mp4`, 15s 9:16
  1080x1920, rendered frame-by-frame from the REAL game by
  `test/promo_video_test.dart` (solver-driven playthrough of level 45, jam
  scene, dissolve, end card, on-brand captions). Uploaded to the Ads asset
  library, hosted unlisted on the Megz YouTube channel.
- **Statics produced + uploaded** — `ac_1200x628.png`, `ac_1200x1200.png`
  (same painters as the house ads; test `app campaign images`).
- **Campaign `Coloro-AC1-Install-Flight1` is PUBLISHED and PAUSED**
  (finished 1 Sep with Ahmed present; he completed Google's
  identity-verification dialog — the one step the automation never does).
  Campaign id 24202059293, account 806-993-4443. Final verified state:
  App campaign / installs / Android / com.megz.coloro; geos EG SA AE MA DZ
  IQ JO; languages Arabic + English; 5 headlines + 5 descriptions from the
  kit; **4 images + the 15s video** attached (ad strength "average" — a
  landscape video would raise it); budget **E£500/day**; bidding
  **maximize installs, no tCPI** (recorded deviation from §2.3's Target
  CPI: at E£500/day any workable tCPI violates the 50x-budget guidance and
  risks underdelivery); dates **1 → 13 Sep 2026**; spend at pause: E£0.00.
- **To launch: flip the campaign from Paused to Enabled** — nothing else.
  Gate unchanged: enable only after the listing art goes live
  (`bash scripts/update_listing_art.sh`). Ad review happens after enabling;
  first spend follows review.
- The optional "audience signal" suggestion was deliberately skipped —
  flight 1 measures the broad market; narrowing comes after data.

### 2.3 Budget shape — flights, not a trickle
**$100/month = $3.30/day will never leave the learning phase.** App campaigns
need ~100 conversions to learn; at $3/day that never arrives.

Run **concentrated flights** instead:
- [ ] Flight 1: **$10/day × 10 days**, Campaign 1 only, wave-1 geos
- [ ] Do not touch it for the full 10 days — editing resets learning
- [ ] Read: CPI, `finish_level_5`/install rate, D1 retention by geo
- [ ] Flight 2: repeat next month **only in the geos that cleared the gates**
- [ ] If nothing clears after two flights, **stop paid** and put everything
      into §1. That is a legitimate outcome, not a failure to fix by spending.

### 2.4 Creatives
Ready: `marketing/playable/coloro_playable.html`, `aso/screenshot_1..5.png`,
`aso/feature_graphic.png`, `aso/icon_512.png`.

- [x] Landscape image 1200×628 — `marketing/ads/ac_1200x628.png` (1 Sep,
      same painters as the house ads; test `app campaign images`)
- [x] Square image 1200×1200 — `marketing/ads/ac_1200x1200.png` (1 Sep)
- [ ] **Portrait video 9:16, 15s** — the slot AC spends most budget on
- [ ] Landscape video 16:9, 15s
- [ ] Upload the playable as an HTML5 asset

Video script (15s, screen capture): 0–2s tap a bottle → "Pick a bottle." ·
2–6s it drinks the picture → "It drinks the picture." · 6–9s red alarm ring →
"Pick wrong, it jams." · 9–12s board dissolves → "300 levels." · 12–15s icon +
"No timers. No lives. Plays offline." + Install.
**The tap and the drain must both be visible before 2s.**

### 2.5 Kill criteria — decided in advance, honoured
- CPI > $0.90 after a full flight → pause that geo
- `finish_level_5` < 15% of installs → the ad promises something the game
  isn't delivering; fix the creative, not the bid
- Cost per `finish_level_5` > $3.00 → that geo cannot reach the target

### 2.6 Flight 1 — read, and PAUSED 3 Sep

Two of the three gates failed on the first two days: CPI passed at **$0.30**,
but `finish_level_5` came in at 0% attributed / 8% all-time against a 15% bar,
and cost per `finish_level_5` at ~$4.25 against a $3.00 bar. Spend at pause:
**≈E£1,700 (~$34)** of a ≈E£6,500 flight.

The campaign was paused rather than run to 13 Sep, overriding §2.3's
hands-off rule. §2.2b is the precedent: it refused to launch on 1.0.6 because
*buying installs onto a build with a defect means paying to show people the
defect*. The onboarding wall was that defect. The 112-user cohort keeps ageing
for free, so nothing was lost by stopping.

**Restart gate for flight 2:** `finish_level_5` ≥ 15% of installs on organic
traffic, measured after 1.0.9 has been live long enough to have a cohort. Same
creative — a 9.2% CTR is not the problem. Nothing else about the campaign
changes; it is parked, not deleted.

---

## 3. Meta — app + events only, no ads
Ahmed's Meta **ads** account is banned. The app exists so attribution and event
history accumulate for the day that changes, and to unlock **Meta Audience
Network** in mediation (§1.1), which is worth real eCPM on its own.

- [ ] Create the Facebook app (steps: `marketing/docs/facebook-app-events.md`)
- [ ] Add `facebook_app_events`, **Android only** (iOS is SPM-only and has a
      recorded ATT rejection — see the doc)
- [ ] Wire App ID + Client Token, call `MetaEvents.instance.configure(...)`
- [ ] Verify in Events Manager → Test Events
- [ ] Enable Meta Audience Network in AdMob mediation

---

## 4. In-game work that moves revenue
Retention and ARPU are worth more than any ad spend at this budget.

**This section stopped being optional on 3 Sep.** Flight 1 proved acquisition
works ($0.30 CPI) and that the game cannot keep or monetise what it buys —
8% of installs reached level 5, 8% ever saw an ad, ARPDAU $0.002 against the
$0.03 this plan models. Full read: `FLIGHT1_READ_2026-09-03.md`.

- [ ] **In-app review prompt** after a 3-level win streak (ratings drive ASO rank)
- [x] **Rewarded "skip this level"** after 3 losses on the same level — new
      rewarded surface at peak intent. **Shipped in 1.0.9 (3 Sep).** Grants the
      skip even when no ad is in inventory: a player refused after three
      defeats churns, and a churned player earns nothing. Recorded as skipped,
      not completed. New `level_skipped` event carries the loss count so the
      threshold of 3 can be tuned against real data.
- [x] **Ads from level 1** — **shipped in 1.0.9 (3 Sep).** `adsFromLevel`
      4 → 1 (banner) and interstitials 4 → 2. The old gate meant 92% of paid
      installs never saw an ad; it was protecting an onboarding stretch that
      players do not survive.
- [ ] **Daily reward** rewarded video on the menu — +1 guaranteed rewarded view/DAU
- [ ] **"More games" button** on the menu → portfolio cross-promo (see §1.2)
- [ ] Interstitial on every level exit *(shipped)*
- [ ] Rewarded promoted to primary on the fail card *(shipped)*
- [ ] Faster levels → more interstitials/session *(shipped)*

---

## 5. Measurement — the monthly loop
- [ ] Firebase: D1 / D7 / D30 retention, session length, levels per session
- [ ] AdMob: eCPM and impressions per DAU, by format and country
- [ ] Play Console: installs, store-listing conversion rate, keyword ranks
- [ ] Compute **ARPDAU** and **install→D7 curve** monthly
- [ ] Re-forecast §0 against real numbers and report honestly, including when
      the trajectory misses

**Month-1 decision gate:** if D1 retention is below ~30%, retention is the
problem and **no amount of acquisition fixes it** — stop all spend and work
§4 until it moves.

---

## 6. Order of operations
1. Ship the current build and get approved
2. **AdMob mediation** (§1.1) — before any spend
3. **Cross-promo** (§1.2) — free installs start immediately
4. **ASO art + localisation** (§1.3)
5. Facebook app → Meta Audience Network (§3)
6. Google Ads prep (§2.1)
7. On approval: **Flight 1** (§2.3)
8. Read, decide, repeat monthly (§5)

Paid advertising is step **7**, not step 1. At this budget it is a measuring
instrument, not an engine.
