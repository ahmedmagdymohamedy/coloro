import 'dart:math' as math;

import '../domain/models/paint_bottle.dart';
import '../domain/models/pixel_grid.dart';
import '../game/drain_order.dart';

/// Builds the bottle supply for a level and — crucially — the ORDER it is
/// dealt into the tray.
///
/// The tray is deliberately shuffled so the bottle you need next is rarely
/// at the front of a column: the player must read the picture, park
/// not-yet-useful bottles in slots, and keep at least one slot breathing.
/// Shuffling naively makes levels unwinnable, so the level generator picks
/// a `dealSeed` / `shuffleWindow` pair that [isDealSolvable] proves can be
/// beaten, and the runtime simply reproduces that exact deal.
abstract final class BottleFactory {
  static const chunkSizes = [40, 30, 20, 15, 12, 10, 8, 6];
  static const slotCount = 4;
  static const columnCount = 4;

  /// The deal, flattened. The controller deals it round-robin into the
  /// tray columns, so index i lands in column `i % columnCount`.
  static List<PaintBottle> build(
    PixelGrid grid, {
    int seed = 0,
    int shuffleWindow = 1,
    int dealSeed = 0,
  }) {
    final base = _baseOrder(grid, _chunk(grid, seed), seed);
    if (shuffleWindow <= 1) return base;
    return _windowShuffle(base, shuffleWindow, math.Random(dealSeed));
  }

  /// True when a winning line of play exists for this exact deal, under the
  /// real constraints: only the 4 column fronts are reachable, 5 slots, a
  /// docked bottle occupies its slot until it drinks its full capacity.
  static bool isDealSolvable(
    PixelGrid grid,
    List<PaintBottle> deal, {
    int maxNodes = 120000,
  }) => _Solver(grid, deal).solve(maxNodes);

  /// The dock order of a proven winning line for [deal], or null when the
  /// search exhausts [maxNodes]. Returns the same [PaintBottle] instances
  /// as [deal], so callers can match by [PaintBottle.id]. Exists for the
  /// promo-video generator, which has to replay a legal winning game on
  /// camera; gameplay never calls it.
  static List<PaintBottle>? solveDealOrder(
    PixelGrid grid,
    List<PaintBottle> deal, {
    int maxNodes = 800000,
  }) => _Solver(grid, deal).winningOrder(maxNodes);

  // ---------------------------------------------------------------------------
  // Supply
  // ---------------------------------------------------------------------------

  static List<PaintBottle> _chunk(PixelGrid grid, int seed) {
    final random = math.Random(seed);
    final bottles = <PaintBottle>[];
    var id = 0;
    for (var color = 0; color < grid.palette.length; color++) {
      final total = grid.colorCounts[color];
      // A bottle holds its slot until it fills up, so a big bottle for a
      // thinly-spread colour is a slot hostage. The cap came down from 40
      // when the fixed palette landed: merging near-identical colours makes
      // each surviving colour's cell count larger, which under the old
      // formula produced 40-capacity bottles that sat in a slot starving.
      // Smaller bottles turn over faster and keep the machine breathing.
      final maxChunk = math.max(6, math.min(20, (total / 4).round()));
      var remaining = total;
      while (remaining > 0) {
        final int capacity;
        if (remaining <= 8) {
          capacity = remaining; // no dangling 2-pixel bottles
        } else {
          final options = chunkSizes
              .where(
                (s) => s <= maxChunk && (s <= remaining - 6 || s == remaining),
              )
              .toList();
          capacity = options.isEmpty
              ? math.min(remaining, maxChunk)
              : options[random.nextInt(options.length)];
        }
        bottles.add(
          PaintBottle(id: id++, colorIndex: color, capacity: capacity),
        );
        remaining -= capacity;
      }
    }
    return bottles;
  }

  /// A known-feasible baseline order: the dock order of a slot-constrained
  /// greedy solve (see [_Solver.witnessOrder]). Shuffling perturbs THIS.
  /// Memoised because the baseline depends only on the board and the
  /// chunking seed — never on `shuffleWindow` or `dealSeed`. The level
  /// generator and `tool/reproof_deals.dart` both call [build] dozens of
  /// times per level while searching for a deal, and without this the
  /// (occasionally expensive) solver fallback below would be redone on
  /// every one of those attempts.
  ///
  /// Keyed by the grid *object* via an [Expando] rather than by a hash of
  /// its contents. A content hash can collide, and a collision here would
  /// silently hand back a base order computed for a different board — a
  /// deal that does not match the level being played. An Expando cannot
  /// collide and needs no eviction: entries die with the grid.
  static final Expando<Map<int, List<PaintBottle>>> _baseCache = Expando();

  static List<PaintBottle> _baseOrder(
    PixelGrid grid,
    List<PaintBottle> bottles,
    int seed,
  ) {
    final perGrid = _baseCache[grid] ??= <int, List<PaintBottle>>{};
    final cached = perGrid[seed];
    if (cached != null) return cached;

    // Greedy is cheap and succeeds on most boards.
    var order = _Solver(grid, bottles).witnessOrder();
    // It failed, so search for a real winning line rather than falling back
    // to the colour-sorted deal, which is almost never winnable.
    order ??= _Solver(grid, bottles).winningOrder();

    return perGrid[seed] = order ?? bottles;
  }

