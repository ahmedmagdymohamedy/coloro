# Decision log

Chronological. Each entry: what was decided, **why**, and how it turned out.
Newest at the bottom, so the file reads as a story.

Full session detail lives in `chat_history/`; this is the index and the
reasoning. IDs like **D-7** are stable — reference them from commits and other
docs rather than restating the reasoning.

---

## Build-out — 20–22 Aug 2026

### D-1 · The drain mechanic, after two rewrites
**Decided:** bottles never move. Docked in slots, they continuously drink each
column's lowest remaining pixel of their colour — deepest row first, swept
left to right, **one pixel per take**.

**Why:** two earlier designs were built and thrown away. A *production line*
(bottles ride a track looping the picture) and a *scanline* both put motion
between the player's decision and its consequence, which made the puzzle hard
to read. Ahmed also explicitly rejected random pixel selection and a 50%
double-grab: the drain has to be fully deterministic or the player cannot plan.

**Consequence:** the whole solvability apparatus depends on this being
deterministic. Any change here invalidates all 300 proofs.

### D-2 · Manual dispatch — the player is the machine operator
**Decided:** a tapped tray bottle docks and runs its first lap automatically;
after that it idles until the player taps it again.

**Why:** Ahmed's framing — the player operates the machine rather than watching
it. Also gives every bottle a fair chance: no pre-judging. A bottle always gets
its lap, and the jam warning only appears after a lap that painted nothing.

### D-3 · Outside-in painting, and a real fail state
**Decided:** bottles only paint cells on the frontier of the unpainted image;
an off-edge bottle jams its slot; all slots jammed = Machine Jammed, with a
retry overlay.

**Why:** Ahmed explicitly wanted a lose condition. Without one there is no
tension and no reason to think before tapping.

**How it turned out:** correct as a design, and the single biggest leak in the
funnel eighteen days later. See **D-14**.

### D-4 · Four slots, not five
**Decided:** `GameController.slotCount = 4` (was 5), matched by
`BottleFactory.slotCount`.

**Why:** at 5 slots the solver ground for 25+ minutes without converging, so
levels could not be generated at all.

**Cost:** it is a **campaign-wide constant**. Changing it invalidates every
level's solvability proof and forces all 300 to be regenerated. The difficulty
ramps all had to come down with it.

### D-5 · Rebuild the campaign — "too fucking easy"
**Decided:** 300 levels (240 normal + 60 hard, interleaved 4:1), difficulty
riding three ramped dials — grid size, colour count, and **vertical churn**
(how often colour changes up a column) — plus a deliberately **shuffled** tray.

**Why:** Ahmed played the first campaign and found it trivial. A sorted tray
was most of the problem: it let the player work top-to-bottom without thinking.

**Three fairness rules discovered the hard way, which must not be dropped:**
1. Colours must be ≥56 apart or the quantiser merges them.
2. Every colour must cover **≥55% of columns**, or its bottle starves as a slot
   hostage.
3. Bottle capacity ≤ ~⅓ of that colour's total — big bottles for scattered
   colours deadlock the machine.

### D-6 · Combos and stars removed
**Decided:** no combo counter, no streak sounds, no per-level stars. Progress
is just `unlockedLevel` / `completedCount`; the reward for finishing a level is
seeing the finished picture.

**Why:** Ahmed's verdict — "not logical". A combo system rewards speed in a
game that is about planning.

---

## Store launch — 22–28 Aug 2026

### D-7 · Store art is generated from the real game, never drawn separately
**Decided:** every screenshot, the feature graphic and the icon are produced by
`test/aso_generator_test.dart` running the actual game.

**Why:** store art that is drawn by hand drifts from the product. Generating it
means it *cannot*. This paid off immediately when the palette changed (**D-8**)
— regenerating was one command.

**Also:** Ahmed rejected a first icon that was dark, flat and thin-lined. Keep
icons **bold and saturated**.

### D-8 · The fixed 12-colour palette — the "two greens" fix
**Decided:** `lib/data/game_palette.dart` is the only source of colour. Levels
no longer derive a palette from their art; every pixel snaps to one of twelve,
**one colour per 30° hue slot**.

**Why:** players reported two shades that read as the same colour. A distance
metric happily calls a dark cyan and a light cyan "different"; a human reads
them as one colour lighter. The hue-slot rule is what actually answers the
complaint; maximising minimum separation (closest pair 62, up from 52) is the
belt to that braces.

