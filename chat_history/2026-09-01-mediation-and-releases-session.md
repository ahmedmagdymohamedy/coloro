# Session record — listing live, both stores resubmitted, Unity mediation shipped

**When:** 1 Sep 2026, afternoon→evening, interactive with Ahmed.
**Previous session:** `chat_history/2026-09-01-preflight-and-campaign-session.md`
(its §5b records the first half of this day).

---

## 1. Play listing art — fixed and live

The overnight session's blocked item 1 closed. First run of
`scripts/update_listing_art.sh` failed at commit with HTTP 403: the service
account had only *Release to testing tracks* + *View app info* (the deploy
setup in `scripts/README.md`), which can stage images inside an edit but not
commit a store-listing change. **Fix: Ahmed granted "Manage store presence"**
in Play Console → Users and permissions; the re-run committed cleanly.
Google's listing review cleared the same afternoon — verified against a
pre-commit snapshot of the live screenshot URLs, plus a pixel check of the
downloaded art. The script's dead `changesNotSentForReview` retry was
removed; a 403 now prints the fix.

## 2. Google Ads flight ENABLED

With the live listing showing 1.0.7 art (the recorded gate), campaign
**Coloro-AC1-Install-Flight1** (id 24202059293) was set to Enabled via the
campaigns table. Status after save: مؤهل (قيد التعلم) — eligible, learning.
Account daily total went 50 → 550 EGP/day. **Nobody touches the campaign
until it completes 13 Sep**; then read against `MARKETING_PLAN.md` §2.5 kill
criteria. Google's "+8.4% budget" suggestion in the campaigns table was
deliberately NOT applied and should stay unapplied.

## 3. Git — the tree is finally committed

- `39cc662` — **1.0.7 as shipped** (60 files; full sweep 303/303 re-proved
  first). The palette fix + repaired levels.json exist as one commit.
- `29f95a1` — **1.0.8 mediation adapters** (see §5).
- Both pushed to origin/main. HANDOFF's "only copy of the source" hazard is
  closed.

## 4. iOS — queued build swapped

ASC had **"1.0.5 Waiting for Review"** carrying build 6 (old palette),
sitting since 28 Aug. Removed it from review, changed the version record to
**1.0.7**, attached **build 7** (TestFlight, fixed palette), submitted —
"1 Item Submitted", now Waiting for Review (~48h per Apple). Screenshots on
the iOS listing were already the new art (28 Aug ASO push). Release is set
to automatic on approval. **iOS deliberately has NO mediation** — not live
on the App Store yet, prior tracking-signal rejection on record, SPM-only
build; iOS mediation is its own future release with a real ATT flow.

## 5. Monetization — Unity Ads mediation SHIPPED (the revenue lever)

### Baseline (recorded BEFORE any mediation, last 7 days, AdMob Network, EGP)

| Format | Earnings | Observed eCPM | Requests | Match rate |
|---|---|---|---|---|
| Interstitial | 22.19 | 264.16 | 137 | 100% |
| Rewarded | 3.63 | 453.48 | 51 | 100% |
| Banner | 0.90 | 12.33 | 183 | **40.98%** |
| Blended | 26.72 | 161.92 | 371 | 70.89% |

Banner's 59% unfilled inventory is mediation's first win. Compare ~8 Sep.

### Unity side (cloud.unity.com, org 11270006112895)

New project **Coloro** (7ce026b1-7c1c-4d4d-ab97-4c9fbc2a222a), mediation
partner = Google AdMob, bound to the live Play listing. **Game ID Android
6183792** (iOS 6183793, unused). Bidding placements auto-created:
Banner_Android / Interstitial_Android / Rewarded_Android (+ iOS twins).
A Monetization Stats API key was generated (retrievable in the Unity
dashboard; not committed here). **Payout profile NOT set up — Ahmed's task;
Unity's earnings accumulate but cannot pay out until then.**

### AdMob side (admob.google.com — NOT apps.admob.com, that's the dead host)

Three mediation groups, all Android, all with **Unity Ads as a BIDDING
source** mapped (Game ID 6183792 + the matching placement):

| Group | id | Coloro ad unit |
|---|---|---|
| Coloro-Banner-Android | 6191461226 | ca-app-pub-3208735875691916/8934478391 |
| Coloro-Interstitial-Android | 9059841517 | …/5307214257 |
| Coloro-Rewarded-Android | 3373720499 | …/2681050910 |

