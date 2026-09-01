# House-ad creatives — AdMob cross-promotion

Nine images for the AdMob **house campaign** that promotes Coloro inside the
other Megz apps. This is the free install channel in
[`../MARKETING_PLAN.md`](../MARKETING_PLAN.md) §1.2 — no spend, and it draws
on an audience that already plays this kind of game.

Generated from the real game art, not mocked up:

```bash
ASO_OUT=marketing flutter test test/aso_generator_test.dart --plain-name 'house ads'
```

They share the wordmark, the palette, the bead shape and the half-drained
board with `aso/feature_graphic.png`, because they come out of the same
painters in `test/aso_generator_test.dart`. Change the brand there and every
piece of art moves together.

## The files

| File | Slot | Size | Priority |
|---|---|---|---|
| `ad_320x50.png` | Banner | 17 KB | **1 — most inventory by far** |
| `ad_320x100.png` | Large banner | 31 KB | 3 |
| `ad_300x250.png` | Medium rectangle | 50 KB | **2 — best eCPM of the banner sizes** |
| `ad_468x60.png` | Full banner | 25 KB | 6 |
| `ad_728x90.png` | Leaderboard | 46 KB | 5 |
| `ad_320x480.png` | Interstitial, phone portrait | 90 KB | **2 — highest intent** |
| `ad_480x320.png` | Interstitial, phone landscape | 97 KB | 4 |
| `ad_768x1024.jpg` | Interstitial, tablet portrait | 105 KB | 7 |
| `ad_1024x768.jpg` | Interstitial, tablet landscape | 91 KB | 7 |

If you only do three, do **320x50, 300x250, 320x480**. That covers most of
the impressions a portfolio of casual games actually serves.

### Two constraints these were built against

**The sizes are exact.** AdMob's image ads accept only this fixed set — an
image that is a few pixels off cannot be attached to an ad at all. Do not
resize or crop them.

**150 KB per image.** The two tablet interstitials came out at 372 KB and
354 KB as PNG, which AdMob rejects, so those two ship as JPEG (quality 72,
~100 KB). Everything else stays PNG. If you regenerate them, redo that
step — the raw PNGs are over the limit:

```bash
sips -s format jpeg -s formatOptions 72 ad_1024x768.png --out ad_1024x768.jpg
```

## Creating the ads in AdMob

The campaign wizard makes **one ad per image**, so this is repeated once per
size. In *Create campaign → step 4 (Create ads)*:

1. **Ad type**: Image ad
2. **Ad name**: name it after the size — `Coloro_320x50`, `Coloro_300x250`,
   … Do **not** leave them as `Coloro_01`, `Coloro_02`: when one size
   underperforms, the report is the only place you find out, and it is
   listed by ad name.
3. **Destination URL**: use the tagged link below, not the bare store link
4. **Image**: upload the matching file
5. **Create ad**, then repeat for the next size

### Destination URL

```
https://play.google.com/store/apps/details?id=com.megz.coloro&referrer=utm_source%3Dadmob_house%26utm_medium%3Dcross_promo%26utm_campaign%3Dportfolio
```

The `referrer` parameter is what makes these installs separable from organic
ones in Play Console → Acquisition, and it is the only way to answer "did
cross-promo actually work". The inner `%3D` / `%26` encoding is required —
Play drops the referrer if the parameter is not encoded, and it fails
silently, so it is worth pasting rather than retyping.

## What to watch

Success here is **installs per 1,000 impressions**, not clicks. House ads
occupy inventory that would otherwise earn money, so the honest measure is
whether the installs are worth the displaced revenue. Check after a week:

- Play Console → Acquisition → filter to `utm_source=admob_house`
- If installs/1k impressions is under ~2, the creative is losing to the
  paying ads it replaced — swap the interstitial in before giving up on the
  channel, since that is the slot with the intent.
