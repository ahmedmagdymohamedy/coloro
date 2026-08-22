import 'package:flutter/material.dart';

/// The game's candy-arcade palette.
abstract final class AppColors {
  // Backgrounds.
  static const bgTop = Color(0xFF2E2250);
  static const bgBottom = Color(0xFF171030);
  static const panel = Color(0xFF241B44);
  static const panelDeep = Color(0xFF150F2C);

  // Machine frame.
  static const frame = Color(0xFF4A3E78);
  static const frameLight = Color(0xFF6C5DA8);
  static const frameShadow = Color(0xFF120C26);

  // Accents.
  static const candyPink = Color(0xFFFF5CA8);
  static const candyOrange = Color(0xFFFFA94D);
  static const candyYellow = Color(0xFFFFD43B);
  static const candyCyan = Color(0xFF3BC9DB);
  static const candyGreen = Color(0xFF51CF66);
  static const candyPurple = Color(0xFF9775FA);

  // Text.
  static const textBright = Color(0xFFFFFFFF);
  static const textSoft = Color(0xFFB9AEE0);
  static const textDim = Color(0xFF7C6FA8);

  // CTA gradient.
  static const ctaTop = Color(0xFFFFB13D);
  static const ctaBottom = Color(0xFFFF7A1A);

  static const starGold = Color(0xFFFFC53D);
  static const starEmpty = Color(0xFF3D3364);

  /// Bright cheerful set used for menu title letters and confetti.
  static const festive = <Color>[
    candyPink,
    candyOrange,
    candyYellow,
    candyGreen,
    candyCyan,
    candyPurple,
  ];
}