  /// Permutes the order within sliding windows of [window] bottles, so a
  /// bottle can drift at most ~window places from where it is needed.
  static List<PaintBottle> _windowShuffle(
    List<PaintBottle> order,
    int window,
    math.Random rnd,
  ) {
    final out = List<PaintBottle>.from(order);
    for (var start = 0; start < out.length; start += window) {
      final end = math.min(start + window, out.length);
      final slice = out.sublist(start, end)..shuffle(rnd);
      out.setRange(start, end, slice);
    }
    return out;
  }
}

/// Slot-constrained search over the real game.
///
/// The board is fully described by how many cells each column has drunk
/// (the drain is strictly bottom-up per column), which makes states small
/// enough to memoize.
class _Solver {
  _Solver(this.grid, this.deal)
    : cols = grid.cols,
      rows = grid.rows,
      drunk = List<int>.filled(grid.cols, 0),
      colPtr = List<int>.filled(BottleFactory.columnCount, 0),
      slots = List<_Docked?>.filled(BottleFactory.slotCount, null) {
    // The tray, as the controller deals it.
    tray = List.generate(BottleFactory.columnCount, (_) => <PaintBottle>[]);
    for (var i = 0; i < deal.length; i++) {
      tray[i % BottleFactory.columnCount].add(deal[i]);
    }
    cellsLeft = grid.fillableCount;
  }

  final PixelGrid grid;
  final List<PaintBottle> deal;
  final int cols, rows;

  late final List<List<PaintBottle>> tray;
  final List<int> drunk;
  final List<int> colPtr;
  final List<_Docked?> slots;
  late int cellsLeft;

  final Set<String> _seen = {};
  int _nodes = 0;

  int _colorAtBottom(int x) {
    if (drunk[x] >= rows) return -1;
    return grid.cells[(rows - 1 - drunk[x]) * cols + x];
  }

  /// The column the runtime would drink from: deepest remaining row (i.e.
  /// fewest cells drunk), then [DrainOrder] among the ties — the identical
  /// rule `GameController._drink` uses, which is what makes this a proof
  /// about the real game rather than about a simplified model of it.
  int? _pickColumn(int color) {
    var bestDrunk = 1 << 30;
    for (var x = 0; x < cols; x++) {
      if (_colorAtBottom(x) != color) continue;
      if (drunk[x] < bestDrunk) bestDrunk = drunk[x];
    }
    if (bestDrunk == 1 << 30) return null;
    final candidates = <int>[
      for (var x = 0; x < cols; x++)
        if (_colorAtBottom(x) == color && drunk[x] == bestDrunk) x,
    ];
    return DrainOrder.pick(candidates);
  }

  int _takableFor(int color) {
    var n = 0;
    for (var x = 0; x < cols; x++) {
      if (_colorAtBottom(x) == color) n++;
    }
    return n;
  }

  /// Advances the deterministic drinking until a slot frees (a bottle
  /// filled up) or every docked bottle starves. Returns the list of
  /// (slotIndex, cellsDrunkPerColumn) undo info.
  _SimResult _advance(List<_Step> journal) {
    while (true) {
      var progressed = false;
      for (var s = 0; s < slots.length; s++) {
        final b = slots[s];
        if (b == null) continue;
        final x = _pickColumn(b.color);
        if (x == null) continue;
        drunk[x]++;
        cellsLeft--;
        b.remaining--;
        journal.add(_Step.drink(s, x));
        progressed = true;
        if (cellsLeft == 0) return _SimResult.solved;
        if (b.remaining == 0) {
          slots[s] = null;
          journal.add(_Step.pop(s, b.color));
          return _SimResult.slotFreed;
        }
      }
      if (!progressed) return _SimResult.stalled;
    }
  }

  void _undo(List<_Step> journal, int mark) {
    for (var i = journal.length - 1; i >= mark; i--) {
      final st = journal[i];
      switch (st.kind) {
        case _StepKind.drink:
          drunk[st.column]--;
          cellsLeft++;
          slots[st.slot]!.remaining++;
        case _StepKind.pop:
          slots[st.slot] = _Docked(st.poppedColor, 0);
        case _StepKind.dock:
          slots[st.slot] = null;
          colPtr[st.column]--;
      }
    }
    journal.removeRange(mark, journal.length);
  }

  String _key() {
    final b = StringBuffer();
    for (final d in drunk) {
      b
        ..write(d)
        ..write(',');
    }
    b.write('|');
    for (final p in colPtr) {
      b
        ..write(p)
        ..write(',');
    }
    b.write('|');
    final occupied = <String>[];
    for (final s in slots) {
      if (s != null) occupied.add('${s.color}:${s.remaining}');
    }
    occupied.sort();
    b.write(occupied.join(';'));
    return b.toString();
  }

