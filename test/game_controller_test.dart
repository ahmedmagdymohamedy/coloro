import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/domain/models/paint_bottle.dart';
import 'package:coloro/domain/models/pixel_grid.dart';
import 'package:coloro/game/game_controller.dart';
import 'package:coloro/game/game_events.dart';
import 'package:flutter_test/flutter_test.dart';

PixelGrid tinyGrid() {
  // 6x4 board, fully paintable: rows 0-1 color 0 (top), rows 2-3 color 1
  // (bottom) — color 0 is blocked until color 1 drains.
  final cells = [
    ...List.filled(12, 0),
    ...List.filled(12, 1),
  ];
  return PixelGrid(
    cols: 6,
    rows: 4,
    cells: cells,
    palette: [0xFFFF0000, 0xFF00FF00],
  );
}

/// Wires instant animation callbacks so the pure simulation can run solo.
void autopilot(GameController controller,
    {void Function(GameEvent e)? also}) {
  controller.onEvent = (e) {
    if (e is CellFillStarted) controller.cellArrived(e.cellIndex);
    if (e is BottleLaunched) controller.slotArrived(e.slotIndex);
    also?.call(e);
  };
}

void main() {
  group('GameController bottom-drain', () {
    test('full playthrough completes the level', () {
      final grid = tinyGrid();
      final controller = GameController(
        grid: grid,
        bottles: BottleFactory.build(grid, seed: 1),
        fillRate: 40,
      );
      final launched = <CellFillStarted>[];
      LevelCompleted? completed;
      autopilot(controller, also: (e) {
        if (e is CellFillStarted) launched.add(e);
        if (e is LevelCompleted) completed = e;
      });

      var safety = 5000;
      while (completed == null && safety-- > 0) {
        for (var c = 0; c < controller.tray.length; c++) {
          controller.launchFromColumn(c);
        }
        controller.tick(0.05);
      }

      expect(completed, isNotNull);
      expect(launched.length, grid.fillableCount);
      expect(controller.visualFilled, grid.fillableCount);
      expect(controller.phase, GamePhase.complete);
      expect(completed!.result.elapsedSeconds, greaterThan(0));
    });

    test('every take is the bottommost remaining pixel of its column', () {
      final grid = PixelGrid(
        cols: 5,
        rows: 5,
        cells: List.filled(25, 0),
        palette: [0xFFFF0000],
      );
      final controller = GameController(
        grid: grid,
        bottles: const [PaintBottle(id: 0, colorIndex: 0, capacity: 25)],
        slotCount: 1,
        fillRate: 60,
      );
      final taken = <int>{};
      var violations = 0;
      controller.onEvent = (e) {
        if (e is BottleLaunched) controller.slotArrived(e.slotIndex);
        if (e is CellFillStarted) {
          final x = e.cellIndex % 5, y = e.cellIndex ~/ 5;
          // Everything below this cell in its column must already be taken.
          for (var yy = y + 1; yy < 5; yy++) {
            if (!taken.contains(yy * 5 + x)) violations++;
          }
          taken.add(e.cellIndex);
          controller.cellArrived(e.cellIndex);
        }
      };

      controller.launchFromColumn(0);
      for (var i = 0; i < 100; i++) {
        controller.tick(0.05);
      }
      expect(taken.length, greaterThan(10));
      expect(violations, 0,
          reason: 'pixels may only be drunk from the bottom edge');
    });

    test('erases row by row: never digs above the deepest remaining row',
        () {
      // Single color, so every column is always a match — only the row
      // ordering decides what gets taken.
      const cols = 6, rows = 6;
      final grid = PixelGrid(
        cols: cols,
        rows: rows,
        cells: List.filled(cols * rows, 0),
        palette: [0xFFFF0000],
      );
      final controller = GameController(
        grid: grid,
        bottles: const [PaintBottle(id: 0, colorIndex: 0, capacity: 36)],
        slotCount: 1,
        fillRate: 60,
      );
      final taken = <int>{};
      var violations = 0;

      int deepestRemaining() {
        for (var y = rows - 1; y >= 0; y--) {
          for (var x = 0; x < cols; x++) {
            if (!taken.contains(y * cols + x)) return y;
          }
        }
        return -1;
      }

      controller.onEvent = (e) {
        if (e is BottleLaunched) controller.slotArrived(e.slotIndex);
        if (e is CellFillStarted) {
          final row = e.cellIndex ~/ cols;
          // Strictly one pixel at a time, always from the deepest row that
          // still has cells — no skipping ahead.
          if (row != deepestRemaining()) violations++;
          taken.add(e.cellIndex);
          controller.cellArrived(e.cellIndex);
        }
      };

      controller.launchFromColumn(0);
      for (var i = 0; i < 100; i++) {
        controller.tick(0.05);
      }
      expect(taken.length, cols * rows);
      expect(violations, 0,
          reason: 'pixels must be erased in bottom-up row sequence');
    });

    test('refuses launch when all slots are full', () {
      final grid = tinyGrid();
      final bottles = [
        for (var i = 0; i < 10; i++)
          PaintBottle(id: i, colorIndex: i.isEven ? 0 : 1, capacity: 2),
      ];
      final controller = GameController(
        grid: grid,
        bottles: bottles,
        slotCount: 2,
      );
      var refused = 0;
      controller.onEvent = (e) {
        if (e is LaunchRefused) refused++;
      };

      expect(controller.launchFromColumn(0), isTrue);
      expect(controller.launchFromColumn(1), isTrue);
      expect(controller.launchFromColumn(2), isFalse);
      expect(refused, 1);
    });

    test('a color above another shows no bottom-edge work', () {
      final controller = GameController(grid: tinyGrid(), bottles: const []);
      // Bottom rows are color 1; color 0 sits above them.
      expect(controller.takableCountFor(1), 6);
      expect(controller.takableCountFor(0), 0);
    });

    test('a starving bottle jams; total starvation fails the level', () {
      final controller = GameController(
        grid: tinyGrid(),
        // Color 0 is on top — unreachable until color 1 drains.
        bottles: const [PaintBottle(id: 0, colorIndex: 0, capacity: 12)],
        slotCount: 1,
      );
      final events = <GameEvent>[];
      controller.onEvent = events.add;

      controller.launchFromColumn(0);
      controller.slotArrived(0);
      for (var i = 0; i < 60; i++) {
        controller.tick(0.05);
      }

      expect(controller.slots[0]!.starving, isTrue);
      expect(events.whereType<SlotStuckChanged>().first.stuck, isTrue);
      expect(controller.phase, GamePhase.failed);
      expect(events.whereType<LevelFailed>(), isNotEmpty);
    });

    test('a starving bottle resumes once its color reaches the bottom edge',
        () {
      final controller = GameController(
        grid: tinyGrid(),
        bottles: const [
          PaintBottle(id: 0, colorIndex: 0, capacity: 12),
          PaintBottle(id: 1, colorIndex: 1, capacity: 12),
        ],
        slotCount: 2,
        fillRate: 60,
      );
      LevelCompleted? completed;
      autopilot(controller, also: (e) {
        if (e is LevelCompleted) completed = e;
      });

      controller.launchFromColumn(0); // color 0 → starves for now
      controller.launchFromColumn(1); // color 1 drains the bottom rows
      controller.tick(0.01); // first tick: matches evaluated, little eaten
      expect(controller.slots[0]!.starving, isTrue);
      expect(controller.phase, GamePhase.playing,
          reason: 'a working bottle keeps the machine alive');

      for (var i = 0; i < 2000 && completed == null; i++) {
        controller.tick(0.05);
      }
      expect(completed, isNotNull);
      expect(controller.phase, GamePhase.complete);
    });
  });

  group('rewarded rescue', () {
    GameController jammedController() {
      final controller = GameController(
        grid: tinyGrid(),
        bottles: BottleFactory.build(tinyGrid(), seed: 1),
        fillRate: 40,
      );
      autopilot(controller);
      return controller;
    }

    test('starts at the base slot count', () {
      expect(jammedController().activeSlotCount, 4);
    });

    test('is repeatable up to the ceiling, then stops being offered', () {
      final controller = jammedController();

      // Every jam may be bought off with another slot...
      var granted = 0;
      while (controller.canEarnExtraSlot) {
        final before = controller.activeSlotCount;
        controller.grantExtraSlotAndResume();
        expect(controller.activeSlotCount, before + 1);
        granted++;
        expect(granted, lessThan(20), reason: 'must terminate');
      }

      expect(controller.activeSlotCount, GameController.maxSlots);
      expect(granted, GameController.maxSlots - 4,
          reason: '4 base slots grow to the ceiling');
      expect(controller.canEarnExtraSlot, isFalse,
          reason: 'past the ceiling the level must be replayed');
    });

    test('a grant past the ceiling is ignored rather than overflowing', () {
      final controller = jammedController();
      while (controller.canEarnExtraSlot) {
        controller.grantExtraSlotAndResume();
      }
      controller
        ..grantExtraSlotAndResume()
        ..grantExtraSlotAndResume();
      expect(controller.activeSlotCount, GameController.maxSlots);
    });

    test('resuming after a rescue lifts the failed phase', () {
      final controller = jammedController()..phase = GamePhase.failed;
      controller.grantExtraSlotAndResume();
      expect(controller.phase, GamePhase.playing);
    });
  });
}
