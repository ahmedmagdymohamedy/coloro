# Session record — Flight 1 read, campaign paused, 1.0.9 built and shipped

**When:** 3 Sep 2026, overnight. Ahmed handed over full decision-making
("take your decision and solve all you see"), set **one red line — never
exceed the budget** — and went to sleep.
**Previous session:** `chat_history/2026-09-01-data-safety-rejection-session.md`

---

## 1. What the numbers said

Full analysis with every figure: **`marketing/FLIGHT1_READ_2026-09-03.md`**.
The short version, from Google Ads, GA4, AdMob, Unity and Play Console:

- **Acquisition works.** 112 installs at **E£15.18 (~$0.30) CPI** on a **9.2%
  CTR** for ≈E£1,700 (~$34). That is exactly the tier-3 CPI §0 of the plan
  assumed and 3× better than the $0.90 kill line.
- **Everything after the install does not.** Of 99 `first_open`: 70 started a
  level, **36 lost level 1**, 24 ever won one, **8 reached level 5**, **8 ever
  saw an ad**. 1.7 sessions per user. 291 losses across 46 players.
- **$34 in, $0.28 out** — about $121 of spend per $1 earned. **ARPDAU $0.002
  against the $0.03 modelled: 15× short.**
- **Unity Ads: zero impressions.** Not a mediation fault — the whole app
  produced 56 impressions in three days. Mediation cannot be evaluated, and
  is not the bottleneck.
- **House cross-promo: 511 impressions, 0 installs** in a week, against a
  target of 500–1,500 installs/month.
- Good news found along the way: **1.0.8 was approved and is live** — the data
  safety fix cleared review.

The plan's own §2.5 gates: CPI **passed**, `finish_level_5` ≥ 15% **failed**
(0% attributed, 8% all-time), cost per `finish_level_5` < $3 **failed**.

## 2. Decisions taken

### Paused the flight

Overrides §2.3's "do not touch it for the full 10 days". That rule protects
*bid learning*, and no amount of bid learning fixes a product that loses 92%
of users before the ad gate. §2.2b is the precedent: it refused to launch on
1.0.6 because *buying installs onto a build with a defect means paying to show
people the defect*. Saves ≈E£4,800 of the flight and costs nothing — the
112-user cohort keeps ageing for free. Directly serves the budget red line.

### Shipped 1.0.9 with two changes

**Ads from level 1.** `adsFromLevel` 4 → 1, `interstitialFromLevel` 4 → 2.
The three-level ad-free onboarding was protecting a stretch of the game
players do not survive. The banner is passive; the first level a player
finishes still ends without a full-screen ad.

**A door out after three losses.** `SKIP THIS PICTURE` on the fail card,
appearing after 3 consecutive losses on the same board — the moment of highest
intent and the game's largest exit. Plays a rewarded ad when inventory exists,
**grants the skip either way**. Recorded as skipped, not completed, so the
menu's check marks and `completedCount` stay honest; solving it later promotes
it to a real completion.

`ProgressStore` gained a skipped-level set plus a two-key "current run of
losses" (which board, how many) rather than a per-level history — the only
question is whether the player is stuck on the board in front of them right
now. Persisted rather than held in the widget, because every retry builds a
fresh `GameScreen` and because a player who quits in frustration should still
be offered the way out when they return.

Also: the fail card now re-checks once for late rewarded inventory instead of
silently never showing the offer, and a new `level_skipped` event carries the
loss count so the threshold of 3 can be tuned against data.

## 3. Judgement calls, and why

**The skip is free when no ad is available.** A player refused after three
defeats churns, and a churned player earns nothing. The ad is the upside, not
the toll. The wording changes with inventory so the card never promises an ad
it cannot show.

**The back-button exit was left alone.** It is real unserved inventory — a
finished board pops with no ad on a single back press — but "double-back is
deliberately left alone" is a recorded decision. Not mine to reverse at 4am.

**Levels 1–5 were NOT eased.** The obvious reading of "36 of 70 lose level 1"
is that the early levels are too hard. But levels 1–4 are already at the
generator's floor: 15×15 grid, 5 colours, the bottom of the ramp. The wall is
the *mechanic* — bottles starve, slots jam — not the grid size. Regenerating
art would have burned a long solver run to change nothing, and risked the
solvability proofs on a night with nobody awake to catch it. A tutorial or a
more forgiving early jam rule is the real fix, and it is a design change to
make awake. The skip offer is the safety valve until then.

**No in-app review prompt.** It is on the plan's §4 list and ratings feed ASO,
but it needs a new native dependency that cannot be verified on a device
tonight. Deliberately deferred rather than shipped blind.

**iOS was not submitted for review.** App Store Connect had logged out, and
entering credentials is off-limits. That turned out to be the safe outcome
anyway: **1.0.7 has been Waiting for Review since 1 Sep**, and pulling it to
submit 1.0.9 would have forfeited a queue position on a platform with no
users yet. The binary is uploaded and waiting; submitting it is one click
whenever iOS 1.0.7 is through.

## 4. Verification before shipping

- `flutter analyze lib/ test/ tool/` — clean
- `flutter test` — **85/85** (14 new, covering the skip bookkeeping and the
  fail card's offers)
- `COLORO_FULL_SWEEP=1 flutter test test/stall_diagnostic_test.dart` —
  **303/303**, the documented release gate. No level data was changed.

## 5. Open for Ahmed

1. **AdMob bank details** — identity verified and payout threshold reached,
   but nothing can actually be paid out without them. This is money already
   earned sitting still.
2. **Unity payout profile** — same.
3. **Host the Coloro privacy policy** — Play still points at the generic
   Megz-wide one (see the data-safety session record).
4. **Submit iOS 1.0.9** once 1.0.7 is through review.
5. **Flight 2 restarts only when `finish_level_5` clears 15% of installs on
   organic traffic.** Same creative — the 9.2% CTR was never the problem.
