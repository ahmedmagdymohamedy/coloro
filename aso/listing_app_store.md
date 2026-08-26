# App Store listing — Coloro

Copy each block straight into App Store Connect. Character counts are
checked against Apple's limits. Where the App Store differs from Play, the
reason is spelled out — the two stores rank on very different signals.

**What Apple actually indexes for search:** app name, subtitle, and the
keywords field. **Not** the description, and **not** the promotional text.
So the name/subtitle/keywords trio has to carry every term you want to rank
for, without repeating a single word between them — Apple counts a term
once no matter how many fields it appears in.

---

## App name  (limit 30)

```
Coloro: Pixel Color Sort
```
*24 chars.* Same text as Play. Brand first, then the two terms this game can
honestly rank for: **pixel** and **color sort**. Apple truncates around 20
characters in search results, so `Coloro: Pixel Colo…` is what most people
see — the brand and the strongest keyword both survive the cut.

**Alternates if the name is taken:**
- `Coloro - Color Sort Puzzle` (26)
- `Coloro: Pixel Art Sort` (22)

---

## Subtitle  (limit 30)  — *iOS only, no Play equivalent*

```
Relaxing offline bottle puzzle
```
*30 chars, exactly at the limit.* The subtitle is the second-strongest
ranking field Apple has, and it renders under the name everywhere the app
appears. Every word here is a search term the name does **not** already
contain: `relaxing`, `offline`, `bottle`, `puzzle`. It also reads as a real
description of the game rather than a keyword dump, which matters because
this line is on the product page.

**Alternates:**
- `Drain the pixel art puzzle` (26) — better read, weaker keyword yield
  (`pixel` and `art` are already covered by the name)
- `Sort bottles, drain the art` (27)
- `Bottle puzzle, brain teaser` (27)

---

## Promotional text  (limit 170)  — *iOS only, no Play equivalent*

```
300 hand-made pixel pictures, every one solver-verified. No timers, no lives, no internet. Just you, the board, and the bottles that drink it away. Start with level 1.
```
*167 chars.*

**Why this field is special:** it sits above the description on the product
page, and it is the **only** listing text you can change without shipping a
new build and going through review. It is **not indexed for search**, so
don't waste it on keywords — spend it on whatever is true *this week*.

Change it whenever you have news; swap in one of these:

| Situation | Text | Chars |
|---|---|---|
| New content ships | `NEW: 300 levels, all verified solvable. No timers, no lives, no wifi needed — pick a bottle and watch the picture drain away.` | 125 |
| Countering "too hard" reviews | `Stuck on a level? There is always a line that wins — every board here was proved solvable before it shipped. No timers. No lives. No internet needed.` | 149 |
| Seasonal / calm-app angle | `Ten minutes, one picture, zero pressure. 300 offline levels with no timers and no lives — drain the pixel art at exactly your own pace.` | 135 |

---

## Keywords  (limit 100)  — *iOS only, no Play equivalent*

```
water,ball,brain,logic,art,match,drain,calm,mind,teaser,paint,tile,zen,wifi,pour,coloring,nonogram
```
*98 chars.*

Rules this list follows:

- **Comma-separated, no spaces after commas.** A space costs a character and
  buys nothing.
- **No word that already appears in the name or subtitle.** `color`, `sort`,
  `pixel`, `puzzle`, `bottle`, `offline`, `relaxing` are all deliberately
  absent — they are already indexed, and repeating them wastes the field.
  (This is why the draft in the old README is wrong: it spent ~30 of its 100
  characters re-declaring words the title already covers.)
- **Singular only.** Apple matches plurals automatically.
- **No "app", "game", "free", or your own brand name.** Apple adds category
  terms itself, and brand terms are indexed from the name.

Apple builds multi-word queries by combining terms across fields, so this
list plus the name/subtitle produces phrases you actually get searched for:
`water sort`, `ball sort`, `color match`, `pixel art`, `brain teaser`,
`logic puzzle`, `coloring puzzle`, `relaxing offline game`.

---

## Description  (limit 4000)

Apple does **not** index this text, so it is written purely to convert.
Only the first ~3 lines show before the "more" tap — everything that has to
land, lands there.

