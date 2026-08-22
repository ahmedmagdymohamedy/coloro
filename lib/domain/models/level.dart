/// A playable level and its difficulty knobs.
///
/// Difficulty is controlled by two dials:
///  * [gridSize]  – how many pixels the image is split into along its longest
///                  side. More cells = longer, harder levels.
///  * [maxColors] – how many palette colors the image is re-rendered with.
///                  More colors = more bottle types to juggle.
///
/// Values come from `assets/levels/levels.json` when present, otherwise from
/// an automatic ramp based on the level number (see [LevelCatalog]).
class Level {
  const Level({
    required this.number,
    required this.assetPath,
    required this.gridSize,
    required this.maxColors,
    this.name,
    this.hard = false,
    this.shuffleWindow = 1,
    this.dealSeed = 0,
  });

  /// How far a bottle may drift from where it is needed in the tray.
  /// 1 = perfectly ordered (trivial); larger = the player must plan and
  /// park bottles. Chosen per level by the generator, always proven
  /// solvable.
  final int shuffleWindow;

  /// Seed of the proven-solvable shuffle for this level.
  final int dealSeed;

  /// Marked as a hard level in levels.json (every 5th campaign level).
  final bool hard;

  /// 1-based level number, drives ordering and the difficulty ramp.
  final int number;

  /// Full asset path, e.g. `assets/levels/1.jpg`.
  final String assetPath;

  /// Maximum cells along the image's longest side.
  final int gridSize;

  /// Palette cap after color quantization.
  final int maxColors;

  /// Optional display name ("Moon", "Heart", ...).
  final String? name;

  String get displayName => name ?? 'Level $number';

  /// Cache key for processed grids: same asset with different difficulty
  /// settings produces a different puzzle.
  String get cacheKey => '$assetPath|$gridSize|$maxColors';
}
