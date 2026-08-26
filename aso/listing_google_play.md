# Google Play listing — Coloro

Copy each block straight into Play Console. Character counts are checked
against Play's limits.

---

## App name  (limit 30)

```
Coloro: Pixel Color Sort
```
*24 chars.* Brand first (so it's searchable once you have installs), then
the two highest-volume keywords this game can honestly rank for:
**color sort** and **pixel**. Do not pad it with extra words — Play now
penalises keyword-stuffed titles, and a short name is what shows in full
on the search results row.

**Alternates if the name is taken:**
- `Coloro - Color Sort Puzzle` (26)
- `Coloro: Pixel Art Sort` (22)

---

## Short description  (limit 80)

```
Sort colored bottles, drain the pixel art, and solve 300 offline puzzles.
```
*73 chars.* This is the highest-weighted indexed text after the title, and
it's the line people actually read before tapping **Install**. It carries
`sort`, `color`, `pixel art`, `puzzle`, `offline`, and states the loop in
one sentence.

**A/B alternates** (Play Console → Store listing experiments):
- `Drain pixel pictures color by color. 300 handcrafted offline puzzles.` (68)
- `Pick the right bottle, drain the picture. A relaxing color sort puzzle.` (70)

---

## Full description  (limit 4000)

```
Pick a bottle. Watch it drink the picture away, one pixel at a time.

Coloro is a color-sorting puzzle with a twist you can feel: every level is a
tiny pixel-art picture, and your bottles drain it from the bottom edge up.
Choose well and the artwork dissolves in one satisfying cascade. Choose
badly and the machine jams.

🎨 A PUZZLE YOU CAN SEE
Every level is a hand-tuned pixel picture — moons, hearts, rockets, cats,
crowns, rainbows. The board starts in full color and disappears as you play,
so you always know exactly how close you are.

🧪 SIMPLE TO PLAY, HARD TO MASTER
• Tap a bottle to dock it in one of 4 slots
• Docked bottles drink matching pixels off the bottom edge
• A bottle whose color is buried starves — and holds its slot hostage
• Fill all 4 slots with starving bottles and the machine jams

That's the whole game. No timers, no lives, no energy meter. Just you, the
picture, and the order you choose.

🧠 REAL DECISIONS, NOT LUCK
The bottle you need is never conveniently on top. Read the picture, work out
which colors are about to surface, and park the ones you can't use yet. Every
single level was verified solvable by a solver that plays under the same
rules you do — if you lose, there was a better line.

🌈 300 LEVELS THAT ACTUALLY GET HARDER
Four normal levels, then a hard one, all the way to 300. Pictures grow from
15×15 to 40×40, palettes from 5 colors to 10, and the colors interleave more
tightly the deeper you go. Level 250 is nothing like level 5.

✈️ PLAYS ANYWHERE
100% offline. No account, no login, no waiting. Open it on a plane, in a
queue, or in bed with one hand.

🔁 REPLAY ANYTHING
Swipe the level carousel to revisit any picture you have finished and drain
it again.

Coloro is for anyone who likes color sort games, pixel art, nonograms,
water sort puzzles, or the very specific pleasure of watching something
neatly disassemble itself.

Free to play. Download Coloro and start draining.
```

*1,936 chars of 4,000.* Structure follows what converts on Play: a hook line, then
scannable emoji-headed blocks, keyword coverage spread naturally
(`color sort`, `pixel art`, `puzzle`, `offline`, `water sort`, `nonogram`),
and a clear closing call to action. Play indexes this text, but readability
matters more than density — the first 3 lines are all most people see
before tapping "more".

---

## Assets checklist

| Asset | File | Spec | Status |
|---|---|---|---|
| App icon | `icon_512.png` | 512×512 PNG exactly (Play rejects other sizes) | ✅ generated |
| Feature graphic | `feature_graphic.png` | 1024×500 PNG | ✅ generated |
| Phone screenshots | `screenshot_1..5.png` | 1080×1920, min 2, max 8 | ✅ generated |
| Promo hero | `screenshot_1.png` | designed panel, not an app capture | ✅ generated |
| Adaptive icon | `icon_foreground.png` + `#7B2FF7` | installed into the app | ✅ generated |

Play also asks for a **7-inch and 10-inch tablet screenshot** if you list
the app as tablet-compatible. If you don't want to produce them, set the
listing to phone-only.

---

## Categorisation

- **Category:** Games → Puzzle
- **Tags:** Puzzle, Casual, Brain, Single player, Offline
- **Content rating:** Everyone / PEGI 3 — no violence, no user content, no
  chat. Declare **"Contains ads"** (you serve banner, interstitial and
  rewarded).

---

## Required before you can publish

1. **Privacy policy URL** — mandatory because the app serves ads and
   Firebase Analytics collects identifiers. See `privacy_policy.md` in this
   folder; host it anywhere public (GitHub Pages works) and paste the URL.
2. **Data safety form** — declare: *Device or other IDs* collected, linked
   to advertising and analytics, not user-deletable. Firebase Analytics
   collects an app instance ID; AdMob collects the advertising ID.
3. **Ads declaration** — "Yes, my app contains ads".
4. **Target audience** — if you ever tick 13-and-under you must turn on
   `TagForChildDirectedTreatment` in AdMob and drop personalised ads.
5. **App signing** — let Play manage the signing key; build with
   `flutter build appbundle --release`.
