import 'package:coloro/data/level_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

img.Image solidStripes(List<int> rgbColors, {int width = 40, int height = 40}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  final stripe = width / rgbColors.length;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final c = rgbColors[(x / stripe).floor().clamp(0, rgbColors.length - 1)];
      image.setPixelRgba(x, y, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, 255);
    }
  }
  return image;
}

void main() {
  group('LevelProcessor.buildGrid', () {
    test('center-crops non-square images to a square grid', () {
      final image = solidStripes([0xFF0000, 0x0000FF], width: 200, height: 100);
      final grid =
          LevelProcessor.buildGrid(image, gridSize: 20, maxColors: 8);
      expect(grid.cols, 20);
      expect(grid.rows, 20);
    });

    test('small pixel art is used 1:1 (after square crop)', () {
      final image = solidStripes([0xFF0000], width: 12, height: 9);
      final grid =
          LevelProcessor.buildGrid(image, gridSize: 30, maxColors: 8);
      expect(grid.cols, 9);
      expect(grid.rows, 9);
    });

    test('full square: every cell is paintable, including near-white areas',
        () {
      // Half red, half near-white — white is content now, not background.
      final image = img.Image(width: 20, height: 20, numChannels: 4);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          if (x < 10) {
            image.setPixelRgba(x, y, 220, 30, 60, 255);
          } else {
            image.setPixelRgba(x, y, 250, 248, 252, 255);
          }
        }
      }
      final grid =
          LevelProcessor.buildGrid(image, gridSize: 20, maxColors: 8);
      expect(grid.palette.length, 2);
      expect(grid.fillableCount, 400);
    });

    test('transparent pixels are composited over the backdrop color', () {
      final image = img.Image(width: 10, height: 10, numChannels: 4);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          image.setPixelRgba(x, y, 10, 200, 90, x < 5 ? 255 : 0);
        }
      }
      final grid =
          LevelProcessor.buildGrid(image, gridSize: 10, maxColors: 4);
      // Everything paintable: the green half plus a backdrop-colored half.
      expect(grid.fillableCount, 100);
      expect(grid.palette.length, 2);
    });

    test('caps the palette at maxColors', () {
      final image = solidStripes(
        [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0xFF00FF, 0x00FFFF],
        width: 60,
        height: 30,
      );
      final grid =
          LevelProcessor.buildGrid(image, gridSize: 30, maxColors: 3);
      expect(grid.palette.length, lessThanOrEqualTo(3));
      for (final c in grid.cells) {
        expect(c, inInclusiveRange(0, grid.palette.length - 1));
      }
    });

    test('color counts sum to fillable cells', () {
      final image = solidStripes([0xFF0000, 0x0000FF, 0x00AA00]);
      final grid =
          LevelProcessor.buildGrid(image, gridSize: 24, maxColors: 8);
      final sum = grid.colorCounts.fold<int>(0, (a, b) => a + b);
      expect(sum, grid.fillableCount);
      expect(grid.fillableCount, grid.cols * grid.rows,
          reason: 'full-square levels have no background cells');
    });
  });
}