```
Pick a bottle. Watch it drink the picture away, one pixel at a time.

Coloro is a color-sorting puzzle with a twist you can feel: every level is a
tiny pixel-art picture, and your bottles drain it from the bottom edge up.
Choose well and the artwork dissolves in one satisfying cascade. Choose
badly and the machine jams.

A PUZZLE YOU CAN SEE
Every level is a hand-tuned pixel picture - moons, hearts, rockets, cats,
crowns, rainbows. The board starts in full color and disappears as you play,
so you always know exactly how close you are.

SIMPLE TO PLAY, HARD TO MASTER
- Tap a bottle to dock it in one of 4 slots
- Docked bottles drink matching pixels off the bottom edge
- A bottle whose color is buried starves, and holds its slot hostage
- Fill all 4 slots with starving bottles and the machine jams

That's the whole game. No timers, no lives, no energy meter. Just you, the
picture, and the order you choose.

REAL DECISIONS, NOT LUCK
The bottle you need is never conveniently on top. Read the picture, work out
which colors are about to surface, and park the ones you can't use yet. Every
single level was verified solvable by a solver that plays under the same
rules you do. If you lose, there was a better line.

300 LEVELS THAT ACTUALLY GET HARDER
Four normal levels, then a hard one, all the way to 300. Pictures grow from
15x15 to 40x40, palettes from 5 colors to 10, and the colors interleave more
tightly the deeper you go. Level 250 is nothing like level 5.

PLAYS ANYWHERE
100% offline. No account, no login, no waiting. Open it on a plane, in a
queue, or in bed with one hand.

REPLAY ANYTHING
Swipe the level carousel to revisit any picture you have finished and drain
it again.

Coloro is free, and ads are what keep it that way. The first three levels
have no ads at all, so you can find out whether you like it before you see a
single one.

Coloro is for anyone who likes color sort games, pixel art, nonograms,
water sort puzzles, or the very specific pleasure of watching something
neatly disassemble itself.

Download Coloro and start draining.
```

> ⚠️ **No emoji.** App Store Connect rejects the description with *"This
> field contains one or more invalid characters"* if it contains emoji —
> confirmed on this app's own submission. Play accepts them; Apple does not.
> The block above is the emoji-free version that Connect accepted. Em dashes
> and `×` were also replaced with plain ASCII to be safe.

*2,071 chars of 4,000.* Identical in substance to the Play description — the two
stores should tell the same story — with one addition Apple's audience
rewards: the ads are stated up front, and so is the three-level ad-free
runway. Ad complaints are the single most common 1-star driver for a free
puzzle game; saying it first defuses most of them.

---

## What's New  (limit 4000)

For the **first** release:

```
Coloro's first release.

300 hand-made pixel-art levels, four normal then one hard, all the way up.
Every one verified solvable before it shipped.

No timers, no lives, no account, and no internet needed.

Found a level that feels unfair? Tell us at heba@paradigmsys.info — we can
re-tune it and ship the fix.
```

For later releases, keep the shape: what changed, then the support address.
Apple shows this on the product page and in the Updates tab, so "bug fixes
and improvements" is a wasted slot.

---

## Screenshots

**What Apple requires now.** Since April 2025, App Store Connect asks for
only the **largest display in each device family** and scales it down to
cover every older device. So the 6.5", 5.5" and 12.9" sets the old README
mentioned are no longer needed — do not produce them.

| Slot | File | Size | Required? |
|---|---|---|---|
| iPhone 6.9" | `ios_iphone_69_1..5.png` | **1320 × 2868** | ✅ required (app runs on iPhone) |
| iPad 13" | `ios_ipad_13_1..5.png` | **2064 × 2752** | ✅ required *while* `TARGETED_DEVICE_FAMILY = "1,2"` — see the decision below |

Confirmed in Connect's Media Manager: the **6.9" slot is labelled "for
iPhone 6.5", 6.7" or 6.9" Displays"** and covers all three, so the separate
6.5" slot below it can stay empty. Two gotchas that cost time on the first
upload:

- **Upload one file at a time.** Selecting all five at once uploads them in
  a scrambled order, and slots 1–3 are the only ones most people see.
- The collapsed 6.5" panel has its own file input directly beneath the 6.9"
  one. Expand 6.9" first and confirm the drop zone lists `1320 × 2868px`,
  or the files land in the 6.5" slot and get rejected on dimensions.

