import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/bouncy_button.dart';

/// Machine-jam fail screen: every slot got blocked by a bottle whose color
/// is not on the picture's edge.
class LevelFailedOverlay extends StatefulWidget {
  const LevelFailedOverlay({
    super.key,
    required this.onRetry,
    required this.onMenu,
    this.onWatchAd,
    this.slotsNow = 0,
    this.slotsMax = 0,
  });

  final VoidCallback onRetry;
  final VoidCallback onMenu;

  /// Rewarded-ad rescue: null when no ad is ready or the machine has already
  /// grown to its maximum number of slots.
  final VoidCallback? onWatchAd;

  /// Slots the machine has now, and the ceiling rescues can reach. Shown so
  /// the player can see the offer is finite rather than wondering why it
  /// eventually stops appearing.
  final int slotsNow;
  final int slotsMax;

  @override
  State<LevelFailedOverlay> createState() => _LevelFailedOverlayState();
}

class _LevelFailedOverlayState extends State<LevelFailedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _stage;

  /// Reveals the ways OUT of the level (retry, menu).
  late final AnimationController _alternatives;
  Timer? _alternativesTimer;

  /// How long the rescue offer stands alone before the alternatives appear.
  ///
  /// The rescue is the only choice that keeps the board — the player's whole
  /// attempt — alive, and it was previously one of three equal-looking
  /// buttons that all arrived together, so it read as the least interesting
  /// of them. It now lands first and by itself; retry and menu follow two
  /// seconds later. Nothing is hidden and nothing is disabled: this only
  /// changes what the eye reaches first.
  static const _alternativesDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _stage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _alternatives = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    if (widget.onWatchAd == null) {
      // No rescue to feature — there is nothing to wait for.
      _alternatives.value = 1;
    } else {
      _alternativesTimer = Timer(_alternativesDelay, () {
        if (mounted) _alternatives.forward();
      });
    }
  }

  @override
  void dispose() {
    _alternativesTimer?.cancel();
    _alternatives.dispose();
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
      animation: Listenable.merge([_stage, _alternatives]),
      builder: (context, _) {
        final scrim = _seg(0, 0.2);
        final cardIn = _seg(0.1, 0.5, Curves.elasticOut);
        final buttonsIn = _seg(0.55, 0.8, Curves.easeOutBack);
        final altIn = Curves.easeOut.transform(_alternatives.value);
        // Little disappointed head-shake as the card lands.
        final wiggle =
            math.sin(_stage.value * math.pi * 6) * (1 - _stage.value) * 0.03;

        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4 * scrim, sigmaY: 4 * scrim),
                child: ColoredBox(
                  color: const Color(
                    0xFF25060E,
                  ).withValues(alpha: 0.55 * scrim),
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: wiggle,
                child: Transform.scale(
                  scale: cardIn,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF5A2740), AppColors.panel],
                      ),
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                        width: 1.5,
                      ),
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
                        const Icon(
                          Icons.settings_suggest_rounded,
                          size: 58,
                          color: Color(0xFFFF5C5C),
                          shadows: [
                            Shadow(color: Color(0x66FF0000), blurRadius: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Machine Jammed!',
                          style: AppTypography.title(size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Every bottle is starving — none of their colors\n'
                          'are on the picture\'s bottom edge.',
                          textAlign: TextAlign.center,
                          style: AppTypography.label(size: 14),
                        ),
                        const SizedBox(height: 22),
                        Transform.translate(
                          offset: Offset(0, 24 * (1 - buttonsIn)),
                          child: Opacity(
                            opacity: buttonsIn.clamp(0.0, 1.0),
                            child: Column(
                              children: [
                                if (widget.onWatchAd != null) ...[
                                  BouncyButton(
                                    onPressed: widget.onWatchAd!,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 38,
                                      vertical: 19,
                                    ),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF63E6BE),
                                        Color(0xFF0CA678),
                                      ],
                                    ),
                                    pulse: true,
                                    shine: true,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          'KEEP GOING  ·  +1 SLOT',
                                          style: AppTypography.button(size: 17),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    widget.slotsMax > 0
                                        ? 'Watch a short ad and resume this '
                                              'board  ·  ${widget.slotsNow} of '
                                              '${widget.slotsMax} slots'
                                        : 'Watch a short ad and resume this '
                                              'board',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.label(size: 12),
                                  ),
                                ],
                                // Retry and menu throw the board away, so
                                // they wait out [_alternativesDelay] and
                                // then fade in under the rescue.
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: altIn,
                                    child: Opacity(
                                      opacity: altIn,
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          BouncyButton(
                                            onPressed: widget.onRetry,
                                            gradient: widget.onWatchAd == null
                                                ? const LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      AppColors.ctaTop,
                                                      AppColors.ctaBottom,
                                                    ],
                                                  )
                                                : const LinearGradient(
                                                    colors: [
                                                      Color(0xFF4A4370),
                                                      Color(0xFF3A3458),
                                                    ],
                                                  ),
                                            pulse: widget.onWatchAd == null,
                                            shine: widget.onWatchAd == null,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.replay_rounded,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'TRY AGAIN',
                                                  style: AppTypography.button(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          BouncyButton(
                                            onPressed: widget.onMenu,
                                            color: AppColors.panelDeep,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 10,
                                            ),
                                            borderRadius: 22,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.home_rounded,
                                                  size: 18,
                                                  color: AppColors.textSoft,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Menu',
                                                  style: AppTypography.label(
                                                    size: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
            ),
          ],
        );
      },
    );
  }
}