**Finding: AppLovin does not offer bidding on AdMob** (checked the full
38-network bidding list) — it must be added as a *waterfall* source, which
needs the AppLovin **SDK key** both in the AdMob mapping and in
`AndroidManifest.xml` (`applovin.sdk.key`).

### Code (commit `29f95a1`)

Plain Gradle deps in `android/app/build.gradle.kts` — deliberately NOT the
gma_mediation_* Flutter packages, so iOS is never touched:
`com.unity3d.ads:unity-ads:4.20.0` (the adapter does not pull the SDK
transitively — R8 fails without it), `com.google.ads.mediation:unity:4.20.0.1`,
`com.google.ads.mediation:applovin:13.6.4.0` (inert until the SDK key
lands). Three `-dontwarn com.amazon.privacypass.*` rules in
`proguard-rules.pro` (AppLovin's OMID references them compile-only).
AAB 64.4MB (Unity SDK ≈ +8MB). 71/71 tests pass.

### Shipped

**1.0.8+8 uploaded straight to the Play production track** via
`./scripts/deploy_mobile_version.sh --android-only --skip-build --track
production` — committed, in Google's update review. Unity revenue appears in
**Unity's dashboard** (Unity pays separately); AdMob-won impressions stay on
AdMob as before.

## 6. House campaign (free installs) — running, 4/9 ads

AdMob campaign **Coloro-House-CrossPromo**: house type, **Google-optimized
backfill** goal (serves only inventory that would go unfilled — zero
displaced revenue), targeting ALL Android portfolio apps' ad units (Black
Point, Crazy Bird 3D, المتاهة, La3bangy Android, Puzzle Board, The Ghost
Way, Deadly Crypt; **iOS apps deliberately excluded** — destination is the
Play listing). Ads created with the referrer-tagged URL from
`marketing/ads/README.md`: Coloro_320x50, _300x250, _320x480, _480x320 (the
four priority sizes). **Remaining 5 sizes** (320x100, 728x90, 468x60,
768x1024.jpg, 1024x768.jpg) deprioritized by Ahmed — add via AdMob →
الحملات → Coloro-House-CrossPromo → create ad, one per size, same URL.

## 7. Blocked on Ahmed (in value order)

1. **AppLovin SDK key** — he was locked out of max.applovin.com (too many
   attempts warning); password reset pending. When he has it: dash/max
   AppLovin → Account → Keys → SDK Key. Then: add
   `applovin.sdk.key` meta-data to AndroidManifest, add AppLovin as
   waterfall source in the three mediation groups, ship in next version.
2. **Unity payout profile** — cloud.unity.com prompts for it.
3. **Revoke the three unknown "Windows" browsers** in the Claude Chrome
   extension settings (he's Mac-only; keep "Ahmed Magdy Personal Mac").

## 8. Browser-automation notes for the next session

- The Claude extension keeps its **own site allowlist** — Chrome-level "On
  all sites" is NOT enough. `dash.applovin.com` was still blocked at
  session end; `admob.google.com`, `ads.google.com`, `ads.applovin.com`,
  `cloud.unity.com`, `appstoreconnect.apple.com`, `play.google.com` work.
- AdMob lives at **admob.google.com** (apps.admob.com never unblocks —
  wrong host).
- The Mac pairing drops when Chrome restarts; re-pair with switch_browser —
  the browser is named **"Ahmed Magdy Personal Mac"**.
- AdMob/Play UIs re-render menus late; when a screenshot comes back
  1568px wide (vs 1422), coordinate clicks land ~(-84,-30) off — re-shoot
  and use fresh coordinates, or use find/ref clicks.

## 9. What "done" looks like next check-in (~8 Sep)

- Play Console: 1.0.8 approved and rolling out; crash rate steady (watch
  the armeabi_v7a SIGABRT from the overnight session's note).
- AdMob mediation report: Unity Ads serving; banner match rate ≫ 41%.
- Unity dashboard: impressions + revenue accruing.
- Google Ads: flight spending; read §2.5 kill criteria per geo on 13 Sep.
- Apple: 1.0.7 approved → App Store live; then plan iOS mediation + ATT.
