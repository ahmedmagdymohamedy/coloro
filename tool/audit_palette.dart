// Reports what snapping every level onto the fixed [GamePalette] does to
// the campaign, WITHOUT solving anything — so it runs in seconds and can be
// read before committing to the slow deal re-search.
//
//   dart run tool/audit_palette.dart
//
// The number that matters is the distinct-colour count per level. A level
// whose six near-identical purples collapse onto three fixed colours is a
// materially different (and probably easier) puzzle, so a large collapse is
// a reason to stop and reconsider rather than to patch seeds.
import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/quantizer.dart';
import 'package:image/image.dart' as img;

void main() {
  final manifest =
      jsonDecode(File('assets/levels/levels.json').readAsStringSync())
          as Map<String, dynamic>;
  final levels = manifest['levels'] as Map<String, dynamic>;

  final drops = <int, int>{}; // requested colours -> count of levels
  final shrank = <String>[];
  var under5 = 0;
  var identical = 0;

  for (var n = 1; n <= 300; n++) {
    final c = levels['$n.png'] as Map<String, dynamic>;
    final want = (c['maxColors'] as num).toInt();
    final was = (c['colors'] as num).toInt();
    final grid = quantizeImage(
      img.decodeImage(File('assets/levels/$n.png').readAsBytesSync())!,
      gridSize: (c['gridSize'] as num).toInt(),
      maxColors: want,
    );
    final got = grid.palette.length;
    drops[got] = (drops[got] ?? 0) + 1;
    if (got == was) identical++;
    if (got < 5) under5++;
    if (got < was) shrank.add('L$n $was->$got');
  }

  stdout.writeln('--- distinct colours per level after snapping ---');
  final keys = drops.keys.toList()..sort();
  for (final k in keys) {
    stdout.writeln('  $k colours : ${drops[k]} levels');
  }
  stdout.writeln('\nsame count as before : $identical / 300');
  stdout.writeln('fewer than before    : ${shrank.length} / 300');
  stdout.writeln('UNDER 5 colours      : $under5 / 300  <-- the risk number');
  if (shrank.isNotEmpty) {
    stdout.writeln('\nfirst 25 that shrank: ${shrank.take(25).join(', ')}');
  }
}
