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
  /// The palette is now a fixed, hand-tuned twelve (see [GamePalette]) that
  /// is authored display-ready, so this is a pass-through.
  ///
  /// It used to remap lightness into `[0.44, 0.86]` and lift saturation, to
  /// rescue the dark palettes the old quantizer derived from each level's
  /// art. Applying that to a fixed palette actively destroys it: the remap
  /// compresses all twelve colours into one bright band and pulls the
  /// closest pair from **62 apart down to 21** — far below the 52 at which
  /// two colours read as the same one. That is the exact failure the fixed
  /// palette exists to prevent.
  ///
  /// This stays as the single entry point every renderer goes through — the
  /// board's beads, the flasks, the flying pixels, the menu previews — which
  /// is what guarantees a bottle and the pixels it drinks are the same
  /// colour. If a future palette ever needs conditioning again, it belongs
  /// here and nowhere else.
  static Color of(int argb) => Color(argb);

  static Color fromColor(Color raw) => raw;

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
