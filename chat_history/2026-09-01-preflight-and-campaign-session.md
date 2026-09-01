# Session record — pre-flight closed, video produced, campaign built

**When:** 1 Sep 2026, overnight, autonomous.
**Previous session:** `chat_history/2026-08-28-palette-and-ads-session.md`.
Plan lives in `marketing/MARKETING_PLAN.md` (§2.2c has this session's
campaign state).

Ahmed's instruction: free users first, but start a small Android install
campaign within budget so analytics start flowing; full marketing authority
delegated.

---

## 1. Status found on arrival

- **1.0.7 (code 7) is LIVE in production** — 177 countries. The review gate
  is fully open.
- **Play Console still shows 0 installs**, but GA4 shows **21 active / 18
  new users in the last 7 days** — a real organic trickle exists (install
  stats lag and count differently).
- **One production crash**: SIGABRT `std::__fl::__libcpp_verbose_abort` in
  libflutter.so, armeabi_v7a split APK, 1 user / 1 event, on both internal
  and production tracks — plausibly a single old 32-bit device. Not a
  blocker at n=1; **watch it once paid traffic starts** (tier-3 geos are
  32-bit-heavy).

## 2. Measurement gates — closed (both were open since 28 Aug)

1. **GA4 ↔ Google Ads linked** — property `coloro-e4a4b` (551039054) ↔
   account 806-993-4443, link shows *completed*, personalized ads +
   auto-tagging on. Done via GA admin (equivalent to the Firebase-side
   link).
2. **`finish_level_5`** marked as a GA4 **key event**, then imported into
   Google Ads as a **primary "Engagement" conversion action**. The §2.5
   kill gates are now evaluable per campaign/geo.
3. `first_open` resolved: Android installs are tracked natively via Play —
   GA4's android `first_open` is not importable by design; the install
   conversion appears automatically with the first App campaign. No action.

## 3. The video — produced without an emulator

The plan's single launch blocker was the 15s portrait video. The Mac had
6.3GB free disk — the emulator route (4-5GB) was abandoned after the system
image download hit "No space left on device". Replacement:
**`test/promo_video_test.dart`** renders the video from the REAL game in a
widget test, zero device needed:

- Drives `GameScreen` at 1080x1920 exactly like the ASO generator, captures
  `RepaintBoundary` frames at 30fps of pumped game time.
- **Plays level 45 with the real solver**: new public
  `BottleFactory.solveDealOrder(grid, deal)` (additive, gameplay never
  calls it) returns the backtracking solver's proven dock order; the test
  replays it — that is what makes a full on-camera playthrough possible.
  Naive policies lose or stall (tried: greedy-takable → starved at 62%,
  keep-slot-free greedy → stalled at 56%, deal-order heuristic → 28%).
- Jam scene: feed the machine in reverse tray order → all four bottles
  starve with red "!" — the honest "pick wrong, it jams" shot.
- Scenes: fresh board + first bottle (2s) → drain at 1.5x (4s) → jam (2.8s)
  → dissolve at 3x through the win card (4.8s) → end card (2.2s ≈ 14.9s).
- Captions are painter-rendered PNG pills (Fredoka) overlaid by ffmpeg —
  the Homebrew ffmpeg 9 build has no drawtext.
- Output: `marketing/ads/coloro_portrait_15s.mp4` (5.3MB, H.264, silent).
  Also new: `ac_1200x628.png`, `ac_1200x1200.png`,
  `video_endcard_1080x1920.png` (test `app campaign images`).

`flutter analyze lib/ test/ tool/` clean; `flutter test` 71/71.

## 4. Google Ads — campaign built, deliberately unpublished

Everything uploaded via the Asset Library (it keeps real `<input
type=file>` elements in the DOM, unlike Play Console): the video (YouTube:
Megz channel, **unlisted**, Google's recommended option) and both statics.

Campaign **`Coloro-AC1-Install-Flight1`** (id 24202059293): App campaign /
installs / Android / Coloro; **EG SA AE MA DZ IQ JO**; **Arabic +
English**; 5 headlines + 5 descriptions from
`marketing/campaigns/google-ads-kit.md` §3; **4 images + the 15s video**;
**E£500/day**; **maximize installs, no tCPI** (recorded deviation from
§2.3, the 50x rule makes any workable tCPI infeasible at this budget);
dates **1 → 13 Sep**. The session initially died at the browser handoff
with the wizard unsaved; when Ahmed returned, the wizard tab had survived
intact — he completed Google's **identity-verification dialog** (the one
step the automation never does), after which the campaign was **published
and immediately paused** (E£0.00 spent). Google's own benchmark shown in
the wizard: typical CPI for similar apps in these geos ≈ **E£4.68**
(~$0.10) — far below the plan's $0.30 assumption; if that holds, E£5,000
buys ~1,000 installs, not ~330.

