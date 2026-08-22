import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A brief message that floats above the board and fades itself out.
///
/// Deliberately not a [SnackBar]: the game screen keeps a fixed-height tray
/// pinned to the bottom, and a SnackBar would either cover it or push the
/// layout. An overlay entry sits above everything and changes nothing.
abstract final class GameToast {
  static OverlayEntry? _current;

  /// Shows [message], replacing any toast already on screen so repeated
  /// presses do not stack.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1900),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        duration: duration,
        onFinished: () {
          if (_current == entry) {
            _current = null;
            entry.remove();
          }
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Removes the visible toast, if any. Safe to call when none is showing.
  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.duration,
    required this.onFinished,
  });

  final String message;
  final Duration duration;
  final VoidCallback onFinished;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _fade.forward().then((_) {
      if (!mounted) return;
      // A cancellable Timer rather than Future.delayed: dismissing the toast
      // early must not leave a callback pending on a disposed widget.
      _hold = Timer(widget.duration, () async {
        if (!mounted) return;
        await _fade.reverse();
        if (mounted) widget.onFinished();
      });
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(context).padding.bottom + 90,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _fade,
          builder: (context, child) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - _fade.value)),
              child: child,
            ),
          ),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.panelDeep.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTypography.label(
                  size: 14,
                  color: AppColors.textBright,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