Both sets are generated from the real game:

```sh
ASO_OUT=aso flutter test test/aso_generator_test.dart
```

Apple accepts 1–10 per display class, PNG or JPEG, RGB, no alpha, and the
dimensions must match **pixel for pixel** — a 1290 × 2796 file will be
rejected from a 1320 × 2868 slot. Order matters: the first three are what
99% of people ever see.

**Screenshot order (same story as Play, deliberately):**

1. **Promo hero** — a designed panel, not an app capture: wordmark, tagline,
   half-drained board, bottle row, promise badges
2. **Drain it colour by colour** — the loop, a full colourful board
3. **Pick the right bottle** — the tension, jam warning visible
4. **Watch the picture vanish** — the payoff
5. **Replay any level** — depth/retention

---

## App preview video  (optional)

Not produced, and not required. If you add one later:

| Family | Resolution | Rules |
|---|---|---|
| iPhone 6.9" | 886 × 1920 portrait | 15–30 s, ≤ 500 MB, ≤ 30 fps, H.264 `.mov/.m4v/.mp4` or ProRes 422 HQ |
| iPad 13" | 1200 × 1600 portrait | same |

Up to 3 per localization, and Apple requires the footage to be **captured
from the app itself** — a motion-graphics ad gets rejected. The poster frame
is picked from the video, so plan a frame with a full colourful board.

---

## App icon

Nothing to upload separately. App Store Connect pulls the 1024 × 1024
marketing icon out of the build's asset catalog:

`ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`

Verified: **1024 × 1024, RGB, no alpha channel** — Apple rejects icons with
an alpha channel, and `remove_alpha_ios: true` in `pubspec.yaml` is what
strips it. `aso/icon.png` is the RGBA source; it is never uploaded, so its
alpha channel is fine.

---

## Categorisation

- **Primary category:** Games
- **Game subcategories:** Puzzle, Casual *(Apple allows two)*
- **Secondary category:** Entertainment — optional, and worth far less than
  the primary. Leave it blank rather than picking something irrelevant.
- **Price:** Free, no in-app purchases
- **Availability:** all territories

---

## Age rating

Expect **4+**. Answer the questionnaire honestly:

| Question | Answer |
|---|---|
| Violence (cartoon / realistic / prolonged graphic) | None |
| Sexual content, nudity, profanity, crude humour | None |
| Horror/fear themes, alcohol, tobacco, drugs, gambling | None |
| Contests, user-generated content, chat, sharing | None |
| Unrestricted web access | No |
| **In-app advertising** | **Yes** — banner, interstitial and rewarded |
| Made for Kids category | **No** |

Do **not** opt into the Kids Category. It forbids third-party analytics and
behavioural ads outright, which would mean pulling both AdMob and Firebase
Analytics.

---

## App Privacy ("nutrition label")

Answer this in Connect → App Privacy. It must match `privacy_policy.md` —
Apple compares them, and a mismatch is a rejection.

**Do you collect data from this app?** → **Yes** (the SDKs do; that counts
as you collecting it).

| Data type | Purposes | Linked to identity? | Used for tracking? |
|---|---|---|---|
| **Identifiers → Device ID**<br>(AdMob advertising ID / IDFV, Firebase app-instance ID, FCM token) | Third-Party Advertising, Analytics, App Functionality | **No** | **No** — see below |
| **Usage Data → Product Interaction**<br>(level started / completed / lost, ad shown) | Analytics | **No** | **No** |
| **Usage Data → Advertising Data**<br>(ad impressions and taps) | Third-Party Advertising, Analytics | **No** | **No** |
| **Location → Coarse Location**<br>(derived from IP by AdMob) | Third-Party Advertising | **No** | **No** |

Everything is **Not Linked to You** because the game has no accounts, no
login and no user identity to link to.

**Declare nothing for:** Contact Info, Health, Financial Info, Contacts,
User Content, Search History, Browsing History, Purchases (no IAP),
Diagnostics (no Crashlytics in `pubspec.yaml`), Sensitive Info.

