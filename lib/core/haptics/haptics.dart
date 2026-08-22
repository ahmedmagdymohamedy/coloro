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
}
