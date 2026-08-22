import 'package:flutter/material.dart';

import '../widgets/bottle_view.dart';
import 'particle.dart';
import 'vfx_controller.dart';

/// Draws every transient effect above the game UI: flying pixels with soft
/// trails, arcing bottles, and the particle pool.
class VfxPainter extends CustomPainter {
  VfxPainter({required this.vfx, required Listenable repaint})
      : super(repaint: repaint);

  final VfxController vfx;

  static const _bottlePainter = BottlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Flying pixels + short motion trail.
    for (final p in vfx.pixels) {
      final pos = p.position;
      for (var k = 1; k <= 3; k++) {
        final tt = (p.t - k * 0.05).clamp(0.0, 1.0);
        final trailPos = p.positionAt(tt * tt * (3 - 2 * tt));
        paint.color = p.color.withValues(alpha: 0.16 / k);
        canvas.drawCircle(trailPos, p.size * (0.5 - k * 0.08), paint);
      }
      paint.color = p.color;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: p.size, height: p.size),
        Radius.circular(p.size * 0.3),
      );
      canvas.drawRRect(rect, paint);
      paint.color = Colors.white.withValues(alpha: 0.55);
      canvas.drawCircle(
          pos.translate(-p.size * 0.18, -p.size * 0.18), p.size * 0.16, paint);
    }

    // Flying bottles.
    for (final b in vfx.bottles) {
      final pos = b.position;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(b.rotation);
      canvas.translate(-b.size.width / 2, -b.size.height / 2);
      _bottlePainter.paint(
        canvas,
        b.size,
        color: b.color,
        label: '${b.remaining}',
        fill: 1 - b.remaining / b.bottle.capacity,
        squash: 2 - b.stretch,
      );
      canvas.restore();
    }

    // Particles.
    for (final p in vfx.particles) {
      final alpha = p.vitality.clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);
      switch (p.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(p.position, p.size * (0.4 + 0.6 * p.vitality), paint);
        case ParticleShape.square:
          canvas.save();
          canvas.translate(p.position.dx, p.position.dy);
          canvas.rotate(p.rotation);
          final s = p.size * (0.5 + 0.5 * p.vitality);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s, height: s),
              Radius.circular(s * 0.25),
            ),
            paint,
          );
          canvas.restore();
        case ParticleShape.streak:
          final dir = p.velocity / (p.velocity.distance + 0.001);
          canvas.drawLine(
            p.position,
            p.position - dir * (p.size * 3),
            paint
              ..strokeWidth = p.size * 0.5
              ..strokeCap = StrokeCap.round,
          );
        case ParticleShape.ring:
          final expansion = 1 - p.vitality;
          canvas.drawCircle(
            p.position,
            8 + expansion * 34,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1 + 3 * p.vitality
              ..color = p.color.withValues(alpha: alpha),
          );
      }
    }
  }

  @override
  bool shouldRepaint(VfxPainter oldDelegate) => true;
}
