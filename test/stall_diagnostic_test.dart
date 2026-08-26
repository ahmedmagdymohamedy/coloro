import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/data/quantizer.dart';
import 'package:coloro/domain/models/paint_bottle.dart';
import 'package:coloro/domain/models/pixel_grid.dart';
import 'package:coloro/game/game_controller.dart';
import 'package:coloro/game/game_events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Solvability gate. Every shipped level carries a (shuffleWindow,
/// dealSeed) pair the generator proved beatable; this re-proves it against
/// the art actually on disk, so drift in the art, the quantizer or the
/// drain rules fails the build instead of shipping a dead level.
void main() {
  final manifest =
      jsonDecode(File('assets/levels/levels.json').readAsStringSync())
          as Map<String, dynamic>;
  final levels = manifest['levels'] as Map<String, dynamic>;

  Map<String, dynamic> cfg(int n) => levels['$n.png'] as Map<String, dynamic>;

  ({PixelGrid grid, List<PaintBottle> deal}) load(int n) {
    final c = cfg(n);
    final grid = quantizeImage(
      img.decodeImage(File('assets/levels/$n.png').readAsBytesSync())!,
      gridSize: (c['gridSize'] as num).toInt(),
      maxColors: (c['maxColors'] as num).toInt(),
    );
    final deal = BottleFactory.build(
      grid,
      seed: n,
      shuffleWindow: (c['shuffleWindow'] as num).toInt(),
      dealSeed: (c['dealSeed'] as num).toInt(),
    );
    return (grid: grid, deal: deal);
  }

  // The drain order is a shared rule (see DrainOrder), so a change to it
  // re-proves against this sample on every run — and against the whole
  // campaign under COLORO_FULL_SWEEP=1, which is what gates a release.
  final sample = Platform.environment['COLORO_FULL_SWEEP'] == '1'
      ? [for (var n = 1; n <= 300; n++) n]
      : const [
          1, 2, 3, 5, 10, 25, 50, 75, 100, 125, //
          150, 175, 200, 225, 250, 275, 290, 295, 299, 300,
        ];

  for (final n in sample) {
    final c = cfg(n);
    test('level $n (${c['name']}, ${c['gridSize']}², ${c['colors']} colors, '
        'churn ${c['churn']}, shuffle ${c['shuffleWindow']}, '
        '${(c['hard'] as bool) ? "HARD" : "normal"}) is solvable as dealt', () {
      final l = load(n);
      expect(
        l.deal.fold<int>(0, (a, b) => a + b.capacity),
        l.grid.fillableCount,
        reason: 'the supply must cover the picture exactly',
      );
      expect(
        BottleFactory.isDealSolvable(l.grid, l.deal, seed: n),
        isTrue,
        reason: 'the shipped deal for level $n has no winning line',
      );
    });
  }

  test('the campaign ramps difficulty and obeys the hard rules', () {
    double avg(Iterable<num> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    List<num> field(String key, Iterable<int> range) => [
      for (final n in range) cfg(n)[key] as num,
    ];

    final early = List.generate(40, (i) => i + 1);
    final late = List.generate(40, (i) => 260 + i);

    expect(
      avg(field('churn', late)),
      greaterThan(avg(field('churn', early))),
      reason: 'late levels must be more vertically interleaved',
    );
    expect(
      avg(field('shuffleWindow', late)),
      greaterThan(avg(field('shuffleWindow', early)) * 1.5),
      reason: 'late levels must deal a far more scrambled tray',
    );
    expect(
      avg(field('colors', late)),
      greaterThan(avg(field('colors', early))),
      reason: 'late levels must use more colors',
    );

    for (var n = 1; n <= 300; n++) {
      final c = cfg(n);
      expect(c['colors'] as int, inInclusiveRange(5, 12), reason: 'level $n');
      expect(
        c['gridSize'] as int,
        inInclusiveRange(15, 40),
        reason: 'level $n',
      );
      expect(c['hard'] as bool, n % 5 == 0, reason: 'level $n 4:1 cadence');
    }
  });

  test('the tray really is shuffled, not sorted', () {
    const n = 50;
    final c = cfg(n);
    final grid = quantizeImage(
      img.decodeImage(File('assets/levels/$n.png').readAsBytesSync())!,
      gridSize: (c['gridSize'] as num).toInt(),
      maxColors: (c['maxColors'] as num).toInt(),
    );
    final sorted = BottleFactory.build(grid, seed: n);
    final dealt = BottleFactory.build(
      grid,
      seed: n,
      shuffleWindow: (c['shuffleWindow'] as num).toInt(),
      dealSeed: (c['dealSeed'] as num).toInt(),
    );
    expect((c['shuffleWindow'] as num).toInt(), greaterThan(1));
    expect(
      dealt.map((b) => b.id).toList(),
      isNot(equals(sorted.map((b) => b.id).toList())),
      reason: 'the shipped tray order must differ from the sorted one',
    );
  });

  test('the live controller drains exactly like the solver models it', () {
    const n = 1;
    final l = load(n);
    final grid = l.grid;
    final controller = GameController(
      grid: grid,
      bottles: l.deal,
      fillRate: 40,
    );
    var taken = 0;
    final gone = <int>{};
    controller.onEvent = (e) {
      if (e is BottleLaunched) controller.slotArrived(e.slotIndex);
      if (e is CellFillStarted) {
        taken++;
        // Bottom-edge only: everything below the taken cell in its column
        // must already be gone.
        final x = e.cellIndex % grid.cols, y = e.cellIndex ~/ grid.cols;
        for (var yy = y + 1; yy < grid.rows; yy++) {
          expect(
            gone.contains(yy * grid.cols + x),
            isTrue,
            reason: 'cell below (\$x,\$yy) was skipped',
          );
        }
        gone.add(e.cellIndex);
        controller.cellArrived(e.cellIndex);
      }
    };
    for (var c = 0; c < controller.tray.length; c++) {
      controller.launchFromColumn(c);
    }
    for (var i = 0; i < 200; i++) {
      controller.tick(0.05);
    }
    expect(taken, greaterThan(0));
  });
}
