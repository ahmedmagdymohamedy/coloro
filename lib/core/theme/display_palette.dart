import 'package:flutter/material.dart';

/// The single source of truth for how a level's palette is *rendered*.
///
/// Levels are quantized straight out of the source artwork, so a dark
/// picture yields a dark palette — and on the dark machine board that made
/// remaining pixels indistinguishable from drained sockets ("some levels
/// have dark color, it's not clear who is filled and who is empty"). It
/// also made a bottle's liquid hard to match against the pixels it drinks
/// ("I can't tell the colors apart between the bottles and the pixels").
///
/// Both problems are *display* problems, so they are fixed here and nowhere
/// else. The puzzle itself — [PixelGrid.cells], the palette indices, the
/// bottle counts — is untouched, so every shipped solvability proof still
/// describes exactly the level the player gets.
///
/// Everything that draws a palette color (the bead atlas, the flask painter,
/// the flying-pixel VFX, the menu preview) goes through [of], which is why
/// a pixel and the bottle drinking it now read as the same color.
abstract final class DisplayPalette {
  /// Lightness is *remapped*, not clamped: `L' = _floor + L * _span`. A
  /// clamp would collapse two different dark colors onto the same value;
  /// a linear remap keeps their ordering and their distance, so the
  /// picture still reads as the original artwork — just lit.
  static const _lightnessFloor = 0.44;
  static const _lightnessSpan = 0.42; // → L' ∈ [0.44, 0.86]

  /// Saturation is lifted the same way, but only for colors that actually
  /// have a hue. A true grey has an arbitrary hue value, so boosting its
  /// saturation would tint it an essentially random color.
  static const _greyThreshold = 0.08;
  static const _saturationFloor = 0.32;
  static const _saturationSpan = 0.68;

  /// The rendered form of a palette color.
  static Color of(int argb) => fromColor(Color(argb));

  static Color fromColor(Color raw) {
    final hsl = HSLColor.fromColor(raw);
    final lightness = _lightnessFloor + hsl.lightness * _lightnessSpan;
    final saturation = hsl.saturation < _greyThreshold
        ? hsl.saturation
        : (_saturationFloor + hsl.saturation * _saturationSpan).clamp(0.0, 1.0);
    return hsl
        .withLightness(lightness.clamp(0.0, 1.0))
        .withSaturation(saturation)
        .toColor();
  }

  /// A whole palette, rendered. Cached per identity so the atlas and the
  /// flask painter never recompute the same conversion per frame.
  static List<Color> forPalette(List<int> argb) =>
      _cache[argb] ??= [for (final c in argb) of(c)];

  static final Map<List<int>, List<Color>> _cache = {};

  /// Lighter/darker relatives of a rendered color, used for bevels, rim
  /// lights and liquid surfaces. Kept here so a bead and a flask of the
  /// same color are shaded by identical amounts.
  static Color lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color darken(Color c, double amount) => lighten(c, -amount);
}
