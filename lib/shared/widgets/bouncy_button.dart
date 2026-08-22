import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_controller.dart';
import '../../core/audio/sfx.dart';
import '../../core/haptics/haptics.dart';

/// Juicy capsule button: squashes on press, springs back on release,
/// optionally idles with a soft breathing pulse and a travelling shine.
class BouncyButton extends StatefulWidget {
  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.gradient,
    this.color,
    this.pulse = false,
    this.shine = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
    this.borderRadius = 40,
    this.sound = Sfx.ui,
  });

  final Widget child;
  final VoidCallback onPressed;
  final Gradient? gradient;
  final Color? color;
  final bool pulse;
  final bool shine;
  final EdgeInsets padding;
  final double borderRadius;
  final Sfx sound;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  double _press = 0; // 0 = up, 1 = fully pressed

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.pulse || widget.shine) _idle.repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _setPress(double value) => setState(() => _press = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _setPress(1);
        Haptics.light();
      },
      onTapCancel: () => _setPress(0),
      onTapUp: (_) {
        _setPress(0);
        AudioController.instance.play(widget.sound);
        widget.onPressed();
      },
      child: AnimatedBuilder(
        animation: _idle,
        builder: (context, child) {
          final breathe =
              widget.pulse ? 1 + 0.035 * math.sin(_idle.value * math.pi * 2) : 1.0;
          return AnimatedScale(
            scale: breathe * (1 - 0.10 * _press),
            duration: const Duration(milliseconds: 120),
            curve: _press > 0 ? Curves.easeOut : Curves.elasticOut,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: widget.gradient,
            color: widget.color,
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                offset: Offset(0, 5),
                blurRadius: 10,
              ),
            ],
            border: Border.all(color: const Color(0x44FFFFFF), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(padding: widget.padding, child: widget.child),
              if (widget.shine)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _idle,
                    builder: (context, _) {
                      final x = -1.5 + _idle.value * 4;
                      return IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(x - 0.6, -1),
                              end: Alignment(x + 0.6, 1),
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
