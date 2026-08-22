import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Bundled Fredoka variable font. Weight is selected via font variations so
/// a single .ttf covers the whole family.
abstract final class AppTypography {
  static const family = 'Fredoka';

  static TextStyle style({
    double size = 16,
    double weight = 600,
    Color color = AppColors.textBright,
    double? height,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontVariations: [FontVariation('wght', weight)],
      // Fallback weight for engines that ignore variations.
      fontWeight: weight >= 650 ? FontWeight.w700 : FontWeight.w500,
      color: color,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle title({double size = 44, Color color = AppColors.textBright}) =>
      style(
        size: size,
        weight: 700,
        color: color,
        shadows: const [
          Shadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 6),
        ],
      );

  static TextStyle button({double size = 22}) => style(
        size: size,
        weight: 700,
        shadows: const [
          Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2),
        ],
      );

  static TextStyle label({double size = 15, Color color = AppColors.textSoft}) =>
      style(size: size, weight: 550, color: color);
}
