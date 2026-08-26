import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/display_palette.dart';

/// Pre-rendered bead sprites, one glossy "full" and one empty "socket"
/// variant per palette color. The grid painter then batches the whole board
/// with a single drawAtlas call per frame — hundreds of cells at trivial
/// cost.
///
/// The two sprites are deliberately drawn as *opposites*, because telling
/// them apart at a glance is the whole readability of the board:
///
///  * a **bead** is bright, raised and separated from its neighbours by a
///    dark gap, so a run of same-colored cells still reads as individual
///    pixels instead of one merged blob;
///  * a **socket** is a flat, colorless hole with an inner shadow — it
///    carries no hue at all, so "already drunk" can never be mistaken for
///    "a dark color still on the board".
///
/// Bead colors come from [DisplayPalette], the same transform the flasks
/// use, so a pixel and the bottle that drinks it are visibly the same color.
class BeadAtlas {
  BeadAtlas._(this.image, this.spriteSize, this.colorCount);

  final ui.Image image;
  final double spriteSize;
  final int colorCount;

  Rect fullRect(int colorIndex) =>
      Rect.fromLTWH(colorIndex * spriteSize, 0, spriteSize, spriteSize);

  Rect hintRect(int colorIndex) => Rect.fromLTWH(
    colorIndex * spriteSize,
    spriteSize,
    spriteSize,
    spriteSize,
  );

  void dispose() => image.dispose();

  static Future<BeadAtlas> build(
    List<int> paletteArgb, {
    double spriteSize = 56,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (var i = 0; i < paletteArgb.length; i++) {
      final color = DisplayPalette.of(paletteArgb[i]);
      _paintBead(
        canvas,
        Rect.fromLTWH(i * spriteSize, 0, spriteSize, spriteSize),
        color,
      );
      _paintSocket(
        canvas,
        Rect.fromLTWH(i * spriteSize, spriteSize, spriteSize, spriteSize),
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

  /// A filled pixel: a chunky candy tile, lit from the top-left.
  ///
  /// The 0.12 inset is doing real work — it leaves a dark gutter between
  /// neighbouring cells, which is what makes a solid field of one color
  /// still read as a grid of separate pixels.
  static void _paintBead(Canvas canvas, Rect rect, Color color) {
    final inset = rect.deflate(rect.width * 0.12);
    final radius = Radius.circular(rect.width * 0.26);
    final rrect = RRect.fromRectAndRadius(inset, radius);

    final light = DisplayPalette.lighten(color, 0.20);
    final dark = DisplayPalette.darken(color, 0.18);

    // Dark contact shadow under the tile — lifts it off the board.
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset.translate(0, inset.height * 0.07), radius),
      Paint()..color = const Color(0x66000000),
    );

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
          inset.left,
          inset.bottom - inset.height * 0.26,
          inset.right,
          inset.bottom,
        ),
        radius,
      ),
      Paint()..color = dark.withValues(alpha: 0.40),
    );

    // Bright top-left glint — the single strongest "this cell is still
    // here" cue, and the reason a dark palette no longer disappears.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset.left + inset.width * 0.13,
          inset.top + inset.height * 0.09,
          inset.width * 0.38,
          inset.height * 0.24,
        ),
        Radius.circular(rect.width * 0.13),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Crisp rim in the tile's own light tone: separates two adjacent beads
    // of the *same* color, which a gap alone cannot do on a dark board.
    canvas.drawRRect(
      rrect.deflate(rect.width * 0.018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.036
        ..color = light.withValues(alpha: 0.75),
    );
  }

  /// An emptied cell. Colorless on purpose: a socket that kept a tint of
  /// its old color is exactly what made dark levels unreadable, because a
  /// faintly-tinted hole and a genuinely dark pixel look identical.
  static void _paintSocket(Canvas canvas, Rect rect) {
    final inset = rect.deflate(rect.width * 0.26);
    final rrect = RRect.fromRectAndRadius(
      inset,
      Radius.circular(rect.width * 0.18),
    );

    // The hole itself — darker than the board behind it.
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF080614));

    // Inner shadow at the top: reads as depth, so the cell looks punched
    // out rather than merely painted a dark color.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          inset.left,
          inset.top,
          inset.right,
          inset.top + inset.height * 0.38,
        ),
        Radius.circular(rect.width * 0.18),
      ),
      Paint()..color = const Color(0x55000000),
    );

    // Faint neutral highlight on the lower lip, the classic "hole" cue.
    canvas.drawRRect(
      rrect.deflate(rect.width * 0.012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.024
        ..color = Colors.white.withValues(alpha: 0.05),
    );
  }
}
