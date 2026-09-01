// Renders a level's quantized grid straight to a PNG so the colour work can
// be eyeballed without launching the app.
//
//   dart run tool/render_level.dart 44 out.png
import 'dart:convert';
import 'dart:io';

import 'package:coloro/data/quantizer.dart';
import 'package:coloro/domain/models/pixel_grid.dart';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final n = int.parse(args.isEmpty ? '44' : args[0]);
  final out = args.length > 1 ? args[1] : 'level_$n.png';

  final levels = (jsonDecode(File('assets/levels/levels.json').readAsStringSync())
      as Map<String, dynamic>)['levels'] as Map<String, dynamic>;
  final c = levels['$n.png'] as Map<String, dynamic>;

  final grid = quantizeImage(
    img.decodeImage(File('assets/levels/$n.png').readAsBytesSync())!,
    gridSize: (c['gridSize'] as num).toInt(),
    maxColors: (c['maxColors'] as num).toInt(),
  );

  const cell = 22, gap = 3;
  final w = grid.cols * cell, h = grid.rows * cell;
  final canvas = img.Image(width: w, height: h);
  img.fill(canvas, color: img.ColorRgb8(0x15, 0x0F, 0x2C));

  for (var y = 0; y < grid.rows; y++) {
    for (var x = 0; x < grid.cols; x++) {
      final v = grid.cells[y * grid.cols + x];
      if (v == PixelGrid.background) continue;
      final argb = grid.palette[v];
      img.fillRect(
        canvas,
        x1: x * cell + gap,
        y1: y * cell + gap,
        x2: (x + 1) * cell - gap,
        y2: (y + 1) * cell - gap,
        color: img.ColorRgb8(
          (argb >> 16) & 0xFF,
          (argb >> 8) & 0xFF,
          argb & 0xFF,
        ),
      );
    }
  }

  File(out).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('level $n  ${grid.cols}x${grid.rows}  '
      '${grid.palette.length} colours -> $out');
}
