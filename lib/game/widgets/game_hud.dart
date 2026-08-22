import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/level.dart';

/// Top bar: back button, level name, animated progress.
///
/// Listens to one narrow channel — [progress] (per collected pixel) — so
/// pixel takes never rebuild anything wider than the bar and the
/// percentage text.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.level,
    required this.progress,
    required this.onBack,
  });

  final Level level;
  final ValueListenable<double> progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(
        children: [
          _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${level.number}. ${level.displayName}',
                  style: AppTypography.style(size: 17, weight: 650),
                ),
                const SizedBox(height: 5),
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (context, p, _) => _ProgressBar(progress: p),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) => Text(
              '${(p * 100).floor()}%',
              style: AppTypography.style(
                size: 18,
                weight: 700,
                color: AppColors.candyYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(color: AppColors.panelDeep),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.candyCyan, AppColors.candyGreen],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      shape: const CircleBorder(
        side: BorderSide(color: Color(0x22FFFFFF)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: AppColors.textSoft, size: 22),
        ),
      ),
    );
  }
}
