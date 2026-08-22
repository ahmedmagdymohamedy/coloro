import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../domain/models/pixel_grid.dart';

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

  // 3. Read cells; transparency is composited over the backdrop so every
  //    cell holds paint.
  final rawColors = List<int>.filled(cols * rows, PixelGrid.background);
  final frequency = <int, int>{};
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
      final posterized = _posterize(r, g, b);
      rawColors[y * cols + x] = posterized;
      frequency[posterized] = (frequency[posterized] ?? 0) + 1;
    }
  }

  // 3. Build the palette: most frequent colors first, merging any color
  //    that sits close to an already chosen one.
  final ranked = frequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final palette = <int>[];
  for (final entry in ranked) {
    if (palette.length >= maxColors) break;
    final isNearExisting =
        palette.any((p) => _distance(p, entry.key) < _mergeDistance);
    if (!isNearExisting) palette.add(entry.key);
  }
  if (palette.isEmpty && ranked.isNotEmpty) palette.add(ranked.first.key);

  // 4. Map every cell to its nearest palette color.
  var cells = [
    for (final raw in rawColors)
      raw == PixelGrid.background ? PixelGrid.background : _nearest(palette, raw),
  ];

  // 5. Drop colors that ended up with only a handful of cells — a bottle
  //    of 2 pixels is noise, not gameplay.
  final total = cells.where((c) => c >= 0).length;
  final minCount = math.max(4, (total * 0.012).round());
  while (palette.length > 1) {
    final counts = List<int>.filled(palette.length, 0);
    for (final c in cells) {
      if (c >= 0) counts[c]++;
    }
    final weakest = counts.indexOf(counts.reduce(math.min));
    if (counts[weakest] >= minCount) break;
    final removedColor = palette.removeAt(weakest);
    cells = [
      for (final c in cells)
        c == PixelGrid.background
            ? PixelGrid.background
            : c == weakest
                ? _nearest(palette, removedColor)
                : (c > weakest ? c - 1 : c),
    ];
  }

  return PixelGrid(
    cols: cols,
    rows: rows,
    cells: cells,
    palette: [for (final c in palette) 0xFF000000 | c],
  );
}

const _mergeDistance = 52.0;

int _posterize(int r, int g, int b) {
  int q(int v) => math.min(255, (v >> 4 << 4) + 8);
  return (q(r) << 16) | (q(g) << 8) | q(b);
}

double _distance(int c1, int c2) {
  final r1 = (c1 >> 16) & 0xFF, g1 = (c1 >> 8) & 0xFF, b1 = c1 & 0xFF;
  final r2 = (c2 >> 16) & 0xFF, g2 = (c2 >> 8) & 0xFF, b2 = c2 & 0xFF;
  // Perception-weighted RGB distance.
  final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
  return math.sqrt(0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db);
}

int _nearest(List<int> palette, int color) {
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < palette.length; i++) {
    final d = _distance(palette[i], color);
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}
