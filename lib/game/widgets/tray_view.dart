import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/display_palette.dart';
import '../../domain/models/paint_bottle.dart';
import '../game_controller.dart';
import 'bottle_view.dart';

/// The bottle supply: columns of queued bottles. Only the front (top) bottle
/// of each column can be launched.
///
/// The tray has a FIXED height, and bottles are keyed by id inside a Stack
/// with animated positions — take one, and the queue visibly glides forward
/// (slide + grow + brighten) instead of snapping.
class TrayView extends StatelessWidget {
  const TrayView({
    super.key,
    required this.controller,
    required this.columnKeys,
    required this.onTapColumn,
  });

  final GameController controller;
  final List<GlobalKey> columnKeys;
  final void Function(int column) onTapColumn;

  static const visibleRows = 3;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: const BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < controller.tray.length; c++)
                Expanded(
                  child: _TrayColumn(
                    anchorKey: columnKeys[c],
                    bottles: controller.tray[c],
                    palette: controller.grid.palette,
                    onTap: () => onTapColumn(c),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrayColumn extends StatelessWidget {
  const _TrayColumn({
    required this.anchorKey,
    required this.bottles,
    required this.palette,
    required this.onTap,
  });

  final GlobalKey anchorKey;
  final List<PaintBottle> bottles;
  final List<int> palette;
  final VoidCallback onTap;

  // Row geometry (fixed → the tray never changes height).
  static const _rowTop = [0.0, 66.0, 117.0];
  static const _rowW = [50.0, 40.0, 40.0];
  static const _rowH = [60.0, 46.0, 46.0];
  // Depth, NOT dimming: queued rows soften their highlights and sink into
  // a deeper shadow, but their liquid keeps its exact colour — reading the
  // queue's colours ahead of time is how the player plans.
  static const _rowDepth = [0.0, 0.5, 0.8];
  static const _height = 184.0;

  @override
  Widget build(BuildContext context) {
    final hidden = bottles.length - TrayView.visibleRows;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: bottles.isEmpty ? null : onTap,
      child: SizedBox(
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Invisible anchor at the front row: flight animations start
            // here (bottles themselves move between rows).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _rowH[0],
              child: Center(
                child: SizedBox(key: anchorKey, width: _rowW[0], height: 60),
              ),
            ),
            for (var i = 0; i < bottles.length && i < TrayView.visibleRows; i++)
              AnimatedPositioned(
                key: ValueKey('bottle_${bottles[i].id}'),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                top: _rowTop[i],
                left: 0,
                right: 0,
                height: _rowH[i],
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    width: _rowW[i],
                    height: _rowH[i],
                    child: _EnterPop(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _rowDepth[i]),
                        duration: const Duration(milliseconds: 260),
                        builder: (context, depth, _) => BottleView(
                          color: DisplayPalette.of(
                            palette[bottles[i].colorIndex],
                          ),
                          label: '${bottles[i].capacity}',
                          depth: depth,
                          // Fresh flasks wait nearly empty; they fill up
                          // with collected beads once docked.
                          fill: 0.14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: _height - 16,
              left: 0,
              right: 0,
              height: 16,
              child: hidden > 0
                  ? Center(
                      child: Text(
                        '+$hidden',
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 13,
                          color: AppColors.textDim,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouncy scale-in played once when a bottle first becomes visible
/// (promoted from the hidden part of the queue).
class _EnterPop extends StatelessWidget {
  const _EnterPop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, c) => Transform.scale(scale: scale, child: c),
      child: child,
    );
  }
}
