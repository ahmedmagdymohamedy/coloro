import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/paint_bottle.dart';
import 'flying_bottle.dart';
import 'flying_pixel.dart';
import 'particle.dart';

/// Owns every transient visual effect: particle pool, in-flight pixels and
/// bottles, and screen shake. Updated once per frame from the game ticker.
class VfxController {
  final List<Particle> particles = [];
  final List<FlyingPixel> pixels = [];
  final List<FlyingBottle> bottles = [];

  final _random = math.Random();

  static const _maxParticles = 900;

  /// Current shake displacement, applied to the machine area.
  Offset shakeOffset = Offset.zero;
  double _shakeEnergy = 0;
  double _shakeTime = 0;

  void Function(FlyingPixel pixel)? onPixelArrived;
  void Function(FlyingBottle bottle)? onBottleArrived;

  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
    particles.removeWhere((p) => p.dead);

    for (var i = pixels.length - 1; i >= 0; i--) {
      final p = pixels[i];
      p.update(dt);
      if (p.arrived) {
        pixels.removeAt(i);
        onPixelArrived?.call(p);
      }
    }

    for (var i = bottles.length - 1; i >= 0; i--) {
      final b = bottles[i];
      b.update(dt);
      if (b.arrived) {
        bottles.removeAt(i);
        onBottleArrived?.call(b);
      }
    }

    // Decaying sine shake.
    if (_shakeEnergy > 0.01) {
      _shakeTime += dt;
      _shakeEnergy *= math.pow(0.0001, dt).toDouble();
      shakeOffset = Offset(
        math.sin(_shakeTime * 55) * _shakeEnergy,
        math.cos(_shakeTime * 47) * _shakeEnergy * 0.8,
      );
    } else {
      shakeOffset = Offset.zero;
      _shakeEnergy = 0;
    }
  }

  bool get hasWork =>
      particles.isNotEmpty || pixels.isNotEmpty || bottles.isNotEmpty;

  void shake(double energy) {
    _shakeEnergy = math.max(_shakeEnergy, energy);
  }

  // -------------------------------------------------------------------------
  // Spawners
  // -------------------------------------------------------------------------

  void launchPixel({
    required Offset from,
    required Offset to,
    required Color color,
    required int cellIndex,
    required double size,
    Offset? control,
    Offset? Function()? follow,
  }) {
    final mid = Offset.lerp(from, to, 0.5)!;
    final side = (_random.nextDouble() - 0.5) * 140;
    final jitter = Offset(
      (_random.nextDouble() - 0.5) * 30,
      (_random.nextDouble() - 0.5) * 30,
    );
    pixels.add(FlyingPixel(
      from: from,
      to: to,
      control: control != null
          ? control + jitter
          : mid.translate(side, -40 - _random.nextDouble() * 50),
      color: color,
      cellIndex: cellIndex,
      duration: 0.30 + _random.nextDouble() * 0.12,
      size: size,
      follow: follow,
    ));
  }

  void launchBottle({
    required PaintBottle bottle,
    required Color color,
    required Offset from,
    required Offset to,
    required int slotIndex,
    required Size size,
    int? remaining,
    double duration = 0.38,
  }) {
    bottles.add(FlyingBottle(
      bottle: bottle,
      color: color,
      from: from,
      to: to,
      slotIndex: slotIndex,
      size: size,
      remaining: remaining,
      duration: duration,
    ));
  }

  /// Expanding shockwave ring (bottle pops).
  void ring(Offset at, Color color) {
    _spawn(1, () {
      return Particle(
        position: at,
        velocity: Offset.zero,
        color: color,
        size: 3,
        maxLife: 0.45,
        shape: ParticleShape.ring,
      );
    });
  }

  /// Tiny sparkle where a pixel lands.
  void sparkle(Offset at, Color color, {double scale = 1}) {
    _spawn(3 + _random.nextInt(2), () {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 30 + _random.nextDouble() * 70;
      return Particle(
        position: at,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: _random.nextBool() ? color : const Color(0xFFFFFFFF),
        size: (2 + _random.nextDouble() * 2.5) * scale,
        maxLife: 0.25 + _random.nextDouble() * 0.2,
        drag: 4,
        shape: ParticleShape.circle,
      );
    });
  }

  /// Chunky burst for a bottle pop.
  void burst(Offset at, Color color) {
    _spawn(16, () {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 90 + _random.nextDouble() * 220;
      return Particle(
        position: at,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: Color.lerp(color, const Color(0xFFFFFFFF),
            _random.nextDouble() * 0.45)!,
        size: 3 + _random.nextDouble() * 5,
        maxLife: 0.45 + _random.nextDouble() * 0.35,
        gravity: 350,
        drag: 2.5,
        rotation: _random.nextDouble() * math.pi,
        spin: (_random.nextDouble() - 0.5) * 14,
      );
    });
  }

  /// Celebration confetti raining from the top of [bounds].
  void confetti(Rect bounds, List<Color> colors, {int count = 90}) {
    _spawn(count, () {
      final x = bounds.left + _random.nextDouble() * bounds.width;
      return Particle(
        position: Offset(x, bounds.top - _random.nextDouble() * 120),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 120,
          60 + _random.nextDouble() * 160,
        ),
        color: colors[_random.nextInt(colors.length)],
        size: 5 + _random.nextDouble() * 5,
        maxLife: 2.2 + _random.nextDouble() * 1.4,
        gravity: 160,
        drag: 0.8,
        rotation: _random.nextDouble() * math.pi,
        spin: (_random.nextDouble() - 0.5) * 10,
      );
    });
  }

  /// Radial firework used behind the completion card.
  void firework(Offset at, Color color) {
    _spawn(26, () {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 60 + _random.nextDouble() * 260;
      return Particle(
        position: at,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: Color.lerp(color, const Color(0xFFFFFFFF),
            _random.nextDouble() * 0.5)!,
        size: 2.5 + _random.nextDouble() * 3,
        maxLife: 0.7 + _random.nextDouble() * 0.6,
        gravity: 120,
        drag: 1.6,
        shape: _random.nextBool() ? ParticleShape.circle : ParticleShape.streak,
      );
    });
  }

  void _spawn(int count, Particle Function() create) {
    for (var i = 0; i < count; i++) {
      if (particles.length >= _maxParticles) return;
      particles.add(create());
    }
  }

  void clear() {
    particles.clear();
    pixels.clear();
    bottles.clear();
    shakeOffset = Offset.zero;
    _shakeEnergy = 0;
  }
}
