import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/paint_bottle.dart';

/// A bottle arcing from the tray into its machine slot.
class FlyingBottle {
  FlyingBottle({
    required this.bottle,
    required this.color,
    required this.from,
    required this.to,
    required this.slotIndex,
    required this.size,
    int? remaining,
    this.duration = 0.38,
  }) : remaining = remaining ?? bottle.capacity;

  /// Paint still to collect — drives the label and liquid level.
  final int remaining;

  final PaintBottle bottle;
  final Color color;
  final Offset from;
  final Offset to;
  final int slotIndex;
  final Size size;
  final double duration;

  double t = 0;

  bool get arrived => t >= 1;

  void update(double dt) {
    t = (t + dt / duration).clamp(0.0, 1.0);
  }

  /// Eased position along an arc that lifts above the straight line.
  Offset get position {
    final e = easeOutBack(t);
    final base = Offset.lerp(from, to, e)!;
    final lift = math.sin(math.pi * t) * 46;
    return base.translate(0, -lift);
  }

  /// Slight forward tilt while flying.
  double get rotation => math.sin(math.pi * t) * 0.25 * (to.dx >= from.dx ? 1 : -1);

  /// Squash/stretch: stretched mid-flight, squashes on landing.
  double get stretch => 1 + math.sin(math.pi * t) * 0.18;
}

/// Ease-out-back without importing Flutter's animation lib here.
double easeOutBack(double t) {
  const c1 = 1.2;
  const c3 = c1 + 1;
  final u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}
