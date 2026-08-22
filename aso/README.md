# ASO kit — Coloro

Everything needed to fill the Google Play store card, plus the App Store
variants. All images are **generated from the real game**, so the listing
can never show something the product doesn't do.

## Regenerate every asset

```sh
ASO_OUT=aso flutter test test/aso_generator_test.dart
dart run flutter_launcher_icons        # re-installs the icon on all platforms
```

The screenshots are captured by driving the actual app in a widget test —
change the game, rerun, and the store art updates with it.

## What's in here

| File | Use |
|---|---|
| `icon_512.png` (512²) | **Play "App icon" — Play requires exactly 512×512** |
| `icon.png` (1024²) | App Store icon, and the source for the launcher icons |
| `icon_foreground.png` | Android adaptive icon foreground — **must stay inside the mask circle** |
| `icon_background.png` | Android adaptive icon background (the radial burst) |
| `icon_adaptive_preview.png` | not shipped: simulates what a round-mask launcher renders. Check this after any icon change. |
| `ic_stat_notify.png` | Android status-bar icon (white + alpha only), copied into `res/drawable*/` |
| `feature_graphic.png` (1024×500) | Play "Feature graphic" — **required** |
| `screenshot_1..5.png` (1080×1920) | Play phone screenshots, in order |
| `listing_google_play.md` | name, short + full description, checklist |
| `privacy_policy.md` | host this and paste the URL into both stores |

## Screenshot order (this order is deliberate)

1. **Promo hero** — a designed panel (not an app capture): wordmark,
   tagline, half-drained board, bottle row, promise badges
2. **Drain it colour by colour** — the loop, a full colourful board
3. **Pick the right bottle** — the tension, jam warning visible
4. **Watch the picture vanish** — the payoff, board half-drained
5. **Replay any level** — depth/retention

Most people swipe at most 3, so the loop and the payoff are in slots 2–4.

## App Store (iOS) differences

- **Name** limit is 30 (same text works), plus a **subtitle** limit 30:
  `Drain the pixel art puzzle` (26)
- **Keywords field** (100 chars, comma-separated, no spaces after commas):
  ```
  color,sort,pixel,art,puzzle,brain,relax,offline,logic,bottle,match,casual,drain,water
  ```
- Screenshots must be **1290×2796** (6.7") and **1242×2688** (6.5"). Rerun
  the generator with those sizes if you publish on iOS — change
  `tester.view.physicalSize` and the compose size in
  `test/aso_generator_test.dart`.
- App Store requires a **privacy nutrition label**: declare *Identifiers →
  Device ID* used for Third-Party Advertising and Analytics.

## Launch checklist

- [ ] Host `privacy_policy.md`, paste URL in Play + App Store
- [ ] Play: Data safety form (Device IDs, ads + analytics)
- [ ] Play: "Contains ads" declared
- [ ] Content rating questionnaire (Everyone / PEGI 3)
- [ ] `flutter build appbundle --release` (Play) / `flutter build ipa` (iOS)
- [ ] Verify live ads fill on a real device before wide release
- [ ] Set `AdIds.useTestAds` behaviour is already automatic: debug = test
      ads, release = live ads
