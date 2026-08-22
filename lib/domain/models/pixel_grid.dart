/// The processed puzzle: a small grid of palette indices.
///
/// Kept plugin-free and plain so it can cross isolate boundaries and be
/// constructed directly in tests.
class PixelGrid {
  PixelGrid({
    required this.cols,
    required this.rows,
    required this.cells,
    required this.palette,
  })  : assert(cells.length == cols * rows),
        colorCounts = List<int>.filled(palette.length, 0) {
    for (final c in cells) {
      if (c >= 0) colorCounts[c]++;
    }
    fillableCount = colorCounts.fold(0, (a, b) => a + b);
  }

  final int cols;
  final int rows;

  /// Palette index per cell, or [background] for cells that stay empty.
  final List<int> cells;

  /// ARGB colors of the quantized palette.
  final List<int> palette;

  /// Number of fillable cells per palette color.
  final List<int> colorCounts;

  /// Total number of fillable cells.
  late final int fillableCount;

  static const background = -1;

  int cellAt(int x, int y) => cells[y * cols + x];

  bool get isEmpty => fillableCount == 0;
}
