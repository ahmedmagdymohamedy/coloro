import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/pixel_grid.dart';
import '../game_controller.dart';
import 'bead_atlas.dart';

/// The picture being painted: hint beads for empty cells, glossy beads that
/// pop in as pixels land, and a shine sweep on completion.
class PixelCanvas extends StatelessWidget {
  const PixelCanvas({
    super.key,
    required this.controller,
    required this.atlas,
    required this.repaint,
    required this.sweepProgress,
  });

  final GameController controller;
  final BeadAtlas atlas;
  final Listenable repaint;

  /// -1 when idle; 0..1 runs the completion shine band across the board.
  final ValueListenable<double> sweepProgress;

  /// Where the cell grid actually sits inside a canvas of [size].
  static Rect gridRect(Size size, PixelGrid grid) {
    final cell = cellSize(size, grid);
    final w = cell * grid.cols, h = cell * grid.rows;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  static double cellSize(Size size, PixelGrid grid) =>
      math.min(size.width / grid.cols, size.height / grid.rows);

  static Offset cellCenter(Size size, PixelGrid grid, int index) {
    final rect = gridRect(size, grid);
    final cell = cellSize(size, grid);
    final x = index % grid.cols, y = index ~/ grid.cols;
    return Offset(
      rect.left + (x + 0.5) * cell,
      rect.top + (y + 0.5) * cell,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PixelCanvasPainter(
          controller: controller,
          atlas: atlas,
          sweepProgress: sweepProgress,
          repaint: Listenable.merge([repaint, sweepProgress]),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PixelCanvasPainter extends CustomPainter {
  _PixelCanvasPainter({
    required this.controller,
    required this.atlas,
    required this.sweepProgress,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameController controller;
  final BeadAtlas atlas;
  final ValueListenable<double> sweepProgress;

  // Reused raw-atlas buffers (4 floats per sprite).
  Float32List? _xforms;
  Float32List? _rects;

  // Beads currently shrinking away (just eaten) — drawn in a second pass.
  final List<({double cx, double cy, int colorIndex, double scale})>
      _shrinking = [];

  static const _popDuration = 0.32;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = controller.grid;
    final rect = PixelCanvas.gridRect(size, grid);
    final cell = PixelCanvas.cellSize(size, grid);
    final time = controller.time;

    // Backboard.
    final board = RRect.fromRectAndRadius(
      rect.inflate(cell * 0.5),
      Radius.circular(cell * 0.8),
    );
    canvas.drawRRect(board, Paint()..color = AppColors.panelDeep);
    canvas.drawRRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.05),
    );

    // Batch all beads into one drawRawAtlas call over reused buffers —
    // zero per-frame allocations for the board itself.
    final count = grid.fillableCount;
    final xforms = _xforms ??= Float32List(count * 4);
    final rects = _rects ??= Float32List(count * 4);
    final half = atlas.spriteSize / 2;
    final baseScale = cell / atlas.spriteSize;
    final flashes = <Offset>[];

    var j = 0;
    for (var i = 0; i < grid.cells.length; i++) {
      final colorIndex = grid.cells[i];
      if (colorIndex == PixelGrid.background) continue;

      final x = i % grid.cols, y = i ~/ grid.cols;
      final cx = rect.left + (x + 0.5) * cell;
      final cy = rect.top + (y + 0.5) * cell;

      // Collect mode: the picture STARTS fully bright; an eaten cell dims
      // to its socket, with the bright bead shrinking away on top.
      final eatenAt = controller.cellFilledAt[i];
      double scale;
      double spriteTop;
      if (eatenAt >= 0) {
        spriteTop = atlas.spriteSize; // dim socket row
        scale = baseScale;
        final age = time - eatenAt;
        if (age < _popDuration) {
          // Shrinking bright bead drawn in the overlay pass.
          final p = (age / _popDuration).clamp(0.0, 1.0);
          _shrinking.add((
            cx: cx,
            cy: cy,
            colorIndex: colorIndex,
            scale: baseScale * (1 - p) * (1 + 0.35 * math.sin(math.pi * p)),
          ));
          if (age < 0.08) flashes.add(Offset(cx, cy));
        }
      } else {
        spriteTop = 0; // full bright bead
        scale = baseScale;
      }

      // RSTransform with rotation 0: scos = scale, ssin = 0.
      xforms[j] = scale;
      xforms[j + 1] = 0;
      xforms[j + 2] = cx - scale * half;
      xforms[j + 3] = cy - scale * half;
      rects[j] = colorIndex * atlas.spriteSize;
      rects[j + 1] = spriteTop;
      rects[j + 2] = (colorIndex + 1) * atlas.spriteSize;
      rects[j + 3] = spriteTop + atlas.spriteSize;
      j += 4;
    }

    canvas.save();
    canvas.clipRRect(board);
    canvas.drawRawAtlas(
      atlas.image,
      xforms,
      rects,
      null,
      null,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );

    // Overlay pass: bright beads shrinking off freshly eaten cells.
    if (_shrinking.isNotEmpty) {
      final overlayXf = <RSTransform>[];
      final overlayRects = <Rect>[];
      for (final sh in _shrinking) {
        overlayXf.add(RSTransform.fromComponents(
          rotation: 0,
          scale: sh.scale,
          anchorX: half,
          anchorY: half,
          translateX: sh.cx,
          translateY: sh.cy,
        ));
        overlayRects.add(atlas.fullRect(sh.colorIndex));
      }
      canvas.drawAtlas(atlas.image, overlayXf, overlayRects, null, null, null,
          Paint()..filterQuality = FilterQuality.medium);
      _shrinking.clear();
    }

    // White flash on freshly eaten cells.
    if (flashes.isNotEmpty) {
      final flashPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
      for (final f in flashes) {
        canvas.drawCircle(f, cell * 0.42, flashPaint);
      }
    }

    // Completion shine sweep.
    final sweep = sweepProgress.value;
    if (sweep >= 0 && sweep <= 1) {
      final bandCenter = rect.left +
          (rect.width + rect.height) * sweep -
          rect.height * 0.5;
      final shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(bandCenter, rect.center.dy),
          width: rect.width * 0.5,
          height: rect.height * 2,
        ),
      );
      canvas.drawRect(
        rect.inflate(cell),
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.plus,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PixelCanvasPainter oldDelegate) => true;
}
