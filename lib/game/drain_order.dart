/// Which bottom-edge cell a docked bottle drinks next.
///
/// The rule the game is built on: a bottle may only take the **lowest
/// remaining pixel of a column**, and it always takes the deepest one
/// available. What this file owns is the *tie-break* — which of the equally
/// deep matching columns it reaches for — and it exists so that the live
/// [GameController] and the solvability solver in `bottle_factory.dart`
/// call literally the same function. The winning line the solver proves is
/// therefore the winning line the player gets.
///
/// ## Why this is still leftmost
///
/// Playtesting asked for the drain to pick a scattered column within a row
/// instead of sweeping strictly left to right. That was implemented and
/// measured against the whole shipped campaign with
/// `tool/reproof_deals.dart`, which re-searches each level's
/// (shuffleWindow, dealSeed) pair over the same space `tool/gen_levels.dart`
/// searches — 40 seeds per window, every window down to 1:
///
/// | tie-break                        | levels left unwinnable |
/// |----------------------------------|------------------------|
/// | leftmost (shipped)               | 0 / 300                |
/// | scattered per (level, row)       | 71 / 300               |
/// | scattered per level              | 77 / 300               |
///
/// The failures are not a seed that needs re-rolling: at window 1 the deal
/// *is* the solver's own witness order, so a level failing there means the
/// greedy witness cannot beat the board at all under the new rule. The
/// campaign's 300 proofs are genuinely coupled to this tie-break, and a
/// quarter of the game would ship unwinnable.
///
/// Making the drain scattered therefore requires regenerating the levels
/// (`dart run tool/gen_levels.dart`), which re-derives art *and* deals
/// together — not a seed patch. Until that happens the tie-break stays
/// leftmost, and the scattered *look* is carried by the collect animation
/// instead, which has no effect on the simulation.
///
/// Anything changed here changes every shipped level's solvability proof.
/// Re-run `COLORO_FULL_SWEEP=1 flutter test test/stall_diagnostic_test.dart`
/// (or `tool/reproof_deals.dart`) before believing otherwise.
abstract final class DrainOrder {
  /// Picks one column out of [candidates] — all of which have a matching
  /// pixel on the same deepest remaining row.
  ///
  /// [candidates] is non-empty and in ascending column order.
  static int pick(List<int> candidates) => candidates.first;
}
