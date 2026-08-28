import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/models/level_result.dart';
import '../domain/models/paint_bottle.dart';
import '../domain/models/pixel_grid.dart';
import 'drain_order.dart';
import 'game_events.dart';

enum GamePhase { playing, complete, failed }

/// Where a slot's bottle currently is.
enum SlotPhase {
  /// Flying from the tray into the slot (UI-driven).
  arriving,

  /// Docked in its slot, drinking matching pixels off the bottom edge.
  docked,
}

/// A bottle docked in a machine slot. It never leaves the slot — it pops
/// there when full.
class SlotBottle {
  SlotBottle(this.bottle) : remaining = bottle.capacity;

  final PaintBottle bottle;
  int remaining;
  SlotPhase phase = SlotPhase.arriving;

  /// True while no column's bottom pixel matches this bottle's color.
  bool starving = false;

  /// Fractional pixel budget accumulated from the fill rate.
  double budget = 0;

  /// Time of the most recent take — drives the little working buzz.
  double lastSprayAt = -10;
}

/// Pure game simulation — BOTTOM-DRAIN rules.
///
/// The full-square picture starts complete. Docked bottles continuously
/// drink pixels from the picture's BOTTOM EDGE only: for each column, just
/// the lowest remaining pixel is reachable. A bottle always takes the
/// deepest matching pixel available, breaking ties by [DrainOrder], so the
/// picture drains row by row from the bottom up and a color buried above
/// other colors cannot be reached until they're drunk first.
///
/// A docked bottle whose color shows nowhere on the bottom edge STARVES
/// (red "!"). When every slot holds a starving bottle for a moment, the
/// machine fails.
///
/// No Flutter widgets — fully unit-testable. Visual concerns are driven
/// through [GameEvent]s; the screen calls [cellArrived]/[slotArrived] when
/// animations land.
class GameController extends ChangeNotifier {
  GameController({
    required this.grid,
    required List<PaintBottle> bottles,
    this.slotCount = 4,
    this.columnCount = 4,
    this.fillRate = 7.0,
    // Kept for call-site stability; the drain order is fully deterministic.
    // ignore: avoid_unused_constructor_parameters
    int seed = 0,
  }) {
    // Deal bottles round-robin into tray columns.
    tray = List.generate(columnCount, (_) => <PaintBottle>[]);
    for (var i = 0; i < bottles.length; i++) {
      tray[i % columnCount].add(bottles[i]);
    }
    slots = List<SlotBottle?>.filled(slotCount, null, growable: true);
    cellFilledAt = List<double>.filled(grid.cells.length, -1);
    _taken = List<bool>.filled(grid.cells.length, false);
  }

  final PixelGrid grid;
  final int slotCount;
  final int columnCount;

  /// Pixels per second a docked bottle drinks while matches exist.
  final double fillRate;

  late final List<List<PaintBottle>> tray;
  late final List<SlotBottle?> slots;

  /// Logically collected cells.
  late final List<bool> _taken;

  /// Game-clock timestamp when each cell's pixel was collected (-1 = still
  /// on the board). The painter uses this for the shrink-away animation.
  late final List<double> cellFilledAt;

  GamePhase phase = GamePhase.playing;
  double time = 0;
  int visualFilled = 0;
  double _jamTimer = 0;

  /// Fine-grained progress channel (0..1). Updated on every collected pixel
  /// so only the HUD progress widgets rebuild — the broad [ChangeNotifier]
  /// fires solely on structural changes (tray/slot contents).
  final ValueNotifier<double> progress01 = ValueNotifier(0);

  /// Seconds of total starvation before the machine jams for good.
  static const jamGrace = 1.4;

  void Function(GameEvent event)? onEvent;

  double get progress =>
      grid.fillableCount == 0 ? 1 : visualFilled / grid.fillableCount;

  bool get hasFreeSlot => slots.any((s) => s == null);

  /// The lowest remaining pixel of [column], or null when it's drained.
  int? bottomCellOf(int column) {
    for (var y = grid.rows - 1; y >= 0; y--) {
      final i = y * grid.cols + column;
      if (grid.cells[i] >= 0 && !_taken[i]) return i;
    }
    return null;
  }

  /// Number of columns whose bottom-edge pixel is [colorIndex] — the work
  /// available to a bottle of that color right now.
  int takableCountFor(int colorIndex) {
    var count = 0;
    for (var x = 0; x < grid.cols; x++) {
      final cell = bottomCellOf(x);
      if (cell != null && grid.cells[cell] == colorIndex) count++;
    }
    return count;
  }

  /// Kept as an alias — "exposed" means "on the bottom edge".
  int exposedCountFor(int colorIndex) => takableCountFor(colorIndex);

  // ---------------------------------------------------------------------------
  // Player actions
  // ---------------------------------------------------------------------------

  /// Player tapped the front bottle of [column]. Returns true on success.
  bool launchFromColumn(int column) {
    if (phase != GamePhase.playing) return false;
    if (column < 0 || column >= tray.length) return false;
    final columnBottles = tray[column];
    if (columnBottles.isEmpty) return false;

    final slotIndex = slots.indexWhere((s) => s == null);
    if (slotIndex == -1) {
      onEvent?.call(LaunchRefused(column));
      return false;
    }

    final bottle = columnBottles.removeAt(0);
    slots[slotIndex] = SlotBottle(bottle);
    onEvent?.call(BottleLaunched(bottle, column, slotIndex));
    notifyListeners();
    return true;
  }

  /// Hard ceiling on slots earned through rewarded ads. Past this the jam is
  /// final and the level must be replayed — an unbounded rescue would let any
  /// level be brute-forced by watching ads, which removes the puzzle.
  static const maxSlots = 8;

