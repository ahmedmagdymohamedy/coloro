import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Pre-rendered bead sprites, one glossy "full" and one faint "hint" variant
/// per palette color. The grid painter then batches the whole board with a
/// single drawAtlas call per frame — hundreds of cells at trivial cost.
class BeadAtlas {
  BeadAtlas._(this.image, this.spriteSize, this.colorCount);

  final ui.Image image;
  final double spriteSize;
  final int colorCount;

  Rect fullRect(int colorIndex) =>
      Rect.fromLTWH(colorIndex * spriteSize, 0, spriteSize, spriteSize);

  Rect hintRect(int colorIndex) =>
      Rect.fromLTWH(colorIndex * spriteSize, spriteSize, spriteSize, spriteSize);

  void dispose() => image.dispose();

  static Future<BeadAtlas> build(List<int> paletteArgb,
      {double spriteSize = 56}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (var i = 0; i < paletteArgb.length; i++) {
      final color = Color(paletteArgb[i]);
      _paintBead(
        canvas,
        Rect.fromLTWH(i * spriteSize, 0, spriteSize, spriteSize),
        color,
      );
      _paintHint(
        canvas,
        Rect.fromLTWH(i * spriteSize, spriteSize, spriteSize, spriteSize),
        color,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (paletteArgb.length * spriteSize).ceil(),
      (spriteSize * 2).ceil(),
    );
    picture.dispose();
    return BeadAtlas._(image, spriteSize, paletteArgb.length);
  }

  /// Candy bead: rounded cube with a lit top-left and shaded bottom edge.
  static void _paintBead(Canvas canvas, Rect rect, Color color) {
    final inset = rect.deflate(rect.width * 0.06);
    final radius = Radius.circular(rect.width * 0.24);
    final rrect = RRect.fromRectAndRadius(inset, radius);

    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.20).clamp(0.0, 1.0)).toColor();
    final dark =
        hsl.withLightness((hsl.lightness - 0.20).clamp(0.0, 1.0)).toColor();

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
          stops: const [0, 0.55, 1],
        ).createShader(inset),
    );

    // Bottom inner shadow for depth.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
            inset.left, inset.bottom - inset.height * 0.28, inset.right, inset.bottom),
        radius,
      ),
      Paint()..color = dark.withValues(alpha: 0.35),
    );

    // Glass glint.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset.left + inset.width * 0.14,
          inset.top + inset.height * 0.10,
          inset.width * 0.34,
          inset.height * 0.22,
        ),
        Radius.circular(rect.width * 0.12),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  /// Empty socket left behind after a pixel is collected. Deliberately
  /// very faint: it must read as "gone" and never compete with the pixels
  /// still on the board.
  static void _paintHint(Canvas canvas, Rect rect, Color color) {
    final inset = rect.deflate(rect.width * 0.20);
    final rrect =
        RRect.fromRectAndRadius(inset, Radius.circular(rect.width * 0.20));
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF0C0918),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: 0.06),
    );
  }
}
