import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/models/level.dart';
import '../../../domain/models/pixel_grid.dart';
import '../../../shared/widgets/bouncy_button.dart';
import '../../../shared/widgets/pixel_picture.dart';

/// Staged celebration card: scrim → card springs in → the finished picture
/// pops into view → buttons rise. The reward IS the completed image.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.level,
    required this.grid,
    required this.hasNextLevel,
    required this.onNext,
    required this.onReplay,
    required this.onMenu,
  });

  final Level level;

  /// The finished picture, shown in full color as the reward.
  final PixelGrid grid;
  final bool hasNextLevel;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onMenu;

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stage;

  @override
  void initState() {
    super.initState();
    _stage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  double _seg(double from, double to, [Curve curve = Curves.easeOut]) {
    final t = ((_stage.value - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _stage,
      builder: (context, _) {
        final scrim = _seg(0, 0.15);
        final cardIn = _seg(0.08, 0.42, Curves.elasticOut);
        final pictureIn = _seg(0.36, 0.62, Curves.elasticOut);
        final buttonsIn = _seg(0.62, 0.85, Curves.easeOutBack);

        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4 * scrim, sigmaY: 4 * scrim),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45 * scrim),
                ),
              ),
            ),
            Center(
              child: Transform.scale(
                scale: cardIn,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A2F68), AppColors.panel],
                    ),
                    border:
                        Border.all(color: const Color(0x33FFFFFF), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.level.displayName.toUpperCase(),
                        style: AppTypography.style(
                          size: 15,
                          weight: 650,
                          color: AppColors.candyCyan,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Level Complete!',
                          style: AppTypography.title(size: 28)),
                      const SizedBox(height: 18),
                      // The finished picture — the actual reward.
                      Transform.scale(
                        scale: pictureIn,
                        child: Container(
                          width: 190,
                          height: 190,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.frameLight,
                                AppColors.frame,
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: ColoredBox(
                              color: AppColors.panelDeep,
                              child: PixelPicture(grid: widget.grid),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Transform.translate(
                        offset: Offset(0, 30 * (1 - buttonsIn)),
                        child: Opacity(
                          opacity: buttonsIn.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              BouncyButton(
                                onPressed: widget.hasNextLevel
                                    ? widget.onNext
                                    : widget.onMenu,
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                ),
                                pulse: true,
                                shine: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.hasNextLevel
                                          ? 'NEXT LEVEL'
                                          : 'ALL DONE!',
                                      style: AppTypography.button(),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _SmallAction(
                                    icon: Icons.replay_rounded,
                                    label: 'Replay',
                                    onTap: widget.onReplay,
                                  ),
                                  const SizedBox(width: 22),
                                  _SmallAction(
                                    icon: Icons.home_rounded,
                                    label: 'Menu',
                                    onTap: widget.onMenu,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onTap,
      color: AppColors.panelDeep,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      borderRadius: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textSoft),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.label(size: 14)),
        ],
      ),
    );
  }
}