  /// Rewarded-ad rescue: hands the machine one extra slot and lifts the
  /// jam so play continues from exactly where it stopped. More slots can
  /// only make a level easier, so a level's solvability proof still holds.
  ///
  /// Repeatable: each loss may be rescued again until [maxSlots] is reached.
  void grantExtraSlotAndResume() {
    if (!canEarnExtraSlot) return;
    slots.add(null);
    _jamTimer = 0;
    if (phase == GamePhase.failed) phase = GamePhase.playing;
    notifyListeners();
  }

  /// Whether another rewarded rescue may still be offered on this attempt.
  bool get canEarnExtraSlot => slots.length < maxSlots;

  /// How many slots the machine currently has, base plus rescues.
  int get activeSlotCount => slots.length;

  /// The fly-to-slot animation finished; the bottle starts drinking.
  void slotArrived(int slotIndex) {
    final slot = slots[slotIndex];
    if (slot == null || slot.phase != SlotPhase.arriving) return;
    slot.phase = SlotPhase.docked;
  }

  // ---------------------------------------------------------------------------
  // Simulation
  // ---------------------------------------------------------------------------

  /// Advances the simulation by [dt] seconds.
  void tick(double dt) {
    // The clock keeps running after completion/failure so landing-pop
    // animations still play out; only the gameplay below stops.
    time += dt;
    if (phase != GamePhase.playing) return;

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot == null || slot.phase != SlotPhase.docked) continue;
      _drink(i, slot, dt);
    }

    _checkMachineJam(dt);
  }

  void _drink(int slotIndex, SlotBottle slot, double dt) {
    final color = slot.bottle.colorIndex;

    // Columns whose bottom pixel matches this bottle right now, paired
    // with the row that pixel sits in.
    final matches = <({int column, int row})>[];
    for (var x = 0; x < grid.cols; x++) {
      final cell = bottomCellOf(x);
      if (cell != null && grid.cells[cell] == color) {
        matches.add((column: x, row: cell ~/ grid.cols));
      }
    }

    if (matches.isEmpty) {
      if (!slot.starving) {
        slot.starving = true;
        slot.budget = 0;
        onEvent?.call(SlotStuckChanged(slotIndex, true));
        notifyListeners();
      }
      return;
    }
    if (slot.starving) {
      slot.starving = false;
      onEvent?.call(SlotStuckChanged(slotIndex, false));
      notifyListeners();
    }

    slot.budget = math.min(3, slot.budget + fillRate * dt);
    while (slot.budget >= 1 && slot.remaining > 0 && matches.isNotEmpty) {
      slot.budget -= 1;

      // SEQUENTIAL erase: always take the lowest remaining row first, so
      // the picture still drains row by row from the bottom up. WITHIN that
      // row the column is chosen by [DrainOrder] — scattered rather than a
      // left-to-right sweep, and identical to what the solver proved.
      var deepest = matches[0].row;
      for (var k = 1; k < matches.length; k++) {
        if (matches[k].row > deepest) deepest = matches[k].row;
      }
      final candidates = <int>[
        for (final m in matches)
          if (m.row == deepest) m.column,
      ];
      final column = DrainOrder.pick(candidates);
      final pick = matches.indexWhere((m) => m.column == column);

      // Exactly ONE pixel per take: the column's bottom cell.
      final cell = bottomCellOf(column);
      if (cell == null || grid.cells[cell] != color) {
        matches.removeAt(pick);
        continue;
      }

      _taken[cell] = true;
      slot.remaining--;
      slot.lastSprayAt = time;
      onEvent?.call(CellFillStarted(cell, color, slotIndex));

      if (slot.remaining == 0) {
        // Pops in its slot, freeing it.
        slots[slotIndex] = null;
        onEvent?.call(BottleEmptied(slotIndex, color));
        notifyListeners();
        return;
      }
      // The column's edge changed; refresh this column's match entry.
      final newBottom = bottomCellOf(column);
      if (newBottom == null || grid.cells[newBottom] != color) {
        matches.removeAt(pick);
      } else {
        matches[pick] = (column: column, row: newBottom ~/ grid.cols);
      }
    }
  }

  /// Fail state: every slot is occupied by a docked bottle with nothing to
  /// drink, and it stays that way past a short grace — nothing can ever
  /// change, because no slot is free for a workable tray bottle.
  void _checkMachineJam(double dt) {
    if (phase != GamePhase.playing) return;
    var jammed = true;
    for (final s in slots) {
      if (s == null || s.phase == SlotPhase.arriving || !s.starving) {
        jammed = false;
        break;
      }
    }
    if (!jammed) {
      _jamTimer = 0;
      return;
    }
    _jamTimer += dt;
    if (_jamTimer >= jamGrace) {
      phase = GamePhase.failed;
      onEvent?.call(const LevelFailed());
      notifyListeners();
    }
  }

  /// The collect animation for [cellIndex] started; the cell is visibly
  /// gone. Deliberately does NOT notifyListeners — collecting ~dozens of
  /// pixels/second must not rebuild the tray/slots; painters read state per
  /// frame and the HUD listens to [progress01].
  void cellArrived(int cellIndex) {
    if (cellFilledAt[cellIndex] >= 0) return;
    cellFilledAt[cellIndex] = time;
    visualFilled++;
    progress01.value = progress;

    if (visualFilled >= grid.fillableCount && phase == GamePhase.playing) {
      phase = GamePhase.complete;
      onEvent?.call(LevelCompleted(LevelResult(elapsedSeconds: time)));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    progress01.dispose();
    super.dispose();
  }
}
