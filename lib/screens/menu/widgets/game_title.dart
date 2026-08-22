import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// "COLORO" as a row of candy tiles, each floating on its own rhythm.
class GameTitle extends StatelessWidget {
  const GameTitle({super.key, required this.animation});

  final Animation<double> animation;

  static const _letters = 'COLORO';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _letters.length; i++)
              Transform.translate(
                offset: Offset(0, math.sin(t * 2.2 + i * 0.9) * 5),
                child: Transform.rotate(
                  angle: math.sin(t * 1.6 + i * 1.3) * 0.05,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: 52,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(AppColors.festive[i], Colors.white, 0.25)!,
                          AppColors.festive[i],
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 5),
                          blurRadius: 8,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _letters[i],
                      style: AppTypography.style(
                        size: 36,
                        weight: 700,
                        shadows: const [
                          Shadow(color: Color(0x55000000), offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