**Cost:** all 300 levels re-proved. 242 unaffected, **58 needed a new deal, 0
unrepairable**. Bottle capacity cap had to come down from `min(40, total/3)` to
`min(20, total/4)` — merging near-identical colours makes each surviving colour
bigger, which under the old formula produced 40-capacity bottles that sat
starving. That was the single biggest cause of levels becoming unwinnable.

**Also:** `DisplayPalette.of()` became a pass-through. Its lightness remap
existed to rescue dark art-derived palettes; applied to a fixed palette it
compresses the closest pair from 62 to 21 and undoes the entire fix.

---

## Monetisation — 1 Sep 2026

### D-9 · Mediation before acquisition
**Decided:** configure AdMob mediation (Unity Ads as a **bidding** source in
three groups) before spending anything on ads. Shipped as 1.0.8.

**Why:** mediation raises eCPM 30–80% with no game changes. Buying users before
it is in place is the most expensive possible order to do things in.

**How it turned out:** correct in principle, irrelevant in practice — see
**D-13**. Unity has served **zero** impressions, because the app produces
almost no impressions at all. Mediation was never the bottleneck.

**Note:** AppLovin does not offer bidding on AdMob (checked the full 38-network
list). It has to be a waterfall source, which needs an SDK key Ahmed did not
have. The adapter shipped inert.

### D-10 · Launch flight 1 with video, and not before
**Decided:** hold the campaign until a 15s portrait video existed, then run a
concentrated flight (E£500/day, 1→13 Sep) rather than a trickle.

**Why:** App campaigns spend most of a budget on video. Launching without one
does not just underdeliver, it *contaminates the flight* — a bad CPI cannot be
attributed to the geo, the bid, or the missing asset. At one flight per month,
a wasted flight costs a month.

**Also rejected:** a trickle budget. $3/day never leaves the learning phase,
because App campaigns need ~100 conversions to learn.

---

## The data-safety rejection — 1 Sep 2026

### D-11 · The Data safety form said we collect nothing. It had since launch.
**What happened:** Google rejected version code 8 — *Invalid Data safety form*,
device identifiers detected, attributed to the AppLovin SDK.

**The real cause was worse than the email suggested.** Question 1 of the form —
"does your app collect or share any user data?" — was answered **No**, and had
been since launch. That was already wrong for 1.0.7: AdMob transmits the
advertising ID and Firebase an app-instance ID. The AppLovin adapter is merely
what made Google's scanner notice.

**Decided:** fix the form, not the code. Declared four types — approximate
location, app interactions, diagnostics, device or other IDs — all **collected
AND shared**, taken from the union of each SDK's own published Play disclosure.
No rebuild; code 8 as already uploaded went back into review and was approved.

**Explicitly rejected:** removing the AppLovin adapter. It would have shipped
another build with the same wrong form, and the adapter is wanted later anyway.

**Rules this leaves behind:**
- Adding any SDK means re-opening this form. The scanner re-runs every release.
- The form and the privacy policy must agree. **Play still points at
  `sites.google.com/view/ammegz`, a generic Megz-wide policy that never
  mentions advertising IDs.** The accurate Coloro policy is `aso/privacy_policy.md`
  and has never been hosted. Still open.

### D-12 · Ship to internal testing, always
**What happened:** 1.0.8 went straight to Play production because the deploy
ran with `--track production`. The script's `TRACK` is a single destination,
not a promotion chain, so internal testing was skipped and Ahmed had nothing to
install while production sat in review.

**Decided:** the script's default (`internal`) is the default for a reason.
Ship there, test, then promote. If `--track production` is used deliberately,
add the internal release by hand the same session — which is what 1.0.9 did.

---

## Flight 1 — read and acted on, 3 Sep 2026

### D-13 · Acquisition works; the game does not keep what it buys
**What the first two days measured** (full read: `marketing/FLIGHT1_READ_2026-09-03.md`):

- 112 installs at **E£15.18 (~$0.30) CPI** on a **9.2% CTR** for ≈E£1,700.
  On plan, and 3× better than the $0.90 kill line. **The ads work.**
- Of 99 who opened the app: 70 started a level, **36 lost level 1**, 24 ever
  won one, **8 reached level 5, and 8 ever saw an ad.**
- **$34 spent, $0.28 earned** — ~$121 of spend per $1 of revenue.
- **ARPDAU $0.002 against the $0.03 modelled — 15× short.** This is the number
  that broke the six-month arithmetic.

**The diagnosis:** ads unlocked at level 4, so **~92% of every pound spent
bought a player who never saw a single ad.** Past level 5 the game holds people
well — users persist to level 40 — so the wall is onboarding, not depth.

