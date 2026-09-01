// Re-proves every shipped level against the CURRENT rules and, where a level
// lost its winning line, finds it a new one.
//
//   dart run tool/reproof_deals.dart            # report only
//   dart run tool/reproof_deals.dart --write    # emit tool/deal_patch.json
//
// Why this exists: a level's difficulty is its art plus (gridSize, maxColors,
// churn); its *fairness* is the deal. Change anything upstream — the drain
// order, the quantizer's palette, the bottle-capacity cap — and the recorded
// (shuffleWindow, dealSeed) pairs still describe a solvable game, just not
// this one.
//
// The search has three knobs, tried cheapest-first:
//
//   1. dealSeed      — free, changes nothing a player can see
//   2. shuffleWindow — costs difficulty, so only weakened when seeds run out
//   3. maxColors     — changes how the picture looks
//   4. gridSize      — changes the picture's resolution, so it goes last
//
// maxColors earns its place because it is the knob that actually moves
// solvability after a palette change: it sets how many colours a level keeps,
// which sets each colour's cell count, which sets bottle sizes — and an
// oversized bottle is what jams a slot.
import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/data/quantizer.dart';
import 'package:coloro/domain/models/pixel_grid.dart';
import 'package:image/image.dart' as img;

const _seedsPerWindow = 40;
const _maxNodes = 45000;

/// Offsets applied to a level's recorded maxColors, in the order tried.
///
/// More colours first: it splits the same cells across more palette entries,
/// which shrinks every bottle and is what usually unjams a board. The deep
/// negative offsets matter for the opposite case — a board whose palette is
/// very lopsided (level 291 had two colours holding 68% of it and several
/// holding under 60 cells). Those tiny colours starve on a wide board, and
/// merging them away is the only thing that helps.
const _colourOffsets = [0, 1, 2, -1, 3, -2, -3, -4];

/// Offsets applied to a level's recorded gridSize, tried only after every
/// colour option is exhausted. A smaller board has fewer cells, so its
/// colours need fewer bottles and the machine jams less — but it also
/// coarsens the picture, which is why it is the last knob turned.
const _gridOffsets = [0, -1, -2, -3, 1];

void main(List<String> args) {
  final write = args.contains('--write');
  // --only 1,2,3 re-searches just those levels, so a follow-up pass over the
  // stragglers does not repeat the whole 300-level sweep.
  final onlyArg = args.firstWhere(
    (a) => a.startsWith('--only='),
    orElse: () => '',
  );
  final only = onlyArg.isEmpty
      ? <int>{}
      : onlyArg.substring(7).split(',').map(int.parse).toSet();
  final manifest =
      jsonDecode(File('assets/levels/levels.json').readAsStringSync())
          as Map<String, dynamic>;
  final levels = manifest['levels'] as Map<String, dynamic>;

  final patch = <String, Map<String, int>>{};
  var ok = 0, repaired = 0, weakened = 0, recoloured = 0, failed = 0;
  final failures = <int>[];

  for (var n = 1; n <= 300; n++) {
    if (only.isNotEmpty && !only.contains(n)) continue;
    final key = '$n.png';
    final c = levels[key] as Map<String, dynamic>;
    final gridSize = (c['gridSize'] as num).toInt();
    final recordedColours = (c['maxColors'] as num).toInt();
    final recordedWindow = (c['shuffleWindow'] as num).toInt();
    final recordedSeed = (c['dealSeed'] as num).toInt();
    final source = img.decodeImage(
      File('assets/levels/$n.png').readAsBytesSync(),
    )!;

    PixelGrid gridFor(int colours, [int? size]) =>
        quantizeImage(source, gridSize: size ?? gridSize, maxColors: colours);

    if (_solvable(gridFor(recordedColours), n, recordedWindow, recordedSeed)) {
      ok++;
      if (n % 25 == 0) stdout.writeln('  ... $n/300');
      continue;
    }
    stdout.writeln('  level $n needs a new deal, searching...');

    int? foundColours, foundWindow, foundSeed, foundGrid;
    outer:
    for (final gOff in _gridOffsets) {
      final size = gridSize + gOff;
      // 15..40 is the range the campaign contract asserts (see
      // test/stall_diagnostic_test.dart); going outside it fails the suite.
      if (size < 15 || size > 40) continue;
      for (final off in _colourOffsets) {
        final colours = recordedColours + off;
        if (colours < 5 || colours > 12) continue;
        final grid = gridFor(colours, size);
        // Strongest shuffle first, so a repair keeps the level as hard.
        for (var window = recordedWindow; window >= 1; window--) {
          for (var k = 0; k < _seedsPerWindow; k++) {
            final dealSeed = (n * 977 + k * 7919 + window * 31) % 100000;
            if (_solvable(grid, n, window, dealSeed)) {
              foundColours = colours;
              foundWindow = window;
              foundSeed = dealSeed;
              foundGrid = size;
              break outer;
            }
          }
        }
      }
    }

    if (foundWindow == null) {
      failed++;
      failures.add(n);
      stderr.writeln('level $n: NO solvable deal found');
      continue;
    }

    repaired++;
    final notes = <String>[];
    if (foundWindow < recordedWindow) {
      weakened++;
      notes.add('window $recordedWindow->$foundWindow');
    }
    if (foundColours != recordedColours) {
      recoloured++;
      notes.add('colours $recordedColours->$foundColours');
    }
    if (notes.isNotEmpty) stdout.writeln('level $n: ${notes.join(', ')}');

    patch[key] = {
      'shuffleWindow': foundWindow,
      'dealSeed': foundSeed!,
      'maxColors': foundColours!,
      'gridSize': foundGrid!,
    };
  }

  stdout.writeln('\n--- reproof summary ---');
  stdout.writeln('already solvable : $ok');
  stdout.writeln(
    'repaired         : $repaired '
    '(weakened: $weakened, recoloured: $recoloured)',
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
  return BottleFactory.isDealSolvable(grid, deal, maxNodes: _maxNodes);
}