  bool solve(int maxNodes) {
    _nodes = 0;
    return _search(maxNodes, <_Step>[]);
  }

  bool _search(int maxNodes, List<_Step> journal) {
    if (_nodes++ > maxNodes) return false;

    final mark = journal.length;
    // Advance to the next decision point: a bottle filling up frees a slot,
    // or everything docked starves. A real player may dock the instant a
    // slot opens, so BOTH are branch points.
    final result = _advance(journal);
    if (result == _SimResult.solved) return true;

    final key = _key();
    if (!_seen.add(key)) {
      _undo(journal, mark);
      return false;
    }

    // Option A — dock one of the reachable column fronts.
    if (slots.contains(null)) {
      final order = <int>[];
      for (var c = 0; c < tray.length; c++) {
        if (colPtr[c] < tray[c].length) order.add(c);
      }
      order.sort((a, b) {
        final ba = tray[a][colPtr[a]], bb = tray[b][colPtr[b]];
        final ta = _takableFor(ba.colorIndex), tb = _takableFor(bb.colorIndex);
        if (ta != tb) return tb.compareTo(ta);
        return ba.capacity.compareTo(bb.capacity);
      });

      for (final c in order) {
        final slotIndex = slots.indexOf(null);
        if (slotIndex == -1) break;
        final bottle = tray[c][colPtr[c]];
        slots[slotIndex] = _Docked(bottle.colorIndex, bottle.capacity);
        colPtr[c]++;
        journal.add(_Step.dock(slotIndex, c, bottle));
        if (_search(maxNodes, journal)) return true;
        _undo(journal, journal.length - 1);
      }
    }

    // Option B — dock nothing and let the machine keep running. Only
    // meaningful when something can still drink.
    if (result == _SimResult.slotFreed) {
      if (_search(maxNodes, journal)) return true;
    }

    _undo(journal, mark);
    return false;
  }

  /// The dock order of a full backtracking solve.
  ///
  /// [witnessOrder] is greedy and gives up the moment its heuristic picks
  /// wrong, which on some boards happens even though a winning line plainly
  /// exists. Falling back from a failed greedy straight to the raw
  /// colour-sorted deal produced levels nothing could beat; this searches
  /// properly and hands back a line that provably wins.
  List<PaintBottle>? winningOrder([int maxNodes = 200000]) {
    _nodes = 0;
    final journal = <_Step>[];
    if (!_search(maxNodes, journal)) return null;
    final order = <PaintBottle>[
      for (final st in journal)
        if (st.kind == _StepKind.dock && st.bottle != null) st.bottle!,
    ];
    final seen = {for (final b in order) b.id};
    order.addAll(deal.where((b) => !seen.contains(b.id)));
    return order.length == deal.length ? order : null;
  }

  /// Greedy (no backtracking) solve that records the dock order — used as
  /// the feasible baseline the shuffle perturbs. Null when greedy fails.
  List<PaintBottle>? witnessOrder() {
    final undocked = List<PaintBottle>.from(deal);
    final order = <PaintBottle>[];
    final journal = <_Step>[];

    while (cellsLeft > 0) {
      final result = _advance(journal);
      if (result == _SimResult.solved) break;

      final slotIndex = slots.indexWhere((s) => s == null);
      if (slotIndex == -1) {
        if (result == _SimResult.slotFreed) continue;
        return null; // every slot holds a starving bottle
      }
      if (undocked.isEmpty) {
        if (result == _SimResult.slotFreed) continue;
        return null;
      }

      // Dock the most useful bottle whose color has spare bottom-edge work.
      PaintBottle? best;
      var bestScore = 0;
      for (final b in undocked) {
        final t = _takableFor(b.colorIndex);
        if (t == 0) continue;
        var docked = 0;
        for (final s in slots) {
          if (s != null && s.color == b.colorIndex) docked += s.remaining;
        }
        final spare = t - docked;
        if (spare <= 0) continue;
        if (spare > bestScore) {
          bestScore = spare;
          best = b;
        }
      }
      if (best == null) {
        if (result == _SimResult.slotFreed) continue;
        return null;
      }
      undocked.remove(best);
      order.add(best);
      slots[slotIndex] = _Docked(best.colorIndex, best.capacity);
    }

    order.addAll(undocked);
    return order;
  }
}

enum _SimResult { solved, slotFreed, stalled }

enum _StepKind { drink, pop, dock }

class _Step {
  _Step.drink(this.slot, this.column)
    : kind = _StepKind.drink,
      poppedColor = -1,
      bottle = null;
  _Step.pop(this.slot, this.poppedColor)
    : kind = _StepKind.pop,
      column = -1,
      bottle = null;
  _Step.dock(this.slot, this.column, [this.bottle])
    : kind = _StepKind.dock,
      poppedColor = -1;

  final _StepKind kind;
  final int slot;
  final int column;
  final int poppedColor;

  /// Only set on dock steps — lets [_Solver.winningOrder] read the dock
  /// sequence straight back out of a successful search.
  final PaintBottle? bottle;
}

class _Docked {
  _Docked(this.color, this.remaining);

  final int color;
  int remaining;
}
