# Session record — Coloro 1.0.6 release night

**When:** 26–27 Aug 2026, overnight, autonomous (Ahmed asleep).
**Purpose of this file:** enough context to pick the work back up cold.
Engineering detail lives in `HANDOFF.md`; marketing lives in `marketing/`.

---

## 1. What was asked

1. Fix the game-experience problems, from a list of playtest notes.
2. Deploy to both stores with `./scripts/deploy_mobile_version.sh`.
3. Submit for review on both stores via the browser, checking store data is correct.
4. Create a Facebook developer app and integrate its events alongside Firebase.
5. Prepare full Google Ads campaign content (launch only on Ahmed's go-ahead).
6. Put everything marketing-related in its own folder.
7. Build an HTML playable for a campaign.
8. Business framing: a $10,000/year revenue target.

Scope Ahmed pre-authorised: Google Play, App Store (Coloro only), Facebook
developers. Meta **ads** are banned on his account — app + integration only.

**His details:** email `ahmedmagdymohamedy@gmail.com`, company **Megz Games**,
privacy policy `https://sites.google.com/view/ammegz`.

### The eleven notes (verbatim intent)

| # | Note |
|---|---|
| 1 | Ads not shown when you lose and replay — need an interstitial |
| 2 | Don't dim the unused bottle, it destroys the colour — slots *and* tray |
| 3 | Some levels are dark; can't tell what's filled from what's empty |
| 4 | Drain each row in a scattered order, not always left → right |
| 5 | The sound keeps speeding up |
| 6 | More haptic feedback |
| 7 | Label the hard levels as hard |
| 8 | Make the rewarded-video button clear and primary (~2s) |
| 9 | Speed up the colour draining |
| 10 | Change the pixel shape, it isn't clear |
| 11 | Can't match colours between the bottles and the pixels |

---

## 2. What shipped — code

Ten of eleven notes fixed. Note 4 was built, measured, and deliberately pulled (§3).

| Note | Change | Files |
|---|---|---|
| 1 | Interstitial on the loss→retry path, same gate as between-levels (level ≥ 4, 30s apart). `maybeShowInterstitial` param renamed `completedLevel` → `level`. | `game_screen.dart`, `ad_service.dart` |
| 2 | All colour-destroying dimming removed. Starving slots get a pulsing **red alarm ring outside the glass**; queued tray rows use depth (softer highlights, deeper shadow) and keep true colour. | `bottle_view.dart`, `slot_bar.dart`, `tray_view.dart` |
| 3, 10, 11 | **One shared fix** — see below. | `display_palette.dart` (new), `bead_atlas.dart`, `pixel_picture.dart` |
| 5 | Pitch ramp removed. Was `0.9 + progress*0.45`; now fixed pitch with a tiny deterministic wobble. Tick gap 0.045 → 0.055. | `game_screen.dart` |
| 6 | Continuous drink pulse (`Haptics.tick()`, ~0.11s gap), quarter-progress milestones, starving promoted light → medium. | `game_screen.dart`, `haptics.dart` |
| 7 | HARD badge in the in-game HUD (the menu card already had one). | `game_hud.dart` |
| 8 | Rewarded button enlarged and primary, lands alone; retry + menu fade in after **2s**. | `level_failed_overlay.dart` |
| 9 | `fillRate` 4.5 → **7.0**/s; hold-to-boost 2× → **3×**. | `game_controller.dart`, `game_screen.dart` |

### The key insight: notes 3, 10, 11 were one problem

New file **`lib/core/theme/display_palette.dart`** is now the single source of
truth for how a palette colour is *drawn*. The bead atlas, flask painter,
flying-pixel VFX, menu previews and the level-complete reward all go through it —
which is what makes a bottle visibly match the pixels it drinks.

It **remaps** lightness into `[0.44, 0.86]` rather than clamping (a clamp
collapses two dark colours onto one value; a remap preserves ordering and
distance). Sockets were also made **colourless** — a tinted socket is exactly
what made dark boards unreadable.

**Puzzle data is untouched** — cells, palette indices, bottle counts identical,
so every shipped solvability proof still describes the level players get.

---

## 3. Note 4 — measured, then pulled (read before retrying)

The drain tie-break was changed from *leftmost* to *scattered*.
`tool/reproof_deals.dart` (new) re-proved the whole campaign, re-searching each
level's `(shuffleWindow, dealSeed)` over the same space `gen_levels.dart` uses —
40 seeds per window, every window down to 1:

| Tie-break | Levels left unwinnable |
|---|---|
| leftmost *(shipped)* | **0 / 300** |
| scattered per (level, row) | 71 / 300 |
| scattered per level | 77 / 300 |

Not bad seeds: at window 1 the deal **is** the solver's own witness order, so a
level failing there can't be beaten at all under the new rule.

**To ship it properly:** regenerate the campaign with `dart run tool/gen_levels.dart`
(re-derives art *and* deals together) and gate on `COLORO_FULL_SWEEP=1`. That is a
content release, not a seed patch.

Full reasoning + numbers are recorded in `lib/game/drain_order.dart` so nobody
retries it blind. `DrainOrder` was kept as the shared rule both the runtime and
the solver call — a genuine structural win from the failed experiment.

Partial compensation shipped: fill rate 4.5 → 7.0/s, so four flasks dissolve the
board from four places at once and the typewriter feel is much weaker.

---

## 4. Facebook / Meta — written, not switched on

`lib/core/analytics/meta_events.dart` (new) defines the Meta funnel;
`analytics_service.dart` fans every relevant event to it. **Inert until an app id
is configured**, which is why it was safe in this build.

Events chosen (small + standard-named, because Meta's models have cross-advertiser
priors for standard names; the 365 per-level Firebase names would mean nothing):
`fb_mobile_level_achieved`, `fb_mobile_tutorial_completion` (level 1 = activation),
`fb_mobile_ad_impression`, `fb_mobile_rewarded_video_completed`,
`fb_mobile_session_milestone`.

**Android-only when the SDK lands**, for two recorded reasons: `ios/` is
deliberately SPM-only with no Podfile, and `ios/Runner/Info.plist` records that
Connect **already refused a submission once** over tracking signals. Full steps:
`marketing/docs/facebook-app-events.md`.

---

## 5. Store state

### Google Play — SUBMITTED FOR REVIEW

- developer `9004145411394454957` (Megz Games) · app `4973484828510117385`
- Was a **draft, never published** — this was a first publication, not an update.
- Account already has production apps, so no 12-tester/14-day wall.

Completed in the console:
1. **Advertising ID** declaration (was blocking Android 13+): **Yes**, purposes
   *Analytics* + *Advertising or marketing*.
2. **Content rating** — finished a stale questionnaire. Category Game, **No** to all
   14 content questions. Result General/Everyone.
   *Gotcha: the Next button stays disabled until you press **Save** first.*
3. **Production release created** — version code 6 (1.0.6) from the bundle library,
   177 countries, release notes written.
4. **Target audience corrected** — had *every* age group ticked incl. under-13, which
   triggers the Families policy while the code serves plain personalised AdMob ads
   with no child-directed treatment. Set to **13+**. This was a rejection or a policy
   strike waiting to happen.
5. **Submitted** — 12 changes, pre-launch checks clean. Reviews usually ≤ 7 days.

Verified: name *Coloro: Pixel Color Sort*, `com.megz.coloro`, targetSdk **36**
(clears the 31 Aug deadline), minSdk 24, 11.8 MB, category Games → Puzzle,
privacy policy `https://sites.google.com/view/ammegz`.

### App Store — NOT SUBMITTED

Build **1.0.6 (6)** uploaded and accepted (`UPLOAD SUCCEEDED`, delivery UUID
`d1a083a4-e14a-41df-b05d-1cea0727cd9e`, 24.9 MB). Connect is **logged out** and
needs an Apple ID password + 2FA — I don't enter passwords. Steps: `HANDOFF.md` §6.

Already handled in the binary: `ITSAppUsesNonExemptEncryption = false`, and
deliberately **no** `NSUserTrackingUsageDescription`.

---

## 6. ⚠️ Open risk: git HEAD is wrong, and it's pushed

HEAD moved `ee72053` → `198de8c "add IOS ASO git push"` **during the session** —
something on the machine committed and pushed; I never ran git. That commit
captured `drain_order.dart` in its **experiment-2** state = 77 unwinnable levels,
and `198de8c` is on **`origin/main`**.

- ✅ The shipped build is correct — compiled after the revert, 303/303 tests green.
- ❌ A fresh clone or CI builds the broken campaign.

**Fix: commit and push the current working tree.** Verify with:

```sh
grep -n 'static int pick' lib/game/drain_order.dart
# correct → static int pick(List<int> candidates) => candidates.first;
```

---

## 7. Verification at end of session

```
flutter analyze lib/ test/ tool/            → clean
flutter test                                 → 62/62
COLORO_FULL_SWEEP=1 flutter test \
  test/stall_diagnostic_test.dart            → 303/303
```

The sweep re-proves **all 300 shipped levels** solvable against the art on disk
under the rule this build actually ships.

---

## 8. Marketing deliverables

| Path | What |
|---|---|
| `marketing/playable/coloro_playable.html` | HTML playable. One ~20 KB file, **zero network requests**. Real mechanic on a 12×12 heart, ~25s to clear. Cannot be lost (tap a docked bottle to return it); banner appears if all bottles block. Verified winnable via its `window.__coloroQA` hook: 20 bottles, no rescues, 0 cells left. CTA tries mraid / FbPlayableAd / ExitApi then falls back to a store link. |
| `marketing/campaigns/google-ads-kit.md` | Revenue arithmetic, campaign structure, 5 headlines + 5 descriptions, creative specs, 15s video script, kill criteria. |
| `marketing/docs/facebook-app-events.md` | Meta: done / blocked / how to finish. |
| `marketing/README.md` | Index. |

### The business finding that matters

**At current ARPU, paid installs lose money.** ~35,000 paid installs cost ~$15,750
to earn ~$10,000. $10k/yr = $833/mo = ~2,300 DAU at $0.012 ARPDAU, or ~930 DAU at
$0.030.

Order of operations: **organic/ASO → AdMob mediation (+30–80% eCPM, no game
changes) → small paid test, scaled only where LTV > CPI.** Retention is the real
unknown; the first 30 days of Firebase data answers it.

Do **not** edit campaigns for 14 days after launch — App campaigns need ~100
conversions to leave learning. Optimise toward `finish_level_5` (already emitted),
not `first_open`.

---

## 9. Next actions, in order

1. **Commit + push the working tree** — the remote is poisoned until then.
2. **Submit iOS** — needs your login (~15 min).
3. **Create the Facebook app** — ~2 min, then the SDK is a small Android-only PR.
4. **Configure AdMob mediation** — before any ad spend.
5. Watch for Google's review result (≤ 7 days typical).
6. **After Play approves, refresh the listing art** — the live listing still shows
   the 22 Aug screenshots with dimmed bottles and unreadable dark boards, i.e. the
   exact defects 1.0.6 fixes. Upload `aso/screenshot_1..5.png` and
   `aso/feature_graphic.png`. Not done pre-submission because editing listing assets
   mid-review can restart the review clock.

---

## 10. New / changed files

**New:** `lib/core/theme/display_palette.dart`, `lib/core/analytics/meta_events.dart`,
`lib/game/drain_order.dart`, `tool/reproof_deals.dart`, `HANDOFF.md`, `marketing/**`,
`chat_history/**`

**Changed:** `bead_atlas.dart`, `bottle_view.dart`, `slot_bar.dart`, `tray_view.dart`,
`pixel_picture.dart`, `game_hud.dart`, `game_controller.dart`, `bottle_factory.dart`,
`game_screen.dart`, `level_failed_overlay.dart`, `analytics_service.dart`,
`ad_service.dart`, `haptics.dart`, `pubspec.yaml` (1.0.5+5 → **1.0.6+6**),
`stall_diagnostic_test.dart` (+ `COLORO_FULL_SWEEP`), regenerated `aso/*.png`

**Two things I refused:** entering the Meta account password, and entering the Apple
ID password + 2FA. Both left clean state — no half-created Facebook app, nothing
partially submitted on Apple.
