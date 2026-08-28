import 'package:flutter/material.dart';

import '../../core/theme/display_palette.dart';
import '../../domain/models/pixel_grid.dart';

/// Renders a finished [PixelGrid] as rounded beads — used for menu previews
/// (ghosted) and the level-complete reward (full color).
class PixelPicture extends StatelessWidget {
  const PixelPicture({super.key, required this.grid, this.opacity = 1});

  final PixelGrid grid;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PixelPicturePainter(grid, opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PixelPicturePainter extends CustomPainter {
  _PixelPicturePainter(this.grid, this.opacity);

  final PixelGrid grid;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / grid.cols < size.height / grid.rows
        ? size.width / grid.cols
        : size.height / grid.rows;
    final ox = (size.width - cell * grid.cols) / 2;
    final oy = (size.height - cell * grid.rows) / 2;
    final paint = Paint();

    for (var i = 0; i < grid.cells.length; i++) {
      final c = grid.cells[i];
      if (c == PixelGrid.background) continue;
      final x = i % grid.cols, y = i ~/ grid.cols;
      // Same transform the board uses, so the menu preview and the
      // level-complete reward are the picture the player just played.
      paint.color = DisplayPalette.of(
        grid.palette[c],
      ).withValues(alpha: opacity);
      final r = Rect.fromLTWH(
        ox + x * cell,
        oy + y * cell,
        cell,
        cell,
      ).deflate(cell * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PixelPicturePainter old) =>
      old.grid != grid || old.opacity != opacity;
}
