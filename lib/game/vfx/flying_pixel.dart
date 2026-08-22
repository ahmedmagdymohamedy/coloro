import 'dart:ui';

/// A pixel in flight from its grid cell into a moving bottle, travelling
/// along a curved (quadratic bezier) path whose endpoint chases the
/// bottle's live position.
class FlyingPixel {
  FlyingPixel({
    required this.from,
    required this.to,
    required this.control,
    required this.color,
    required this.cellIndex,
    required this.duration,
    required this.size,
    this.follow,
  });

  final Offset from;

  /// Current target — refreshed every frame from [follow] while the bottle
  /// is trackable, frozen at its last known position otherwise.
  Offset to;
  final Offset control;
  final Color color;
  final int cellIndex;
  final double duration;
  final double size;

  /// Resolves the bottle's live position; null keeps the last target.
  final Offset? Function()? follow;

  double t = 0;

  bool get arrived => t >= 1;

  void update(double dt) {
    final live = follow?.call();
    if (live != null) to = live;
    t = (t + dt / duration).clamp(0.0, 1.0);
  }

  Offset positionAt(double tt) {
    final u = 1 - tt;
    return from * (u * u) + control * (2 * u * tt) + to * (tt * tt);
  }

  Offset get position {
    // Ease-in: pixels accelerate towards the canvas.
    final e = t * t * (3 - 2 * t);
    return positionAt(e);
  }
}
