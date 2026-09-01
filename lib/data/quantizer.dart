import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../domain/models/pixel_grid.dart';
import 'game_palette.dart';

/// PURE image→grid pipeline (no Flutter imports) shared by the runtime
/// LevelProcessor and tool/gen_levels.dart, so witness validation runs on
/// EXACTLY the grid players get.
/// Painted behind (semi)transparent pixels so cut-out sources still
/// produce a full square — a soft arcade purple sky.
const backdropColor = 0xFF8A63D2;

/// Pure, isolate-friendly, unit-testable pipeline.
///
/// Levels are FULL SQUARES: the source is center-cropped square, scaled
/// to gridSize², and every cell becomes paintable content.
///
/// **Colours are not derived from the art.** Every pixel is snapped to the
/// fixed [GamePalette], and [maxColors] decides how many of those twelve
/// this level keeps. Deriving a palette per level is what used to let a
/// board ship with two greens a player reads as one colour — see
/// [GamePalette] for the full reasoning. The upshot for callers: the same
/// image at the same gridSize/maxColors is still perfectly deterministic,
/// but the colours it yields are now a subset of a known twelve.
PixelGrid quantizeImage(
  img.Image source, {
  required int gridSize,
  required int maxColors,
}) {
  // 1. Center-crop to a square.
  final side = math.min(source.width, source.height);
  var image = (source.width == source.height)
      ? source
      : img.copyCrop(
          source,
          x: (source.width - side) ~/ 2,
          y: (source.height - side) ~/ 2,
          width: side,
          height: side,
        );

  // 2. Scale so the grid is gridSize² (tiny pixel art stays 1:1).
  final n = math.min(gridSize, side);
  if (image.width != n) {
    image = img.copyResize(
      image,
      width: n,
      height: n,
      interpolation: img.Interpolation.average,
    );
  }
  final cols = n, rows = n;

  // 3. Read every cell and snap it to the nearest fixed palette colour.
  //    Transparency is composited over the backdrop first, so every cell
  //    holds paint.
  final fixed = _fixedRgb;
  final snapped = List<int>.filled(cols * rows, 0); // index into [fixed]
  final counts = List<int>.filled(fixed.length, 0);
  const bdR = (backdropColor >> 16) & 0xFF;
  const bdG = (backdropColor >> 8) & 0xFF;
  const bdB = backdropColor & 0xFF;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final p = image.getPixel(x, y);
      final a = p.a.toInt() / 255.0;
      final r = (p.r.toInt() * a + bdR * (1 - a)).round();
      final g = (p.g.toInt() * a + bdG * (1 - a)).round();
      final b = (p.b.toInt() * a + bdB * (1 - a)).round();
      final idx = _nearestFixed(r, g, b);
      snapped[y * cols + x] = idx;
      counts[idx]++;
    }
  }

  // 4. Keep the [maxColors] most-used palette entries. A level therefore
  //    still gets a palette that suits its picture — it just has to pick
  //    from the fixed twelve rather than inventing its own.
  final present = <int>[
    for (var i = 0; i < fixed.length; i++)
      if (counts[i] > 0) i,
  ]..sort((a, b) => counts[b].compareTo(counts[a]));
  var kept = present.take(math.max(1, maxColors)).toList();

  // 5. Everything that did not survive falls to its nearest kept colour.
  List<int> cellsFor(List<int> keptIdx) {
    final remap = List<int>.filled(fixed.length, 0);
    for (var i = 0; i < fixed.length; i++) {
      if (keptIdx.contains(i)) {
        remap[i] = keptIdx.indexOf(i);
      } else {
        var best = 0;
        var bestDist = double.infinity;
        for (var k = 0; k < keptIdx.length; k++) {
          final d = _distanceRgb(fixed[i], fixed[keptIdx[k]]);
          if (d < bestDist) {
            bestDist = d;
            best = k;
          }
        }
        remap[i] = best;
      }
    }
    return [for (final s in snapped) remap[s]];
  }

  var cells = cellsFor(kept);

  // 6. Drop colours that ended up with only a handful of cells — a bottle
  //    of 2 pixels is noise, not gameplay.
  final total = cells.length;
  final minCount = math.max(4, (total * 0.012).round());
  while (kept.length > 1) {
    final tally = List<int>.filled(kept.length, 0);
    for (final c in cells) {
      tally[c]++;
    }
    final weakest = tally.indexOf(tally.reduce(math.min));
    if (tally[weakest] >= minCount) break;
    kept = [...kept]..removeAt(weakest);
    cells = cellsFor(kept);
  }

  return PixelGrid(
    cols: cols,
    rows: rows,
    cells: cells,
    palette: [for (final i in kept) GamePalette.colors[i]],
  );
}

/// The fixed palette as RGB triples, computed once.
final List<List<int>> _fixedRgb = GamePalette.rgb;

int _nearestFixed(int r, int g, int b) {
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < _fixedRgb.length; i++) {
    final c = _fixedRgb[i];
    final dr = r - c[0], dg = g - c[1], db = b - c[2];
    final d = 0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db;
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

double _distanceRgb(List<int> a, List<int> b) {
  final dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
  // Perception-weighted RGB distance.
  return math.sqrt(0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db);
}

/// Perception-weighted distance between two packed RGB values. Kept public
/// to the library so the palette test measures separation with exactly the
/// metric the quantizer snaps with.
double paletteDistance(int c1, int c2) {
  final r1 = (c1 >> 16) & 0xFF, g1 = (c1 >> 8) & 0xFF, b1 = c1 & 0xFF;
  final r2 = (c2 >> 16) & 0xFF, g2 = (c2 >> 8) & 0xFF, b2 = c2 & 0xFF;
  final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
  return math.sqrt(0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db);
}
