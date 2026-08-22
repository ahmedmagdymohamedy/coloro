import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_controller.dart';
import 'bottle_view.dart';

/// The row of machine slots. Bottles dock here and drink pixels straight
/// off the picture's bottom edge — a starving bottle (its color nowhere on
/// the bottom edge) trembles with a red "!".
class SlotBar extends StatelessWidget {
  const SlotBar({
    super.key,
    required this.controller,
    required this.slotKeys,
    required this.repaint,
  });

  final GameController controller;
  final List<GlobalKey> slotKeys;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repaint,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < controller.slots.length; i++)
              _Slot(
                key: ValueKey('slot_$i'),
                anchorKey: slotKeys[i],
                slot: controller.slots[i],
                palette: controller.grid.palette,
                time: controller.time,
              ),
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.anchorKey,
    required this.slot,
    required this.palette,
    required this.time,
  });

  final GlobalKey anchorKey;
  final SlotBottle? slot;
  final List<int> palette;
  final double time;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    final visible = s != null && s.phase == SlotPhase.docked;
    final starving = visible && s.starving;
    final working = visible && time - s.lastSprayAt < 0.15;

    return SizedBox(
      width: 52,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Holder stand: an open bowl with a wavy rim the flask sits in.
          Positioned.fill(
            top: 10,
            child: CustomPaint(
              key: anchorKey,
              painter: _HolderPainter(jammed: starving),
            ),
          ),
          if (visible)
            Positioned(
              bottom: 17,
              width: 38,
              height: 48,
              child: BottleView(
                color: Color(palette[s.bottle.colorIndex]),
                label: '${s.remaining}',
                fill: 1 - s.remaining / s.bottle.capacity,
                dim: starving ? 0.45 : 0,
                wobble: starving
                    ? math.sin(time * 5 + s.bottle.id) * 0.10
                    : (working
                        ? math.sin(time * 22 + s.bottle.id) * 0.05
                        : 0),
                squash: working
                    ? 1 + math.sin(time * 26 + s.bottle.id * 2) * 0.04
                    : 1,
              ),
            ),
          // Front rim of the stand — the flask sits INSIDE the bowl.
          if (visible)
            Positioned.fill(
              top: 10,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _HolderPainter(jammed: starving, front: true),
                ),
              ),
            ),
          if (starving)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF5C5C),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 4),
                  ],
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The holder stand: a thick-outlined open bowl whose rim dips into a deep
/// W (like the reference). Drawn in two passes so the flask sits INSIDE:
/// the full bowl behind the bottle, and the lower front wall again in
/// front of it.
class _HolderPainter extends CustomPainter {
  _HolderPainter({required this.jammed, this.front = false});

  final bool jammed;

  /// true → draw only the lower front wall (painted above the bottle).
  final bool front;

  Path _outline(double w, double h) => Path()
    ..moveTo(w * 0.05, h * 0.26)
    ..quadraticBezierTo(w * 0.04, h * 0.08, w * 0.15, h * 0.10)
    ..quadraticBezierTo(w * 0.24, h * 0.12, w * 0.28, h * 0.26)
    ..quadraticBezierTo(w * 0.33, h * 0.50, w * 0.42, h * 0.40)
    ..quadraticBezierTo(w * 0.48, h * 0.33, w * 0.50, h * 0.32)
    ..quadraticBezierTo(w * 0.52, h * 0.33, w * 0.58, h * 0.40)
    ..quadraticBezierTo(w * 0.67, h * 0.50, w * 0.72, h * 0.26)
    ..quadraticBezierTo(w * 0.76, h * 0.12, w * 0.85, h * 0.10)
    ..quadraticBezierTo(w * 0.96, h * 0.08, w * 0.95, h * 0.26)
    ..lineTo(w * 0.88, h * 0.88)
    ..quadraticBezierTo(w * 0.87, h * 0.97, w * 0.76, h * 0.97)
    ..lineTo(w * 0.24, h * 0.97)
    ..quadraticBezierTo(w * 0.13, h * 0.97, w * 0.12, h * 0.88)
    ..close();

  Path _cavity(double w, double h) => Path()
    ..moveTo(w * 0.16, h * 0.32)
    ..quadraticBezierTo(w * 0.17, h * 0.21, w * 0.23, h * 0.24)
    ..quadraticBezierTo(w * 0.30, h * 0.28, w * 0.34, h * 0.42)
    ..quadraticBezierTo(w * 0.38, h * 0.56, w * 0.46, h * 0.47)
    ..quadraticBezierTo(w * 0.50, h * 0.43, w * 0.54, h * 0.47)
    ..quadraticBezierTo(w * 0.62, h * 0.56, w * 0.66, h * 0.42)
    ..quadraticBezierTo(w * 0.70, h * 0.28, w * 0.77, h * 0.24)
    ..quadraticBezierTo(w * 0.83, h * 0.21, w * 0.84, h * 0.32)
    ..lineTo(w * 0.79, h * 0.83)
    ..quadraticBezierTo(w * 0.78, h * 0.90, w * 0.70, h * 0.90)
    ..lineTo(w * 0.30, h * 0.90)
    ..quadraticBezierTo(w * 0.22, h * 0.90, w * 0.21, h * 0.83)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rim = jammed ? const Color(0xFF9A6478) : const Color(0xFF8D93B0);
    final inside = jammed ? const Color(0xFF3A2334) : const Color(0xFF241F42);

    if (front) {
      // Only the bowl's LOWER front wall overlaps the flask — a subtle
      // tuck at its base, never covering the body or the count.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(w * 0.16, h * 0.68, w * 0.84, h));
      canvas.drawPath(_outline(w, h), Paint()..color = rim);
      canvas.drawPath(_cavity(w, h), Paint()..color = inside);
      canvas.restore();
      return;
    }

    canvas.drawPath(_outline(w, h), Paint()..color = rim);
    canvas.drawPath(_cavity(w, h), Paint()..color = inside);
  }

  @override
  bool shouldRepaint(_HolderPainter old) =>
      old.jammed != jammed || old.front != front;
}
