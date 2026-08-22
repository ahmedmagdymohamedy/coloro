import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/domain/models/pixel_grid.dart';
import 'package:flutter_test/flutter_test.dart';

PixelGrid gridWithCounts(List<int> counts) {
  final cells = <int>[];
  for (var color = 0; color < counts.length; color++) {
    cells.addAll(List.filled(counts[color], color));
  }
  // Pad to a rectangle with background.
  final cols = 10;
  while (cells.length % cols != 0) {
    cells.add(PixelGrid.background);
  }
  return PixelGrid(
    cols: cols,
    rows: cells.length ~/ cols,
    cells: cells,
    palette: List.generate(counts.length, (i) => 0xFF000000 | (i * 40 + 20)),
  );
}

void main() {
  group('BottleFactory', () {
    test('bottle capacities sum exactly to each color count', () {
      final grid = gridWithCounts([137, 61, 22, 9]);
      final bottles = BottleFactory.build(grid, seed: 3);
      for (var color = 0; color < 4; color++) {
        final sum = bottles
            .where((b) => b.colorIndex == color)
            .fold<int>(0, (a, b) => a + b.capacity);
        expect(sum, grid.colorCounts[color], reason: 'color $color');
      }
    });

    test('no bottle is empty or oversized', () {
      final grid = gridWithCounts([200, 45, 33]);
      final bottles = BottleFactory.build(grid, seed: 9);
      for (final b in bottles) {
        expect(b.capacity, greaterThan(0));
        expect(b.capacity, lessThanOrEqualTo(40));
      }
    });

    test('ids are unique', () {
      final grid = gridWithCounts([90, 90]);
      final bottles = BottleFactory.build(grid);
      expect(bottles.map((b) => b.id).toSet().length, bottles.length);
    });

    test('deterministic for the same seed', () {
      final grid = gridWithCounts([120, 40]);
      final a = BottleFactory.build(grid, seed: 7)
          .map((b) => '${b.colorIndex}:${b.capacity}')
          .toList();
      final b = BottleFactory.build(grid, seed: 7)
          .map((b) => '${b.colorIndex}:${b.capacity}')
          .toList();
      expect(a, b);
    });
  });
}