**Decided:** pause the flight rather than run it to 13 Sep.

**Why, given the plan said "do not touch it for 10 days":** that rule protects
*bid learning*, and no amount of bid learning fixes a product that loses 92% of
users before the ad gate. The governing precedent is our own earlier refusal to
launch on 1.0.6 — *buying installs onto a build with a defect means paying to
show people the defect*. The onboarding wall was that defect. The 112-user
cohort kept ageing for free, so stopping cost nothing.

### D-14 · 1.0.9 — ads from level 1, and a door out after three losses
**Decided, and shipped the same night:**

1. **`adsFromLevel` 4 → 1** (banner), **interstitials 4 → 2**. The first level
   a player finishes still ends without a full-screen ad — that is the part of
   "clean onboarding" worth keeping. The rest was protecting a stretch of the
   game players do not survive.
2. **A `SKIP THIS PICTURE` offer after 3 consecutive losses on the same board.**
   The moment of highest intent and the game's largest exit — 46 players, 291
   losses, 6.3 each.

**Why the skip is granted even when no ad is available:** a player refused
after three defeats churns, and a churned player earns nothing at all. The ad
is the upside, not the toll. The wording changes with inventory so the card
never promises an ad it cannot show.

**Recorded as skipped, not completed**, so the menu's check marks and
`completedCount` stay honest; solving it later promotes it to a real
completion. The loss streak is *persisted*, not held in the widget, because
every retry builds a fresh `GameScreen` and because a player who quits in
frustration should still be offered the way out when they return.

**Explicitly decided against:**
- **Easing levels 1–5.** The obvious reading of "36 of 70 lose level 1" is that
  the early levels are too hard — but levels 1–4 are already at the generator's
  **floor**: 15×15 grid, 5 colours, the bottom of the ramp. The wall is the
  *mechanic*, not the grid. Regenerating art would burn a long solver run to
  change nothing. The real fix is a tutorial or a gentler early jam rule, and
  that is a design change to make with Ahmed awake.
- **Closing the back-button ad hole.** It is real unserved inventory, but
  "double-back is deliberately left alone" was a recorded decision.
- **An in-app review prompt.** On the plan's list and good for ASO, but it
  needs a new native dependency that could not be verified on a device that
  night.

**Verified before shipping:** analyze clean, 85/85 tests (14 new), and the full
303/303 solvability sweep.

### D-15 · The organic-traffic restart gate was unmeasurable — withdrawn
**What happened:** **D-13**'s follow-up set the flight-2 restart gate at
"`finish_level_5` ≥ 15% of installs **on organic traffic**". Ahmed caught the
hole: **there is no organic traffic.** The gate could never have been met, and
the campaign would have stayed off forever waiting for a number that was never
coming.

**Why both free channels are dead** (27 Aug – 2 Sep):

| Campaign | Configuration | Impressions | Installs |
|---|---|---|---|
| `Coloro-House-CrossPromo` | Google-optimised **backfill** — serves only inventory that would otherwise go unfilled | 222 | **0** |
| `Coloro` (24197514460) | AdMob install campaign, **max CPI E£1.00** | 285 | **0** |

The second is the sharper find: **a E£1.00 cost cap against a ~E£15 market
rate.** It cannot win an auction, so it has been serving impressions and buying
nothing. Mispriced, not merely weak. Still open.

**Decided:** measure on **paid** installs, because that is the only traffic
that exists. 1.0.9 went live 3 Sep 05:14, so every new install now gets the new
build with no update needed — new installs are the *cleanest* place to measure,
not a compromise.

### D-16 · Restart at E£100/day, not E£50
**Decided:** the flight resumed 3 Sep at **E£100/day**, running to its existing
13 Sep end date. ≈E£1,100 for ~70 installs; September lands near E£2,800 of the
5,000 budget.

**Why not E£50/day**, which was Ahmed's first instinct: at ~E£15 CPI that is
~3 installs a day, so a cohort big enough to tell 8% from 15% takes a month.
The two rates cost about the same in total — the only difference is whether the
answer arrives on 13 Sep or in October.

**Ahmed made this change himself.** Typing a monetary value into an ad platform
is refused by the agent permission layer, and that guard should stay.

**What to read on 13 Sep:** `finish_level_5` / installs (was 8%, target ≥15%)
and `ad_shown` users / `first_open` users (was 8%). The second should move on
its own as existing players update, without buying anyone.
