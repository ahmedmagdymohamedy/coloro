import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/display_palette.dart';

/// Paints a glossy paint bottle. Shared by the tray, the machine slots and
/// the in-flight VFX so the bottle looks identical everywhere.
///
/// **The liquid color is never tinted, faded or greyed.** An earlier build
/// dimmed starving bottles and the queued tray rows by lerping them toward
/// the panel purple, and the first thing playtesting said was that you then
/// could not tell what color the bottle actually held — which is the single
/// piece of information the whole puzzle is played on. Depth and distress
/// are now carried by geometry and light only:
///
///  * queued tray rows → smaller, softer highlights, a deeper drop shadow;
///  * a starving bottle → a pulsing red alarm ring around the flask.
///
/// Both leave `color` completely untouched. Callers pass a color already
/// through [DisplayPalette], the same transform the board's beads use, so a
/// flask and the pixels it drinks are visibly the same color.
class BottlePainter {
  const BottlePainter();

  /// [squash] < 1 flattens the bottle (press/land), > 1 stretches it.
  /// [wobble] tilts it slightly (radians) while spraying.
  /// [fill] 0..1 sets the liquid level inside the round glass body — the
  /// flask fills up as the bottle collects beads.
  /// [depth] 0..1 pushes the flask visually into the background WITHOUT
  /// touching its hue: highlights soften, the shadow deepens.
  /// [alarm] 0..1 draws the starving alarm ring at that intensity.
  void paint(
    Canvas canvas,
    Size size, {
    required Color color,
    required String label,
    double squash = 1,
    double wobble = 0,
    double depth = 0,
    double alarm = 0,
    double fill = 1,
  }) {
    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.rotate(wobble);
    canvas.scale(2 - squash, squash);
    canvas.translate(-size.width / 2, -size.height);

    final w = size.width, h = size.height;
    final hsl = HSLColor.fromColor(color);
    final capColor = DisplayPalette.lighten(color, 0.05);
    final lighten = DisplayPalette.lighten(color, 0.22);
    // The glass is the liquid's own hue, only a little deeper — never a
    // different color, so the flask reads as "a bottle of THIS color".
    final glass = hsl
        .withLightness((hsl.lightness - 0.11).clamp(0.05, 1.0))
        .withSaturation((hsl.saturation * 0.88).clamp(0.0, 1.0))
        .toColor();
    final surface = DisplayPalette.lighten(color, 0.14);

    // Highlight strength is the ONLY thing depth touches.
    final gloss = 1 - depth * 0.55;

    // Round glass body in the lower part.
    final r = math.min(w * 0.50, h * 0.385);
    final center = Offset(w / 2, h - r - h * 0.02);

    // Drop shadow: deepens with depth, so back rows sit further away.
    if (depth > 0) {
      canvas.drawCircle(
        center.translate(0, h * 0.02 * depth),
        r,
        Paint()
          ..color = const Color(0xFF0B0820).withValues(alpha: 0.45 * depth)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
      );
    }

    canvas.drawCircle(center, r, Paint()..color = glass);

    // Liquid: fills the inner body from the bottom, level = [fill].
    final inner = r * 0.90;
    final level = (fill.clamp(0.0, 1.0)) * 2 * inner;
    if (level > 0.01) {
      final liquidTop = center.dy + inner - level;
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: inner)),
      );
      canvas.drawRect(
        Rect.fromLTRB(
          center.dx - inner,
          liquidTop,
          center.dx + inner,
          center.dy + inner,
        ),
        Paint()..color = color,
      );
      // Liquid surface line.
      if (fill < 0.98) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, liquidTop),
            width: inner * 2,
            height: inner * 0.22,
          ),
          Paint()..color = surface.withValues(alpha: 0.85 * gloss),
        );
      }
      canvas.restore();
    }

    // Neck (glass tone).
    final neckRect = Rect.fromCenter(
      center: Offset(w / 2, center.dy - r - h * 0.030),
      width: w * 0.26,
      height: h * 0.12,
    );
    canvas.drawRect(neckRect, Paint()..color = glass);

    // Collar band, slightly wider than the neck.
    final collar = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, neckRect.top),
        width: w * 0.40,
        height: h * 0.085,
      ),
      Radius.circular(w * 0.045),
    );
    canvas.drawRRect(collar, Paint()..color = glass);

    // Faceted drop cork.
    final capBottom = collar.outerRect.top + h * 0.012;
    final capTop = capBottom - h * 0.20;
    final capMidY = capTop + (capBottom - capTop) * 0.60;
    final cap = Path()
      ..moveTo(w / 2, capTop)
      ..lineTo(w / 2 + w * 0.17, capMidY)
      ..quadraticBezierTo(
        w / 2 + w * 0.14,
        capBottom,
        w / 2 + w * 0.06,
        capBottom,
      )
      ..lineTo(w / 2 - w * 0.06, capBottom)
      ..quadraticBezierTo(
        w / 2 - w * 0.14,
        capBottom,
        w / 2 - w * 0.17,
        capMidY,
      )
      ..close();
    canvas.drawPath(cap, Paint()..color = capColor);

    // Rim light: a stroke in the liquid's own colour, so the flask reads
    // clearly against the dark machine and its colour is obvious even
    // when it is nearly empty.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.055)
      ..color = lighten.withValues(alpha: 0.95 * gloss);
    canvas
      ..drawCircle(center, r - rim.strokeWidth / 2, rim)
      ..drawRect(neckRect.deflate(rim.strokeWidth / 2), rim)
      ..drawRRect(collar.deflate(rim.strokeWidth / 2), rim)
      ..drawPath(cap, rim);

    // Starving alarm: a red ring OUTSIDE the glass. It surrounds the flask
    // rather than covering it, so the colour underneath stays fully legible
    // while the bottle still screams for attention.
    if (alarm > 0) {
      const alarmColor = Color(0xFFFF4D4D);
      canvas.drawCircle(
        center,
        r + rim.strokeWidth * 0.9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.8, w * 0.07)
          ..color = alarmColor.withValues(alpha: 0.95 * alarm),
      );
      canvas.drawCircle(
        center,
        r + rim.strokeWidth * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, w * 0.10)
          ..color = alarmColor.withValues(alpha: 0.30 * alarm)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10),
      );
    }

    // Count label centered on the body. Always full white — the number is
    // the second thing the player reads, after the colour.
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.style(
          size: math.min(r * 1.0, w * 0.40),
          weight: 700,
          color: Colors.white,
          shadows: const [
            Shadow(color: Color(0x88000000), offset: Offset(0, 1.2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, center.dy - textPainter.height / 2),
    );

    canvas.restore();
  }
}

