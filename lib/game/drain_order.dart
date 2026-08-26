/// Which bottom-edge cell a docked bottle drinks next.
///
/// The rule the game is built on never changes: a bottle may only take the
/// **lowest remaining pixel of a column**, and it always takes the deepest
/// one available. What this file decides is the *tie-break* — which of the
/// equally-deep matching columns it reaches for.
///
/// That used to be "the leftmost one", which made every row erase itself as
/// a strict left-to-right typewriter sweep. Playtesting called it out
/// directly: it should drain from a row in a scattered order, not always
/// left to right.
///
/// The tie-break is therefore scattered — but it is **not random**. It is a
/// pure function of `(candidates, levelSeed, row)`:
///
///  * the live [GameController] and the solvability solver in
///    `bottle_factory.dart` both call this one function, so the winning line
///    the solver proves is the winning line the player actually gets;
///  * it depends only on board state, never on call order, so the two
///    simulations agree even though they interleave their slots
///    differently;
///  * it is stable per level, so replaying a level drains it the same way.
///
/// Anything that changes here changes every shipped level's solvability
/// proof, so `test/stall_diagnostic_test.dart` re-proves the campaign
/// against it.
abstract final class DrainOrder {
  /// Picks one column out of [candidates] — all of which have a matching
  /// pixel on the same [row], the deepest row still available.
  ///
  /// [candidates] must be non-empty and in ascending column order.
  static int pick(List<int> candidates, int levelSeed, int row) {
    if (candidates.length == 1) return candidates.first;
    // EXPERIMENT 2: per-level, row-independent ordering.
    return candidates[_mix(levelSeed, 0) % candidates.length];
  }

  /// A cheap integer hash (splitmix-style finalizer). Returns a
  /// non-negative value so the `%` above is always a valid index.
  static int _mix(int levelSeed, int row) {
    var x = (levelSeed * 0x9E3779B1) ^ ((row + 1) * 0x85EBCA6B);
    x &= 0x3FFFFFFF;
    x ^= x >> 15;
    x = (x * 0x2545F491) & 0x3FFFFFFF;
    x ^= x >> 13;
    return x & 0x3FFFFFFF;
  }
}
