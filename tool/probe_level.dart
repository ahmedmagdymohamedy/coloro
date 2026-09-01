// Why is one level unsolvable? Tries escalating search budgets, and reports
// the board shape that might explain it.
//
//   dart run tool/probe_level.dart 85
import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/data/quantizer.dart';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final n = int.parse(args.isEmpty ? '85' : args[0]);
  // Optional overrides: dart run tool/probe_level.dart 291 <maxColors> <gridSize>
  final colourOverride = args.length > 1 ? int.parse(args[1]) : null;
  final gridOverride = args.length > 2 ? int.parse(args[2]) : null;
  final levels =
      (jsonDecode(File('assets/levels/levels.json').readAsStringSync())
              as Map<String, dynamic>)['levels']
          as Map<String, dynamic>;
  final c = levels['$n.png'] as Map<String, dynamic>;

  final grid = quantizeImage(
    img.decodeImage(File('assets/levels/$n.png').readAsBytesSync())!,
    gridSize: gridOverride ?? (c['gridSize'] as num).toInt(),
    maxColors: colourOverride ?? (c['maxColors'] as num).toInt(),
  );

  stdout.writeln(
    'level $n  ${grid.cols}x${grid.rows}  '
    'cells=${grid.fillableCount}  colours=${grid.palette.length}',
  );
  final counts = grid.colorCounts;
  stdout.writeln('colour cell counts: $counts');

  final deal = BottleFactory.build(
    grid,
    seed: n,
    shuffleWindow: 1,
    dealSeed: 0,
  );
  final caps = deal.map((b) => b.capacity).toList()..sort();
  stdout.writeln(
    'bottles=${deal.length}  '
    'biggest=${caps.last}  smallest=${caps.first}',
  );
  final big = deal.where((b) => b.capacity >= 30).length;
  stdout.writeln('bottles of capacity >= 30: $big');

  for (final budget in [45000, 200000, 800000, 3000000]) {
    final sw = Stopwatch()..start();
    final ok = BottleFactory.isDealSolvable(grid, deal, maxNodes: budget);
    sw.stop();
    stdout.writeln(
      '  window 1, maxNodes $budget -> '
      '${ok ? "SOLVABLE" : "no"}  (${sw.elapsedMilliseconds}ms)',
    );
    if (ok) return;
  }
}
