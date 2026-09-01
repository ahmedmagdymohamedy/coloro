# Session record — Play rejected 1.0.8 on the Data safety form; fixed and re-sent

**When:** 1 Sep 2026, evening.
**Previous session:** `chat_history/2026-09-01-mediation-and-releases-session.md`
(it shipped the 1.0.8 mediation build this rejection landed on).

---

## 1. The rejection

Google Play email, app status **Rejected**, version code **8**:

> Issue found: Invalid Data safety form … We detected user data transmitted
> off devices that you have not disclosed … Device Or Other IDs … Possible
> SDKs: com.applovin:applovin-sdk

The 1.0.8 release was rolled back to an *unsent change*; production stayed on
1.0.7, so no users were affected.

## 2. Root cause — bigger than the email implies

The email blames the AppLovin adapter, but the real state of the form was:

**Question 1 — "Does your app collect or share any of the required user data
types?" — was answered "No".** The entire declaration was empty, and had been
since launch. That was already inaccurate for 1.0.7 (AdMob transmits the
advertising ID; Firebase Analytics an app-instance ID); the AppLovin SDK in
1.0.8 is just what pushed Google's traffic scanner over the line.

So this was never an AppLovin problem, and removing that adapter would not
have fixed it — it would have shipped another build with the same wrong form.
`aso/listing_google_play.md` had specified the correct declaration back in
August ("Device or other IDs collected, linked to advertising and
analytics"); it was simply never entered.

## 3. Fix — console only, no rebuild

No code change, no version bump: code 8 as already uploaded is the build
under review. The form was filled from each SDK's own published Play
disclosure rather than from memory:

- Google Mobile Ads — https://developers.google.com/admob/android/privacy/play-data-disclosure
- Unity Ads — https://docs.unity.com/en-us/grow/ads/privacy/google-data-safety
- Firebase — https://firebase.google.com/docs/android/play-data-disclosure

The union of those (plus Meta App Events, which is in the build via
`facebook_app_events`) gives four data types. Every one is **collected AND
shared** — Unity and AppLovin use the data for their own ad serving, which is
"sharing" under Play's definition, and under-declaring the *shared* half is
the most likely way to be rejected a second time.

| Category | Type | Collected | Shared | Purposes |
|---|---|---|---|---|
| Location | Approximate location | ✓ | ✓ | Advertising, Analytics, Fraud prevention |
| App activity | App interactions | ✓ | ✓ | Advertising, Analytics, Fraud prevention |
| App info and performance | Diagnostics | ✓ | ✓ | + App functionality |
| Device or other IDs | Device or other IDs | ✓ | ✓ | + App functionality |

Uniform answers on every type: **not** processed ephemerally; collection
**required** (there is no in-app opt-out). Section 2 answers: data encrypted
in transit **yes**; app does not allow account creation; no sign-in with
accounts created outside the app; no data-deletion request mechanism.

Deliberately **not** declared, though they appear in Unity's table:
*Purchase history* (Coloro has no IAP and reports none) and *Personal info →
User IDs* (no accounts, no user identifier of any kind — the installation
identifiers are already covered by Device or other IDs).

## 4. Re-submitted

Publishing overview → **"Send 2 changes for review"**:

1. Production · 1.0.8 · start full rollout
2. App content · Data safety · complete the questionnaire

Console confirmed *"2 changes sent for review"* and the page flipped from
"some changes were rejected" to **"changes under review"**. Reviews take up
to 7 days. The policy-status issue page states Google auto-resolves the issue
if the submitted changes contain the fix, so no appeal was filed — the
finding was factually correct.

## 5. The remaining gap — hosted privacy policy (Ahmed's task)

Play policy requires the Data safety section and the privacy policy to agree.
Play points at **https://sites.google.com/view/ammegz**, which is a *generic
Megz-wide* policy: it names AdMob, Flurry, Google Analytics and Facebook
Login, and **never mentions advertising IDs or device identifiers** — nor
Unity Ads or AppLovin.

`aso/privacy_policy.md` (the Coloro-specific one, in this repo) was rewritten
this session to match the new declaration exactly — it now names Unity Ads,
AppLovin and Meta App Events and spells out the identifier + IP-derived
approximate location collection. **It has never been hosted.** Ahmed needs to
paste it into that Google Site, or host it elsewhere and swap the URL in Play
Console + App Store Connect. Editing Google Sites through browser automation
was deliberately not attempted.

If the re-review fails, this is the first thing to check — not the form.

## 6. 1.0.8 was never on internal testing — added afterwards

Ahmed asked why he could not test code 8. Internal testing was still on
**1.0.7 (29 Aug)**: the 1.0.8 deploy last session ran
`./scripts/deploy_mobile_version.sh --android-only --skip-build --track production`,
and `--track production` assigns the uploaded bundle to production *only* —
the script's `TRACK` is a single destination, not a promotion chain, so
internal was skipped entirely. (Its default is `TRACK="internal"`; the flag
overrode it.)

Fixed without a rebuild: internal testing → Create release → **Add from
library** → code 8 → publish. Same bundle as the one in production review, so
what he tests is exactly what Google is reviewing. Release named "8 (1.0.8)",
notes added, published immediately (internal releases do not wait for the
production review). Sole warning: the known APK-size advisory.

Opt-in link for testers: `https://play.google.com/apps/internaltest/4701727256833733267`
(list "My friends", 16 testers, enabled).

**Rule:** ship to internal, test, then promote. `--track production` on an
untested build leaves nothing to test.

## 7. Notes for the next browser session

- Play Console renders in **Arabic/RTL** for this account. Step tabs in the
  Data safety wizard are not clickable; you must walk 1→5 with "التالي".
- Screenshot/viewport scaling settles to 1:1 (1280×547) after the first
  interaction, but the *first* screenshot of a fresh page comes back 1568×739.
  Take a throwaway screenshot before trusting coordinates, or use find/ref.
- Useful URLs (direct navigation works for these slugs, `app-content` and
  `publishing-overview` do **not** — they bounce to the app list):
  - `…/app/4973484828510117385/publishing`
  - `…/app/4973484828510117385/app-content/overview`
  - `…/app/4973484828510117385/app-content/data-privacy-security`
- The form has **export/import to CSV** — a faster path than clicking through
  the wizard next time, if a file download is acceptable.
