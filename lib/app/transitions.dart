import 'package:flutter/material.dart';

/// Custom page transitions that keep the arcade feel between screens.
abstract final class GameTransitions {
  /// Gentle zoom + fade, used for menu → game.
  static PageRouteBuilder<T> zoomFade<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 1.08, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
