import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/level_processor.dart';
import '../../../domain/models/level.dart';
import '../../../domain/models/pixel_grid.dart';
import '../../../shared/widgets/pixel_picture.dart';

/// One card in the level carousel: a pixelated sneak peek for unlocked
/// levels, a lock for the ones still ahead.
class LevelPreviewCard extends StatelessWidget {
  const LevelPreviewCard({
    super.key,
    required this.level,
    required this.locked,
    required this.completed,
  });

  final Level level;
  final bool locked;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: locked
              ? const [Color(0xFF3A3258), Color(0xFF2C2647)]
              : const [AppColors.frameLight, AppColors.frame],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: AppColors.panelDeep,
                      child: locked
                          ? const Center(
                              child: Icon(
                                Icons.lock_rounded,
                                size: 44,
                                color: AppColors.textDim,
                              ),
                            )
                          : FutureBuilder<PixelGrid>(
                              future: LevelProcessor.process(level),
                              builder: (context, snapshot) {
                                final grid = snapshot.data;
                                if (grid == null) {
                                  return const Center(
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: AppColors.candyPurple,
                                      ),
                                    ),
                                  );
                                }
                                return PixelPicture(
                                  grid: grid,
                                  opacity: completed ? 0.85 : 0.55,
                                );
                              },
                            ),
                    ),
                  ),
                ),
                if (level.hard)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8495F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white54, width: 1),
                      ),
                      child: Text(
                        'HARD',
                        style: AppTypography.style(size: 10, weight: 700),
                      ),
                    ),
                  ),
                if (completed)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.candyGreen,
                        border: Border.all(color: Colors.white70, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            locked
                ? 'Level ${level.number}'
                : 'Level ${level.number} · ${level.displayName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              size: 15,
              weight: 650,
              color: locked ? AppColors.textDim : AppColors.textBright,
            ),
          ),
        ],
      ),
    );
  }
}
