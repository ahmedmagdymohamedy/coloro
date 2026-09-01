import 'dart:math' as math;

import 'package:coloro/data/game_palette.dart';
import 'package:coloro/data/quantizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the two properties the fixed palette exists for.
///
/// The complaint that produced it was "the game sees two kinds of green" —
/// so both a perceptual-distance floor *and* a hue-slot rule are asserted.
/// The distance floor alone is not enough: a dark cyan and a light cyan sit
/// far apart numerically and still read as one colour.
void main() {
  final colors = GamePalette.colors;

  test('the palette has twelve entries with matching names', () {
    expect(colors.length, 12);
    expect(GamePalette.names.length, colors.length);
  });

  test('no two colours are within the quantizer merge distance', () {
    // 52 is the distance at which the old quantizer merged two colours
    // outright, so anything at or below it is indistinguishable by the very
    // metric the pipeline snaps with. The optimised palette clears 60.
    var worst = double.infinity;
    late String worstPair;
    for (var i = 0; i < colors.length; i++) {
      for (var j = i + 1; j < colors.length; j++) {
        final d = paletteDistance(colors[i], colors[j]);
        if (d < worst) {
          worst = d;
          worstPair = '${GamePalette.names[i]}/${GamePalette.names[j]}';
        }
      }
    }
    expect(worst, greaterThan(60),
        reason: 'closest pair is $worstPair at ${worst.toStringAsFixed(1)}');
  });

  test('every colour owns its own hue slot', () {
    // This is the constraint that actually answers the report. Two colours
    // sharing a hue read as "the same colour, lighter" however far apart a
    // distance metric says they are.
    final hues = [for (final c in colors) _hueOf(c)]..sort();
    for (var i = 0; i < hues.length; i++) {
      final gap = (hues[(i + 1) % hues.length] - hues[i] + 360) % 360;
      expect(gap, greaterThanOrEqualTo(25),
          reason: 'hues ${hues[i]}° and ${hues[(i + 1) % hues.length]}° '
              'are only $gap° apart');
    }
  });

  test('no colour disappears into the board or a drained socket', () {
    const board = 0x150F2C;
    const socket = 0x080614;
    for (var i = 0; i < colors.length; i++) {
      final rgb = colors[i] & 0xFFFFFF;
      expect(paletteDistance(rgb, board), greaterThan(70),
          reason: '${GamePalette.names[i]} vanishes into the board');
      expect(paletteDistance(rgb, socket), greaterThan(70),
          reason: '${GamePalette.names[i]} vanishes into a socket');
    }
  });
}

int _hueOf(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;
  if (delta == 0) return 0;
  double h;
  if (maxC == r) {
    h = 60 * (((g - b) / delta) % 6);
  } else if (maxC == g) {
    h = 60 * (((b - r) / delta) + 2);
  } else {
    h = 60 * (((r - g) / delta) + 4);
  }
  return ((h % 360) + 360).round() % 360;
}
