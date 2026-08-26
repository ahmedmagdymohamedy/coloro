// Re-proves every shipped level against the CURRENT drain rules and, where
// a level lost its winning line, finds it a new one.
//
//   dart run tool/reproof_deals.dart            # report only
//   dart run tool/reproof_deals.dart --write    # emit the patch file
//
// Why this exists: a level's difficulty is its art plus (gridSize,
// maxColors, churn); its *fairness* is the (shuffleWindow, dealSeed) pair,
// which is only meaningful relative to the drain order. Change the drain
// order — as DrainOrder did when the left-to-right sweep became scattered —
// and the pairs still describe a solvable game, just not this one.
//
// So this tool re-searches ONLY that pair, over exactly the space
// tool/gen_levels.dart searches, and never touches the artwork, the grid
// size, the palette or the churn. Difficulty is preserved by always taking
// the strongest (largest) shuffle window that can still be won; the window
// is only weakened when no seed at that strength works.
import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/data/quantizer.dart';
import 'package:coloro/domain/models/pixel_grid.dart';
import 'package:image/image.dart' as img;

/// Seeds tried per window. gen_levels.dart tries 3 while it still has the
/// option of throwing the whole scene away; here the art is fixed, so the
/// search goes deeper before giving up any difficulty.
const _seedsPerWindow = 40;
const _maxNodes = 45000;

void main(List<String> args) {
  final write = args.contains('--write');
  final manifest =
      jsonDecode(File('assets/levels/levels.json').readAsStringSync())
          as Map<String, dynamic>;
  final levels = manifest['levels'] as Map<String, dynamic>;

  final patch = <String, Map<String, int>>{};
  var ok = 0, repaired = 0, weakened = 0, failed = 0;
  final failures = <int>[];

  for (var n = 1; n <= 300; n++) {
    final key = '$n.png';
    final c = levels[key] as Map<String, dynamic>;
    final grid = quantizeImage(
      img.decodeImage(File('assets/levels/$n.png').readAsBytesSync())!,
      gridSize: (c['gridSize'] as num).toInt(),
      maxColors: (c['maxColors'] as num).toInt(),
    );
    final recordedWindow = (c['shuffleWindow'] as num).toInt();
    final recordedSeed = (c['dealSeed'] as num).toInt();

    if (_solvable(grid, n, recordedWindow, recordedSeed)) {
      ok++;
      continue;
    }

    // Strongest shuffle first, so a repaired level stays as hard as it was.
    int? foundWindow, foundSeed;
    for (
      var window = recordedWindow;
      window >= 1 && foundWindow == null;
      window--
    ) {
      for (var k = 0; k < _seedsPerWindow; k++) {
        final dealSeed = (n * 977 + k * 7919 + window * 31) % 100000;
        if (_solvable(grid, n, window, dealSeed)) {
          foundWindow = window;
          foundSeed = dealSeed;
          break;
        }
      }
    }

    if (foundWindow == null) {
      failed++;
      failures.add(n);
      stderr.writeln(
        'level $n: NO solvable deal found (window $recordedWindow)',
      );
      continue;
    }

    repaired++;
    if (foundWindow < recordedWindow) {
      weakened++;
      stdout.writeln(
        'level $n: window $recordedWindow → $foundWindow, '
        'seed $recordedSeed → $foundSeed',
      );
    }
    patch[key] = {'shuffleWindow': foundWindow, 'dealSeed': foundSeed!};
  }

  stdout.writeln('\n--- reproof summary ---');
  stdout.writeln('already solvable : $ok');
  stdout.writeln(
    'repaired         : $repaired  (of which weakened: $weakened)',
  );
  stdout.writeln(
    'unrepairable     : $failed ${failures.isEmpty ? "" : failures}',
  );

  if (write) {
    File(
      'tool/deal_patch.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(patch));
    stdout.writeln('\nwrote tool/deal_patch.json (${patch.length} levels)');
  }
  if (failed > 0) exit(1);
}

bool _solvable(PixelGrid grid, int n, int window, int dealSeed) {
  final deal = BottleFactory.build(
    grid,
    seed: n,
    shuffleWindow: window,
    dealSeed: dealSeed,
  );
  if (deal.fold<int>(0, (a, b) => a + b.capacity) != grid.fillableCount) {
    return false;
  }
  return BottleFactory.isDealSolvable(grid, deal, seed: n, maxNodes: _maxNodes);
}
