// Recomputes the *informational* fields in levels.json from what the
// pipeline actually produces, and writes them as a patch.
//
//   dart run tool/refresh_level_meta.dart          # report
//   dart run tool/refresh_level_meta.dart --write  # -> tool/meta_patch.json
//
// `colors`, `cells` and `bottles` are descriptions of a level, not inputs to
// it — nothing reads them at runtime. But `test/stall_diagnostic_test.dart`
// asserts on `colors`, and a stale value would let the suite pass on a
// number that no longer describes the game. Run this after any change to the
// quantizer, the palette, or a level's gridSize/maxColors.
import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/data/quantizer.dart';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final write = args.contains('--write');
  final levels =
      (jsonDecode(File('assets/levels/levels.json').readAsStringSync())
          as Map<String, dynamic>)['levels'] as Map<String, dynamic>;

  final patch = <String, Map<String, int>>{};
  var changed = 0;
  var minColours = 99, maxColours = 0;

  for (var n = 1; n <= 300; n++) {
    final key = '$n.png';
    final c = levels[key] as Map<String, dynamic>;
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

    final colours = grid.palette.length;
    final cells = grid.fillableCount;
    final bottles = deal.length;
    minColours = colours < minColours ? colours : minColours;
    maxColours = colours > maxColours ? colours : maxColours;

    if (c['colors'] != colours ||
        c['cells'] != cells ||
        c['bottles'] != bottles) {
      changed++;
      patch[key] = {'colors': colours, 'cells': cells, 'bottles': bottles};
    }
  }

  stdout.writeln('levels whose metadata drifted: $changed / 300');
  stdout.writeln('actual colour count range: $minColours..$maxColours');

  if (write) {
    File(
      'tool/meta_patch.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(patch));
    stdout.writeln('wrote tool/meta_patch.json');
  }
}
