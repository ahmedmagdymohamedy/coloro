import 'package:flutter/services.dart';

/// Exception-safe haptic feedback wrappers.
abstract final class Haptics {
  static void light() {
    HapticFeedback.lightImpact().ignore();
  }

  static void medium() {
    HapticFeedback.mediumImpact().ignore();
  }

  static void heavy() {
    HapticFeedback.heavyImpact().ignore();
  }

  static void selection() {
    HapticFeedback.selectionClick().ignore();
  }

  /// The lightest tap the OS offers, used for the continuous "drinking"
  /// texture while pixels stream into a flask. Deliberately the selection
  /// click rather than an impact: repeated impacts at gameplay rate feel
  /// like a rattle, and on iOS the Taptic Engine coalesces them anyway.
  static void tick() {
    HapticFeedback.selectionClick().ignore();
  }
}
