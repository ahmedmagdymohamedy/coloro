import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/bouncy_button.dart';

/// The in-game explainer shown once, right after level 3, before the real OS
/// permission dialog.
///
/// The OS prompt is one-shot: if it is fired cold and dismissed, the player
/// can never be asked again from inside the app. So we ask for a *yes to the
/// idea* first, in our own voice, at the moment the player has just won three
/// levels in a row and likes the game. Only a yes here spends the OS prompt.
///
/// Returns true if the player opted in.
class NotifyPermissionSheet extends StatelessWidget {
  const NotifyPermissionSheet._();

  static Future<bool> show(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, _, _) => const NotifyPermissionSheet._(),
      transitionBuilder: (context, anim, _, child) {
        final t = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 5 * anim.value, sigmaY: 5 * anim.value),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55 * anim.value),
                ),
              ),
            ),
            Center(child: Transform.scale(scale: t, child: child)),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A2F68), AppColors.panel],
            ),
            border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
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
              // A friendly badge rather than a system bell — this card has to
              // feel like part of the game, not like the OS talking.
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.candyPink, AppColors.candyOrange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF5CA8),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 18),
              Text('Three in a row', style: AppTypography.title(size: 26)),
              const SizedBox(height: 10),
              Text(
                'You are on a roll. Want a quiet nudge when a new picture is '
                'ready for you?',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 15.5),
              ),
              const SizedBox(height: 22),
              BouncyButton(
                pulse: true,
                shine: true,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.ctaTop, AppColors.ctaBottom],
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Remind me', style: AppTypography.button(size: 20)),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style:
                      AppTypography.label(size: 14, color: AppColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
