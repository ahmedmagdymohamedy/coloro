import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// Paints a glossy paint bottle. Shared by the tray, the machine slots and
/// the in-flight VFX so the bottle looks identical everywhere.
class BottlePainter {
  const BottlePainter();

  /// [squash] < 1 flattens the bottle (press/land), > 1 stretches it.
  /// [wobble] tilts it slightly (radians) while spraying.
  /// [fill] 0..1 sets the liquid level inside the round glass body — the
  /// flask fills up as the bottle collects beads.
  ///
  /// Flat potion-flask design after the reference: faceted drop cork, a
  /// collar band, short neck, round dark-glass body with bright liquid.
  void paint(
    Canvas canvas,
    Size size, {
    required Color color,
    required String label,
    double squash = 1,
    double wobble = 0,
    double dim = 0,
    double fill = 1,
  }) {
    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.rotate(wobble);
    canvas.scale(2 - squash, squash);
    canvas.translate(-size.width / 2, -size.height);

    final w = size.width, h = size.height;
    final hsl = HSLColor.fromColor(color);
    final capColor = hsl
        .withLightness((hsl.lightness + 0.05).clamp(0.0, 1.0))
        .toColor();
    final lighten =
        hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor();
    final glass = hsl
        .withLightness((hsl.lightness - 0.11).clamp(0.05, 1.0))
        .withSaturation((hsl.saturation * 0.88).clamp(0.0, 1.0))
        .toColor();
    final surface =
        hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();

    Color fade(Color c) => Color.lerp(c, const Color(0xFF3A3158), dim)!;

    // Round glass body in the lower part.
    final r = math.min(w * 0.50, h * 0.385);
    final center = Offset(w / 2, h - r - h * 0.02);
    canvas.drawCircle(center, r, Paint()..color = fade(glass));

    // Liquid: fills the inner body from the bottom, level = [fill].
    final inner = r * 0.90;
    final level = (fill.clamp(0.0, 1.0)) * 2 * inner;
    if (level > 0.01) {
      final liquidTop = center.dy + inner - level;
      canvas.save();
      canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: inner)));
      canvas.drawRect(
        Rect.fromLTRB(
            center.dx - inner, liquidTop, center.dx + inner, center.dy + inner),
        Paint()..color = fade(color),
      );
      // Liquid surface line.
      if (fill < 0.98) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, liquidTop),
            width: inner * 2,
            height: inner * 0.22,
          ),
          Paint()..color = fade(surface).withValues(alpha: 0.85),
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
    canvas.drawRect(neckRect, Paint()..color = fade(glass));

    // Collar band, slightly wider than the neck.
    final collar = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, neckRect.top),
        width: w * 0.40,
        height: h * 0.085,
      ),
      Radius.circular(w * 0.045),
    );
    canvas.drawRRect(collar, Paint()..color = fade(glass));

    // Faceted drop cork.
    final capBottom = collar.outerRect.top + h * 0.012;
    final capTop = capBottom - h * 0.20;
    final capMidY = capTop + (capBottom - capTop) * 0.60;
    final cap = Path()
      ..moveTo(w / 2, capTop)
      ..lineTo(w / 2 + w * 0.17, capMidY)
      ..quadraticBezierTo(
          w / 2 + w * 0.14, capBottom, w / 2 + w * 0.06, capBottom)
      ..lineTo(w / 2 - w * 0.06, capBottom)
      ..quadraticBezierTo(
          w / 2 - w * 0.14, capBottom, w / 2 - w * 0.17, capMidY)
      ..close();
    canvas.drawPath(cap, Paint()..color = fade(capColor));

    // Rim light: a stroke in the liquid's own colour, so the flask reads
    // clearly against the dark machine and its colour is obvious even
    // when it is nearly empty.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.055)
      ..color = fade(lighten).withValues(alpha: 0.95);
    canvas
      ..drawCircle(center, r - rim.strokeWidth / 2, rim)
      ..drawRect(
        neckRect.deflate(rim.strokeWidth / 2),
        rim,
      )
      ..drawRRect(collar.deflate(rim.strokeWidth / 2), rim)
      ..drawPath(cap, rim);

    // Count label centered on the body.
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.style(
          size: math.min(r * 1.0, w * 0.40),
          weight: 700,
          color: Colors.white.withValues(alpha: 1 - dim * 0.45),
          shadows: const [
            Shadow(color: Color(0x55000000), offset: Offset(0, 1.2)),
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
    this.dim = 0,
    this.fill = 1,
  });

  final Color color;
  final String label;
  final double squash;
  final double wobble;
  final double dim;

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
        dim: dim,
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
    required this.dim,
    required this.fill,
  });

  final Color color;
  final String label;
  final double squash;
  final double wobble;
  final double dim;
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
      dim: dim,
      fill: fill,
    );
  }

  @override
  bool shouldRepaint(_BottleWidgetPainter old) =>
      old.color != color ||
      old.label != label ||
      old.squash != squash ||
      old.wobble != wobble ||
      old.dim != dim ||
      old.fill != fill;
}
