import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Deep-space gradient with softly glowing pixel squares drifting upward.
class MenuBackground extends StatelessWidget {
  const MenuBackground({super.key, required this.animation});

  /// Unbounded, ever-growing time value in seconds.
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MenuBackgroundPainter(animation),
      child: const SizedBox.expand(),
    );
  }
}

class _MenuBackgroundPainter extends CustomPainter {
  _MenuBackgroundPainter(this.time) : super(repaint: time);

  final Animation<double> time;

  // Deterministic star field.
  static final _pixels = List.generate(26, (i) {
    final rnd = math.Random(i * 77);
    return (
      x: rnd.nextDouble(),
      depth: 0.35 + rnd.nextDouble() * 0.65,
      size: 6 + rnd.nextDouble() * 14,
      speed: 0.012 + rnd.nextDouble() * 0.03,
      phase: rnd.nextDouble(),
      color: AppColors.festive[i % AppColors.festive.length],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgBottom],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint();
    for (final p in _pixels) {
      final progress = (p.phase + t * p.speed) % 1.2;
      final y = size.height * (1.1 - progress);
      final x = size.width * p.x +
          math.sin(t * 0.6 + p.phase * math.pi * 2) * 18 * p.depth;
      final wobble = 0.85 + 0.15 * math.sin(t * 2 + p.phase * 9);
      final s = p.size * p.depth * wobble;
      final alpha = 0.05 + 0.13 * p.depth;

      paint.color = p.color.withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: s, height: s),
          Radius.circular(s * 0.28),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MenuBackgroundPainter oldDelegate) => false;
}