**Decided and recorded: the flight ENABLES only after the Play listing
shows the 1.0.7 art.** The listing is the campaign's landing page; sending
paid traffic to screenshots of the broken palette is the exact mistake the
28-Aug decision existed to prevent.

## 5. Blocked items (all need Ahmed)

1. **Listing art upload** — the sandbox classifier refused to let the
   session exercise the Play service-account credential (twice; not worked
   around). Everything is scripted: **`bash
   scripts/update_listing_art.sh`** replaces the feature graphic + 5
   screenshots via the Publishing API in ~1 minute.
2. **Browser handoff mid-session** — the Mac Chrome extension dropped and
   the account then listed **three unrecognized "Windows" browsers**; the
   protocol requires the user to pick, so no browser action was possible
   after that. Ahmed should check chrome extension installs he owns and
   reconnect the Mac one. (If those Windows machines aren't his: revoke.)
3. **AdMob house campaign** — `apps.admob.com` is not enabled for the
   Chrome extension, so the free cross-promo channel (the actual "free
   users first") is still not set up. Either grant the domain in the
   extension settings or click through `marketing/ads/README.md` (15 min).
4. **Facebook app password** + **AppLovin/Unity accounts for mediation** —
   unchanged from last session; both still worth real money.

## 5b. Afternoon follow-up (1 Sep) — listing live, campaign ENABLED

Blocked item 1 is closed, and the flight is on:

1. **First run of `update_listing_art.sh` failed at commit** — HTTP 403. The
   service account had only *Release to testing tracks* + *View app info*
   (the deploy setup in `scripts/README.md`), which stages images inside an
   edit but cannot commit a store-listing change. Ahmed granted **Manage
   store presence** in Play Console → Users and permissions; the re-run
   committed cleanly (edit `06680933214746778294`). The script's dead
   `changesNotSentForReview` retry was removed and a 403 now prints the fix.
2. **Listing review cleared same day** — a watcher compared the live store
   page's screenshot URLs against a pre-commit snapshot; all five flipped to
   new content hashes, and a downloaded frame confirmed the 1.0.7 art
   (new wordmark, fixed palette).
3. **`Coloro-AC1-Install-Flight1` set to Enabled** (via the campaigns table
   status menu). Status after saving: **مؤهل (قيد التعلم)** — eligible, bid
   strategy learning; ads now in Google's ad review. Account daily total
   went 50 → 550 EGP/day. The gate held: no paid click can land on the old
   art.

**Flight discipline from here: nobody touches the campaign until it
completes on 13 Sep** (edits reset learning). Then read results against the
§2.5 kill criteria per campaign/geo. The budget-raise suggestion Google
shows in the campaigns table ("تحسين ميزانياتك +8.4%") was deliberately NOT
applied and should stay unapplied.

Still open: AdMob house campaign, Facebook app password, AppLovin/Unity
mediation accounts, committing the working tree (`lib/` + `levels.json`
together, per HANDOFF), and checking the **three unrecognized "Windows"
browsers** on the extension account — the Mac connection itself is working
again (this follow-up used it), but revoking those, if they aren't Ahmed's,
was never confirmed.

## 6. New tools this session

| Tool | What it does |
|---|---|
| `test/promo_video_test.dart` | Renders promo-video frames from the real game (PROMO_OUT=dir), solver-driven playthrough |
| `BottleFactory.solveDealOrder` | Public accessor for the solver's proven dock order (used only by the video generator) |
| `scripts/update_listing_art.sh` | Replaces Play listing feature graphic + screenshots via the Publishing API |
| `marketing/playable/coloro_playable.zip` | AC-spec packaging of the playable (index.html, ExitApi already wired) |