**Coarse Location is deliberate.** `privacy_policy.md` says AdMob may derive
approximate location from your IP address. The label has to say the same
thing. If you'd rather not declare it, change the policy first — never the
other way round.

---

## Other App Store Connect fields

| Field | Value |
|---|---|
| Bundle ID | `com.megz.coloro` |
| SKU | `COLORO-IOS-001` (any private string; it is never shown) |
| Version | `1.0.4`, build `4` — from `pubspec.yaml` |
| Minimum iOS | 15.0 |
| Copyright | `2026 Megz` — *no © symbol; Apple adds it* |
| Privacy Policy URL | **required** — host `privacy_policy.md` and paste the URL |
| Support URL | **required** — a page with a contact route. A GitHub Pages page with `heba@paradigmsys.info` on it is enough; Apple rejects a bare `mailto:` |
| Marketing URL | optional, leave blank if there's no site |
| Content rights | "No third-party content" — all art is generated by the app |
| Sign-in required for review | **No** |

---

## Export compliance

The app makes no encrypted network calls of its own; the SDKs use standard
HTTPS, which is exempt. Add this to `ios/Runner/Info.plist` and Connect
stops asking on every single upload:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## App Review notes

Paste into "Notes" so a reviewer doesn't file a false rejection:

```
Coloro is a single-player offline puzzle game. No account, login, or
network connection is required to play any part of it — you can review it
in airplane mode.

Ads (banner, interstitial, rewarded) are intentionally disabled for the
first three levels so new players see the game before any advertising.
To see ads during review, finish level 3.

The rewarded ad grants one extra bottle slot and is always optional; every
level is completable without it.
```

---

## Decide these before you upload

These four are iOS-specific and none of them exist on the Play side. The
first is a genuine submission blocker.

### 1. IDFA / App Tracking Transparency — **CONFIRMED HARD BLOCK**

Not a prediction any more. Confirmed at the authoritative gate: clicking
**Add for Review** on version 1.0.4 returns *"Unable to Add for Review"*
with these two items:

> - Before you can submit this app for review, an Admin must provide
>   information about the app's privacy practices in the App Privacy section.
> - Your app contains NSUserTrackingUsageDescription, indicating that it may
>   request permission to track users. To submit for review, update your App
>   Privacy response to indicate that data collected from this app will be
>   used for tracking purposes, or update your app binary and upload a new
>   build.

The same key also greys out **Publish** on the App Privacy page, which is
why the first item never clears: the label cannot be published while the
label says "no tracking" and the binary says "will ask to track".

The cause: `ios/Runner/Info.plist` declares `NSUserTrackingUsageDescription`,
but nothing in `lib/` ever calls the ATT framework — there is no
`app_tracking_transparency` dependency and no UMP consent flow. So the
binary *claims* it will ask to track, and never does. Connect will not let
the label say "no tracking" while that key is in the binary, and the
**Publish** button stays greyed out. An unpublished privacy label blocks
submission.

The whole label is otherwise filled in and saved (4 data types, all Not
Linked, all Tracking = No). Only Publish is blocked.

Three ways out — a product call, not a listing call:

- **Remove the key and rebuild (recommended, honest, fastest to approval).**
  Delete `NSUserTrackingUsageDescription` from `ios/Runner/Info.plist`,
  bump to 1.0.5, `flutter build ipa --release`, upload. The saved label
  then publishes as-is. AdMob gets no IDFA and serves contextual rather
  than personalised ads — lower eCPM, zero rejection risk. This is what
  Apple's own banner tells you to do.
- **Implement ATT properly, then rebuild.** Add Google's UMP consent SDK
  plus an ATT request before initialising AdMob, flip the label's tracking
  answers to **Yes**, and keep the key. Highest ad revenue, and it is also
  what you need for GDPR consent in the EEA. Most work.
- **Declare tracking = Yes on the current build.** Unblocks Publish today
  with no rebuild, but the app would claim tracking it never performs and
  never shows the ATT prompt — a direct Guideline 5.1.2 rejection risk.
  **Not recommended.**

Options 1 and 2 both mean the submitted build is *not* the one currently on
TestFlight.