/// Widget wrapper used in the tray and slots.
class BottleView extends StatelessWidget {
  const BottleView({
    super.key,
    required this.color,
    required this.label,
    this.squash = 1,
    this.wobble = 0,
    this.depth = 0,
    this.alarm = 0,
    this.fill = 1,
  });

  final Color color;
  final String label;
  final double squash;
  final double wobble;

  /// Visual distance 0..1 — softens highlights, never the hue.
  final double depth;

  /// Starving alarm ring intensity 0..1.
  final double alarm;

  /// Liquid level 0..1.
  final double fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BottleWidgetPainter(
        color: color,
        label: label,
        squash: squash,
        wobble: wobble,
        depth: depth,
        alarm: alarm,
        fill: fill,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BottleWidgetPainter extends CustomPainter {
  _BottleWidgetPainter({
    required this.color,
    required this.label,
    required this.squash,
    required this.wobble,
    required this.depth,
    required this.alarm,
    required this.fill,
  });

  final Color color;
  final String label;
  final double squash;
  final double wobble;
  final double depth;
  final double alarm;
  final double fill;

  static const _painter = BottlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _painter.paint(
      canvas,
      size,
      color: color,
      label: label,
      squash: squash,
      wobble: wobble,
      depth: depth,
      alarm: alarm,
      fill: fill,
    );
  }

  @override
  bool shouldRepaint(_BottleWidgetPainter old) =>
      old.color != color ||
      old.label != label ||
      old.squash != squash ||
      old.wobble != wobble ||
      old.depth != depth ||
      old.alarm != alarm ||
      old.fill != fill;
}
