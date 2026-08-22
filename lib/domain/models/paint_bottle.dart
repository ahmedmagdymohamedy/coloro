/// A single paint bottle holding [capacity] pixels of one palette color.
class PaintBottle {
  const PaintBottle({
    required this.id,
    required this.colorIndex,
    required this.capacity,
  });

  /// Unique within a level, used as a widget/animation key.
  final int id;

  /// Index into the level's [PixelGrid.palette].
  final int colorIndex;

  /// How many pixels this bottle can paint.
  final int capacity;
}
