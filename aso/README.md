# ASO kit — Coloro

Everything needed to fill the Google Play store card **and** the App Store
product page. All images are **generated from the real game**, so neither
listing can show something the product doesn't do.

## Regenerate every asset

```sh
ASO_OUT=aso flutter test test/aso_generator_test.dart
dart run flutter_launcher_icons        # re-installs the icon on all platforms
```

The screenshots are captured by driving the actual app in a widget test —
change the game, rerun, and the store art updates with it. All three sets
(Play phone, 6.9" iPhone, 13" iPad) run the identical script at each store's
own device geometry, so the two listings can never tell different stories.

## What's in here

| File | Use |
|---|---|
| `icon_512.png` (512²) | **Play "App icon" — Play requires exactly 512×512** |
| `icon.png` (1024²) | source for every launcher icon. Not uploaded anywhere: App Store Connect takes its 1024² marketing icon out of the build's asset catalog. |
| `icon_foreground.png` | Android adaptive icon foreground — **must stay inside the mask circle** |
| `icon_background.png` | Android adaptive icon background (the radial burst) |
| `icon_adaptive_preview.png` | not shipped: simulates what a round-mask launcher renders. Check this after any icon change. |
| `ic_stat_notify.png` | Android status-bar icon (white + alpha only), copied into `res/drawable*/` |
| `feature_graphic.png` (1024×500) | Play "Feature graphic" — **required** |
| `screenshot_1..5.png` (1080×1920) | Play phone screenshots, in order |
| `ios_iphone_69_1..5.png` (1320×2868) | App Store 6.9" iPhone set — **required** |
| `ios_ipad_13_1..5.png` (2064×2752) | App Store 13" iPad set — required while the app is listed for iPad |
| `listing_google_play.md` | Play: name, short + full description, checklist |
| `listing_app_store.md` | App Store: name, subtitle, promo text, keywords, privacy label, checklist |
| `privacy_policy.md` | host this and paste the URL into both stores |

## Screenshot order (this order is deliberate)

1. **Promo hero** — a designed panel (not an app capture): wordmark,
   tagline, half-drained board, bottle row, promise badges
2. **Drain it colour by colour** — the loop, a full colourful board
3. **Pick the right bottle** — the tension, jam warning visible
4. **Watch the picture vanish** — the payoff, board half-drained
5. **Replay any level** — depth/retention

Most people swipe at most 3, so the loop and the payoff are in slots 2–4.

## App Store (iOS)

Everything iOS-specific — subtitle, promotional text, keywords, the privacy
nutrition label, age rating, and the four things to decide before you
upload — lives in **`listing_app_store.md`**. Two points that shape this
folder:

- Apple asks for only the **largest display in each family** and scales it
  down for every older device, so the generator produces exactly two iOS
  sets: **1320×2868** (6.9" iPhone) and **2064×2752** (13" iPad). The 6.5",
  5.5" and 12.9" sets are no longer needed.
- The **13" iPad set is only required while `TARGETED_DEVICE_FAMILY = "1,2"`**.
  The game is a phone layout, so it sits small on an iPad canvas — see the
  iPad decision in `listing_app_store.md`.

## Launch checklist

- [ ] Host `privacy_policy.md`, paste URL in Play + App Store
- [ ] Play: Data safety form (Device IDs, ads + analytics)
- [ ] Play: "Contains ads" declared
- [ ] Play: content rating questionnaire (Everyone / PEGI 3)
- [ ] App Store: work through `listing_app_store.md` — the ATT/IDFA
      question there is a submission blocker until it's decided
- [ ] `flutter build appbundle --release` (Play) / `flutter build ipa` (iOS)
- [ ] Verify live ads fill on a real device before wide release
- [ ] Set `AdIds.useTestAds` behaviour is already automatic: debug = test
      ads, release = live ads
