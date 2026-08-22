
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../domain/models/level.dart';
import 'quantizer.dart';
import '../domain/models/pixel_grid.dart';

/// Turns a level image into a playable [PixelGrid]:
/// decode → downscale to the level's gridSize → detect background →
/// quantize to at most maxColors → drop marginal colors.
///
/// The heavy work runs in a background isolate via [compute]. Results are
/// cached per (asset, difficulty) so menu previews and gameplay share them.
class LevelProcessor {
  LevelProcessor._();

  static final Map<String, PixelGrid> _cache = {};

  static Future<PixelGrid> process(Level level) async {
    final cached = _cache[level.cacheKey];
    if (cached != null) return cached;

    final data = await rootBundle.load(level.assetPath);
    final grid = await compute(_processBytes, _Request(
      bytes: data.buffer.asUint8List(),
      gridSize: level.gridSize,
      maxColors: level.maxColors,
    ));
    return _cache[level.cacheKey] = grid;
  }

  /// Pure, isolate-friendly, unit-testable pipeline (see quantizer.dart).
  @visibleForTesting
  static PixelGrid buildGrid(
    img.Image source, {
    required int gridSize,
    required int maxColors,
  }) =>
      quantizeImage(source, gridSize: gridSize, maxColors: maxColors);
}

class _Request {
  const _Request({
    required this.bytes,
    required this.gridSize,
    required this.maxColors,
  });

  final Uint8List bytes;
  final int gridSize;
  final int maxColors;
}

PixelGrid _processBytes(_Request request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    throw StateError('Could not decode level image');
  }
  return LevelProcessor.buildGrid(
    decoded,
    gridSize: request.gridSize,
    maxColors: request.maxColors,
  );
}
