import 'dart:ui';

enum ParticleShape { circle, square, streak, ring }

/// One particle in the [VfxController] pool.
class Particle {
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.maxLife,
    this.gravity = 0,
    this.drag = 0,
    this.rotation = 0,
    this.spin = 0,
    this.shape = ParticleShape.square,
  }) : life = maxLife;

  Offset position;
  Offset velocity;
  final Color color;
  double size;
  double life;
  final double maxLife;
  final double gravity;
  final double drag;
  double rotation;
  final double spin;
  final ParticleShape shape;

  /// 1.0 at birth, 0.0 at death.
  double get vitality => (life / maxLife).clamp(0.0, 1.0);

  bool get dead => life <= 0;

  void update(double dt) {
    life -= dt;
    velocity = Offset(
      velocity.dx * (1 - drag * dt),
      velocity.dy * (1 - drag * dt) + gravity * dt,
    );
    position += velocity * dt;
    rotation += spin * dt;
  }
}
