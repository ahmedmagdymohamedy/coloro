/// The fixed colour palette every level is drawn from.
///
/// ## Why this exists
///
/// Levels used to carry their own palette, quantized out of each source
/// image by frequency. Two colours only had to be `_mergeDistance` (52)
/// apart to survive as separate entries, so a level could — and regularly
/// did — ship with two greens a player reads as one colour. The report was
/// blunt: *"I see all of that is green but the game sees two kinds of
/// green."* A board you cannot read is a board you cannot plan on, which is
/// the entire game.
///
/// So the palette is no longer derived. Every level's art is mapped onto
/// these twelve colours and nothing else, and a level's `maxColors` simply
/// decides how many of the twelve it keeps.
///
/// ## How these twelve were chosen
///
/// Two constraints, both enforced by `test/game_palette_test.dart`:
///
/// 1. **One colour per 30° hue slot.** This is the constraint that actually
///    answers the complaint. A numeric distance metric happily accepts a
///    dark cyan and a light cyan as "different", but a player reads them as
///    one colour lighter — exactly the failure being fixed. Locking each
///    entry to its own hue slot makes that impossible by construction.
/// 2. **Maximum minimum separation** under the quantizer's own
///    perception-weighted distance, searched over candidate lightness and
///    saturation values within each slot. The result separates the closest
///    pair by **62**, against the 52 at which the old quantizer would have
///    merged two colours outright.
///
/// Every entry also clears a contrast floor against the board (`#150F2C`)
/// and the drained socket (`#080614`), so no colour can disappear into the
/// background of a dark picture.
///
/// ## These are display-ready
///
/// They are authored to be rendered as-is. `DisplayPalette` deliberately
/// passes them through untouched — its old lightness remap existed to
/// rescue dark art-derived palettes, and re-applying it here would compress
/// all twelve back into one bright band and undo the separation above
/// (measured: it collapses the closest pair from 62 to 21).
///
/// Deliberately Flutter-free so the pure image pipeline can use it.
abstract final class GamePalette {
  /// Opaque ARGB, ordered by hue starting at red.
  static const colors = <int>[
    0xFFD61F1F, // red      hue   0
    0xFFE27A12, // orange   hue  30
    0xFFE2E212, // yellow   hue  60
    0xFF7ABE37, // lime     hue  90
    0xFF12E212, // green    hue 120
    0xFFA2EBC7, // spring   hue 150
    0xFF1FD6D6, // cyan     hue 180
    0xFF127AE2, // azure    hue 210
    0xFF8989E6, // blue     hue 240
    0xFF7A2BCA, // violet   hue 270
    0xFFED26ED, // magenta  hue 300
    0xFFF797C7, // rose     hue 330
  ];

  /// Human-readable names, index-aligned with [colors]. Diagnostics only.
  static const names = <String>[
    'red', 'orange', 'yellow', 'lime', 'green', 'spring',
    'cyan', 'azure', 'blue', 'violet', 'magenta', 'rose',
  ];

  static int get length => colors.length;

  /// RGB triples without the alpha byte, for the distance maths.
  static List<List<int>> get rgb => [
        for (final c in colors)
          [(c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF],
      ];
}