**Resolved by option 1 (22 Aug 2026).** `NSUserTrackingUsageDescription` was
removed from `ios/Runner/Info.plist`, `ITSAppUsesNonExemptEncryption=false`
added, `pubspec.yaml` bumped to `1.0.5+5`, and `flutter build ipa --release`
produced `build/ios/ipa/coloro.ipa`. Verified in the built binary: the ATT
key is absent and the encryption key reads `false`. Once that build is
uploaded and processed, the saved "no tracking" label publishes and the
version submits unchanged.

### 2. iPad — ship it, or drop the family

`TARGETED_DEVICE_FAMILY = "1,2"` lists the app for iPad, which is why the
13" screenshots are required. But the game is a phone layout: on a
1032 × 1376 pt canvas the board and tray sit small and centred with a lot of
empty space around them (look at `ios_ipad_13_3.png` and `ios_ipad_13_5.png`).
The screenshots are accurate — that genuinely is what an iPad user gets.

Either accept that, or set `TARGETED_DEVICE_FAMILY = 1` in
`ios/Runner.xcodeproj/project.pbxproj`, which makes it an iPhone-only app,
drops the iPad screenshot requirement entirely, and lets iPad users run it
in the iPhone compatibility window. For a one-handed phone puzzle that is
usually the better trade. **Your call — nothing here has been changed.**

### 3. SKAdNetwork IDs — revenue, not approval

`Info.plist` lists exactly one `SKAdNetworkIdentifier`
(`cstr6suwn9.skadnetwork`). Google publishes a list of roughly 150 that
AdMob's mediation partners need for install attribution. Missing them
doesn't block review; it quietly suppresses what advertisers will pay you.
Paste Google's current list before launch:
https://developers.google.com/admob/ios/quick-start#update_your_infoplist

### 4. Privacy manifest — verify at first upload

There is no app-level `PrivacyInfo.xcprivacy` in the Runner target. Each
plugin pod ships its own, which normally covers it. If Apple emails
**ITMS-91053 (missing API declaration)** after your first upload, add
`ios/Runner/PrivacyInfo.xcprivacy` to the Runner target:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyCollectedDataTypes</key>
  <array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
  </array>
</dict>
</plist>
```

`CA92.1` is the reason code for reading/writing your own app's
`NSUserDefaults`, which is what `shared_preferences` does.

---

## Launch checklist

Everything below is **already entered and saved in App Store Connect**
(app `6804212387`, version 1.0.4) unless marked otherwise.

- [x] App name, subtitle, promotional text, keywords, description
- [x] Version set to **1.0.4** so build 4 could be attached
- [x] Copyright `2026 Megz`; Support URL `https://sites.google.com/view/ammegz`
- [x] Category Games → Puzzle, Casual; Content Rights = no third-party content
- [x] Age rating questionnaire → **4+** (advertising declared; A12 in Brazil)
- [x] App Review notes, contact (Ahmed Magdy, +201118723729)
- [x] **"Sign-in required" unchecked** — it was on by default and would have
      made a reviewer wait for credentials that do not exist
- [x] 5 × iPhone 6.9" and 5 × iPad 13" screenshots, in the intended order
- [x] Build **1.0.4 (4)** attached; release set to *automatic on approval*
- [x] Pricing **Free**, available in all 175 countries
- [x] Privacy policy URL; App Privacy label filled (4 data types, Not Linked,
      Tracking = No) — **saved but NOT published, blocked by the ATT issue**
- [x] **ATT block resolved in code** — key removed, 1.0.5+5 built
- [x] Uploaded via `./scripts/deploy_mobile_version.sh --ios-only`
- [x] Connect version set to 1.0.5, build 5 attached, privacy label published
- [x] **SUBMITTED to App Review, 22 Aug 2026 9:33 PM — "Waiting for Review"**
- [x] Add `ITSAppUsesNonExemptEncryption = false` to `Info.plist`
- [ ] Paste Google's full SKAdNetwork list into `Info.plist`
- [ ] Korea: add a GRAC Rating Classification Number, or drop Korea from
      availability — games need an RCN to publish there
- [ ] Verify live ads fill on a real device before releasing widely

Consider replacing the generic Megz privacy policy with the tailored
`privacy_policy.md` in this folder: the hosted Google Sites page never
mentions Coloro, omits Firebase Analytics and the notification token, and
lists Flurry and Facebook Login, which this app does not use.
