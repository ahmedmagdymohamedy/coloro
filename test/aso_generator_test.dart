@Tags(['aso'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coloro/app/coloro_app.dart';
import 'package:coloro/core/theme/app_typography.dart';
import 'package:coloro/data/level_catalog.dart';
import 'package:coloro/screens/game/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every store asset (icon, feature graphic, phone screenshots)
/// from the REAL game, so the listing can never drift from the product.
///
///   ASO_OUT=aso flutter test test/aso_generator_test.dart
///
/// It is a generator, not a check: without ASO_OUT it does nothing.
void main() {
  final outDir = Platform.environment['ASO_OUT'];

  setUpAll(() async {
    final data = rootBundle.load('assets/fonts/Fredoka.ttf');
    await (FontLoader('Fredoka')..addFont(data)).load();

    // Widget tests ship no icon font, so every Icon renders as a tofu box.
    // Load the real one out of the SDK or the screenshots look broken.
    final root = Platform.environment['FLUTTER_ROOT'] ??
        (() {
          final exe = Process.runSync('which', ['flutter']).stdout.toString().trim();
          return exe.isEmpty ? '' : File(exe).parent.parent.path;
        })();
    final iconFont =
        File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFont.existsSync()) {
      final bytes = iconFont.readAsBytesSync();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();
    } else {
      // ignore: avoid_print
      print('WARNING: MaterialIcons font not found — icons will be boxes.');
    }

    if (outDir != null) Directory(outDir).createSync(recursive: true);
  });

  /// Encoding a picture to PNG needs real async, which only exists inside
  /// runAsync during widget tests.
  Future<void> render(
    WidgetTester tester,
    String name,
    int width,
    int height,
    void Function(Canvas canvas, Size size) painter,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter(canvas, Size(width.toDouble(), height.toDouble()));
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      picture.dispose();
      image.dispose();
      // ignore: avoid_print
      print('  -> $name ($width x $height)');
    });
  }

  testWidgets('icon', (tester) async {
    if (outDir == null) return;
    await render(tester, 'icon.png', 1024, 1024, _paintIcon);
    // Play Console demands exactly 512x512 for the store icon. Rendered at
    // native size rather than downscaled, so the rim stays crisp.
    await render(tester, 'icon_512.png', 512, 512, _paintIcon);
    // Android adaptive icon: foreground must stay inside the safe circle.
    await render(tester, 'icon_foreground.png', 1024, 1024,
        (c, s) => _paintIcon(c, s, adaptive: true));
    await render(tester, 'icon_background.png', 1024, 1024, _paintBackdrop);
    // White-on-transparent status-bar icon, installed into android res/.
    await render(tester, 'ic_stat_notify.png', 96, 96, _paintNotificationIcon);
    // Not shipped: a simulation of what a round-mask launcher actually
    // renders, so the adaptive layers can be checked without installing.
    await render(
        tester, 'icon_adaptive_preview.png', 512, 512, _paintAdaptivePreview);
  });

  testWidgets('feature graphic', (tester) async {
    if (outDir == null) return;
    await render(tester, 'feature_graphic.png', 1024, 500, _paintFeatureGraphic);
  });

  testWidgets('screenshots', (tester) async {
    if (outDir == null) return;

    SharedPreferences.setMockInitialValues({'unlocked_level': 24});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RepaintBoundary(child: ColoroApp()));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    Future<void> shot(String file, String headline, String sub) async {
      final boundary = find
          .byType(RepaintBoundary)
          .evaluate()
          .first
          .renderObject! as RenderRepaintBoundary;
      late ui.Image raw;
      await tester.runAsync(() async {
        raw = await boundary.toImage(pixelRatio: 3);
      });
      await render(tester, file, 1080, 1920,
          (c, s) => _composeScreenshot(c, s, raw, headline, sub));
      raw.dispose();
    }

    // Slot 1 is a promo hero, not an app capture: the first screenshot has
    // to sell the concept, and a raw menu shot cannot.
    await render(tester, 'screenshot_1.png', 1080, 1920, _paintPromoHero);

    // Open a colourful mid-campaign level.
    final catalog = await tester.runAsync(LevelCatalog.load);
    final level = catalog!.levels[19];
    Navigator.of(tester.element(find.text('PLAY'))).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: level, hasNextLevel: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final trayFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TrayColumn',
    );
    for (var attempt = 0;
        attempt < 20 && trayFinder.evaluate().isEmpty;
        attempt++) {
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final game =
        tester.state<GameScreenState>(find.byType(GameScreen)).debugGame!;

    Future<void> play(int ticks) async {
      for (var i = 0; i < ticks; i++) {
        for (var c = 0; c < 4; c++) {
          final col = game.tray[c];
          if (col.isNotEmpty &&
              game.hasFreeSlot &&
              game.takableCountFor(col.first.colorIndex) > 0) {
            await tester.tap(trayFinder.at(c), warnIfMissed: false);
          }
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await play(12);
    await shot('screenshot_2.png', 'Drain it colour by colour',
        'Bottles drink the bottom edge');

    await play(60);
    await shot('screenshot_3.png', 'Pick the right bottle',
        'Guess wrong and the machine jams');

    await play(140);
    await shot('screenshot_4.png', 'Watch the picture vanish',
        'Oddly satisfying, every time');

    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // Never ship a screenshot with a spinner in it: wait for the carousel
    // previews to finish decoding.
    for (var i = 0;
        i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('screenshot_5.png', 'Replay any level',
        'Swipe through your collection');
  });
}

// ---------------------------------------------------------------------------
// Brand palette
// ---------------------------------------------------------------------------

const _deep = Color(0xFF2A0E5C);
const _mid = Color(0xFF7B2FF7);
const _hot = Color(0xFFC33BD8);
const _ink = Color(0xFF25103F);
const _glass = Color(0xFFF3ECFF);
const _pink = Color(0xFFFF3D8B);
const _orange = Color(0xFFFF9F1C);
const _yellow = Color(0xFFFFE03B);
const _green = Color(0xFF3DDC84);
const _cyan = Color(0xFF2BD4F0);
const _white = Color(0xFFFDFEFF);

/// A chunky candy bead with a thick dark rim — the game's signature shape.
void _bead(Canvas canvas, Rect r, Color color, {double rim = 0}) {
  final hsl = HSLColor.fromColor(color);
  final light = hsl.withLightness((hsl.lightness + 0.20).clamp(0, 1)).toColor();
  final dark = hsl.withLightness((hsl.lightness - 0.18).clamp(0, 1)).toColor();
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.28));
  if (rim > 0) {
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim
        ..strokeJoin = StrokeJoin.round
        ..color = _ink,
    );
  }
  canvas
    ..drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
          stops: const [0, 0.55, 1],
        ).createShader(r),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + r.width * 0.16, r.top + r.height * 0.13,
            r.width * 0.34, r.height * 0.20),
        Radius.circular(r.width * 0.13),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
}

/// Bright radial burst — casual-game icons live or die on background pop.
void _paintBackdrop(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  final centre = Offset(w * 0.5, h * 0.46);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = RadialGradient(
        colors: const [_hot, _mid, _deep],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: centre, radius: w * 0.78)),
  );
  // Sun rays.
  final ray = Paint()..color = Colors.white.withValues(alpha: 0.07);
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final path = Path()
      ..moveTo(centre.dx, centre.dy)
      ..lineTo(centre.dx + math.cos(a - 0.12) * w,
          centre.dy + math.sin(a - 0.12) * w)
      ..lineTo(centre.dx + math.cos(a + 0.12) * w,
          centre.dy + math.sin(a + 0.12) * w)
      ..close();
    canvas.drawPath(path, ray);
  }
}

/// The icon: one oversized potion flask holding a rainbow, tilted for
/// energy, with a thick dark rim so it still reads at 48 px.
void _paintIcon(Canvas canvas, Size size, {bool adaptive = false}) {
  final w = size.width, h = size.height;
  if (!adaptive) _paintBackdrop(canvas, size);

  // ic_launcher.xml already wraps this drawable in `inset 16%`, so the canvas
  // it receives IS the safe zone. Shrinking again here is what reduced the
  // flask to a dot floating in a purple tile on the launcher.
  //
  // The lift exists because the flask's mass sits low: its silhouette spans
  // roughly 0.05h..1.00h, so centring the *canvas* leaves the art visually
  // low. 0.86 keeps the whole silhouette inside the circular mask.
  canvas
    ..save()
    ..translate(w / 2, h / 2 - (adaptive ? h * 0.028 : 0))
    ..scale(adaptive ? 0.86 : 0.88)
    ..rotate(-0.10)
    ..translate(-w / 2, -h / 2);

  final cx = w * 0.5;
  final bodyC = Offset(cx, h * 0.645);
  final bodyR = w * 0.315;
  final rim = w * 0.055;

  final neckRect = Rect.fromCenter(
    center: Offset(cx, bodyC.dy - bodyR - h * 0.055),
    width: w * 0.19,
    height: h * 0.15,
  );
  final collar = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(cx, neckRect.top + h * 0.008),
      width: w * 0.30,
      height: h * 0.062,
    ),
    Radius.circular(w * 0.028),
  );

  // One silhouette so the rim never draws internal seams.
  var flask = Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: bodyC, radius: bodyR)),
    Path()..addRect(neckRect),
  );
  flask = Path.combine(PathOperation.union, flask, Path()..addRRect(collar));

  canvas
    ..drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 1.7
        ..strokeJoin = StrokeJoin.round
        ..color = _ink,
    )
    ..drawPath(flask, Paint()..color = _glass);

  // Rainbow inside the glass — the "colours" promise, instantly legible.
  canvas.save();
  canvas.clipPath(
    Path()
      ..addOval(Rect.fromCircle(center: bodyC, radius: bodyR - rim * 0.9)),
  );
  const bands = [_pink, _orange, _yellow, _green, _cyan];
  final bandH = (bodyR - rim * 0.9) * 2 / bands.length;
  for (var i = 0; i < bands.length; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        bodyC.dx - bodyR,
        bodyC.dy - bodyR + rim * 0.9 + i * bandH,
        bodyR * 2,
        bandH + 1,
      ),
      Paint()..color = bands[i],
    );
  }
  // Gloss sweep across the glass.
  canvas.restore();

  // Glass reflection: an arc hugging the inner rim reads as curved glass,
  // where a floating blob just looks like a smudge.
  canvas.drawArc(
    Rect.fromCircle(center: bodyC, radius: bodyR * 0.70),
    math.pi * 1.08,
    math.pi * 0.42,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bodyR * 0.15
      ..color = Colors.white.withValues(alpha: 0.60),
  );

  // Cork.
  final corkBottom = collar.outerRect.top + h * 0.006;
  final cork = Path()
    ..moveTo(cx, corkBottom - h * 0.135)
    ..lineTo(cx + w * 0.105, corkBottom - h * 0.036)
    ..quadraticBezierTo(cx + w * 0.09, corkBottom, cx + w * 0.042, corkBottom)
    ..lineTo(cx - w * 0.042, corkBottom)
    ..quadraticBezierTo(cx - w * 0.09, corkBottom, cx - w * 0.105,
        corkBottom - h * 0.036)
    ..close();
  canvas
    ..drawPath(
      cork,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 1.7
        ..strokeJoin = StrokeJoin.round
        ..color = _ink,
    )
    ..drawPath(cork, Paint()..color = _orange);

  canvas.restore();

  // Beads tumbling in — drawn outside the tilt so they stay upright.
  final beadRim = w * 0.030;
  if (adaptive) {
    // A launcher masks this drawable to a circle, so anything near a corner
    // is cut in half. These sit inside that circle, in the gaps either side
    // of the narrow cork.
    _bead(canvas, Rect.fromLTWH(w * 0.718, h * 0.158, w * 0.115, w * 0.115),
        _cyan, rim: beadRim);
    _bead(canvas, Rect.fromLTWH(w * 0.158, h * 0.198, w * 0.095, w * 0.095),
        _yellow, rim: beadRim);
    _bead(canvas, Rect.fromLTWH(w * 0.805, h * 0.355, w * 0.080, w * 0.080),
        _pink, rim: beadRim);
  } else {
    _bead(canvas, Rect.fromLTWH(w * 0.775, h * 0.075, w * 0.150, w * 0.150),
        _cyan, rim: beadRim);
    _bead(canvas, Rect.fromLTWH(w * 0.065, h * 0.115, w * 0.115, w * 0.115),
        _yellow, rim: beadRim);
    _bead(canvas, Rect.fromLTWH(w * 0.855, h * 0.300, w * 0.095, w * 0.095),
        _pink, rim: beadRim);
  }
}

/// Reproduces the launcher's own compositing: background layer, foreground
/// layer inset by the 16% that `ic_launcher.xml` applies, then the circular
/// mask most launchers use. Anything clipped here is clipped on a real phone.
void _paintAdaptivePreview(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  canvas
    ..save()
    ..clipPath(Path()
      ..addOval(Rect.fromCircle(
          center: Offset(w / 2, h / 2), radius: w * 0.5)))
    ..drawRect(Offset.zero & size, Paint()..color = _deep);

  _paintBackdrop(canvas, size);

  // The 16% inset from ic_launcher.xml.
  const inset = 0.16;
  canvas
    ..save()
    ..translate(w * inset, h * inset)
    ..scale(1 - inset * 2);
  _paintIcon(canvas, size, adaptive: true);
  canvas
    ..restore()
    ..restore();
}

/// Android status-bar icon. The system throws away every colour and keeps
/// only the alpha channel, so this must be a flat white silhouette — feeding
/// it the full-colour icon is what produces the notorious grey blob.
void _paintNotificationIcon(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  final white = Paint()..color = Colors.white;
  final cx = w * 0.5;
  final bodyC = Offset(cx, h * 0.60);
  final bodyR = w * 0.30;

  final neck = Rect.fromCenter(
    center: Offset(cx, bodyC.dy - bodyR - h * 0.085),
    width: w * 0.18,
    height: h * 0.20,
  );
  final collar = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(cx, neck.top + h * 0.02),
      width: w * 0.30,
      height: h * 0.075,
    ),
    Radius.circular(w * 0.03),
  );
  var flask = Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: bodyC, radius: bodyR)),
    Path()..addRect(neck),
  );
  flask = Path.combine(PathOperation.union, flask, Path()..addRRect(collar));

  // A punched-out band reads as liquid at 24 dp, where interior detail would
  // just close up into a solid blob. Subtracted from the path rather than
  // cleared with a blend mode, so no layer is needed.
  flask = Path.combine(
    PathOperation.difference,
    flask,
    Path()
      ..addRect(Rect.fromLTWH(
          bodyC.dx - bodyR, bodyC.dy - bodyR * 0.34, bodyR * 2, bodyR * 0.30)),
  );
  canvas.drawPath(flask, white);
}

/// A candy letter tile, the same treatment the in-game title uses.
void _letterTile(Canvas canvas, Rect r, String letter, Color color) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.26));
  canvas
    ..drawRRect(rr.shift(const Offset(0, 7)), Paint()..color = const Color(0x66000000))
    ..drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.28)!, color],
        ).createShader(r),
    )
    ..drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.06
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  _text(canvas, letter, Offset(r.center.dx, r.top + r.height * 0.14),
      size: r.height * 0.60, align: TextAlign.center);
}

/// A simplified flask, used for the promo hero's bottle row.
void _promoFlask(Canvas canvas, Offset centre, double r, Color color) {
  final ink = _ink;
  final body = Path()..addOval(Rect.fromCircle(center: centre, radius: r));
  final neck = Rect.fromCenter(
      center: Offset(centre.dx, centre.dy - r - r * 0.36),
      width: r * 0.62,
      height: r * 0.66);
  final flask = Path.combine(PathOperation.union, body, Path()..addRect(neck));
  canvas
    ..drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    )
    ..drawPath(flask, Paint()..color = _glass)
    ..save()
    ..clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r * 0.80)))
    ..drawRect(
      Rect.fromLTWH(centre.dx - r, centre.dy - r * 0.20, r * 2, r * 1.4),
      Paint()..color = color,
    )
    ..restore();
  // Cork.
  final corkTop = neck.top - r * 0.46;
  final cork = Path()
    ..moveTo(centre.dx, corkTop)
    ..lineTo(centre.dx + r * 0.34, neck.top)
    ..lineTo(centre.dx - r * 0.34, neck.top)
    ..close();
  canvas
    ..drawPath(
      cork,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.20
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    )
    ..drawPath(cork, Paint()..color = color);
}

/// Screenshot slot 1: a designed hero that states the promise. A raw menu
/// capture cannot sell a puzzle nobody has seen yet.
void _paintPromoHero(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  _paintBackdrop(canvas, Size(w, h * 1.25));

  // Wordmark in candy tiles.
  const letters = 'COLORO';
  const tileColors = [_pink, _orange, _yellow, _green, _cyan, Color(0xFFB197FC)];
  final tile = w * 0.135;
  final startX = (w - (tile * 6 + 14 * 5)) / 2;
  for (var i = 0; i < letters.length; i++) {
    _letterTile(
      canvas,
      Rect.fromLTWH(startX + i * (tile + 14), h * 0.075, tile, tile * 1.12),
      letters[i],
      tileColors[i],
    );
  }
  _text(canvas, 'Drain the pixels. Reveal the art.', Offset(w / 2, h * 0.185),
      size: 44, weight: 600, color: const Color(0xFFE6DBFF),
      align: TextAlign.center, maxWidth: w * 0.9);

  // The board: top half painted, bottom half already drunk away.
  final boardSide = w * 0.80;
  final board =
      Rect.fromLTWH((w - boardSide) / 2, h * 0.245, boardSide, boardSide);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(board.inflate(22), const Radius.circular(46)),
      Paint()..color = const Color(0xFF6C5DA8),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(30)),
      Paint()..color = const Color(0xFF150F2C),
    );
  const art = [
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 2, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0],
  ];
  final cell = board.width / 7.5;
  for (var y = 0; y < 7; y++) {
    for (var x = 0; x < 7; x++) {
      final r = Rect.fromLTWH(board.left + cell * 0.26 + x * cell,
          board.top + cell * 0.26 + y * cell, cell * 0.86, cell * 0.86);
      if (art[y][x] == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22)),
          Paint()..color = Colors.white.withValues(alpha: 0.06),
        );
      } else {
        _bead(canvas, r, art[y][x] == 1 ? _pink : _yellow);
      }
    }
  }

  // Bottle row, mirroring the machine's slots.
  const rowColors = [_pink, _cyan, _yellow, _green];
  final flaskR = w * 0.070;
  for (var i = 0; i < 4; i++) {
    // Clear of the board frame: a cork poking through it reads as a bug.
    _promoFlask(
      canvas,
      Offset(w * (0.20 + i * 0.20), h * 0.780),
      flaskR,
      rowColors[i],
    );
  }

  // Promise badges.
  const badges = ['300 LEVELS', 'NO TIMERS', 'PLAYS OFFLINE'];
  var bx = 0.0;
  final widths = <double>[];
  for (final b in badges) {
    final tp = TextPainter(
      text: TextSpan(
          text: b, style: AppTypography.style(size: 30, weight: 700)),
      textDirection: TextDirection.ltr,
    )..layout();
    widths.add(tp.width + 46);
  }
  final total = widths.reduce((a, b) => a + b) + 24 * (badges.length - 1);
  bx = (w - total) / 2;
  for (var i = 0; i < badges.length; i++) {
    final rect = Rect.fromLTWH(bx, h * 0.845, widths[i], 76);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(38)),
      Paint()..color = Colors.white.withValues(alpha: 0.13),
    );
    _text(canvas, badges[i], Offset(rect.center.dx, rect.top + 18),
        size: 30, weight: 700, color: _yellow, align: TextAlign.center);
    bx += widths[i] + 24;
  }
}

void _text(
  Canvas canvas,
  String text,
  Offset at, {
  required double size,
  double weight = 700,
  Color color = _white,
  double maxWidth = 4000,
  TextAlign align = TextAlign.left,
  List<Shadow>? shadows,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: AppTypography.style(
        size: size,
        weight: weight,
        color: color,
        shadows: shadows,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: maxWidth);
  final dx = align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
  tp.paint(canvas, Offset(dx, at.dy));
}

/// 1024x500 Play Store header: brand left, product right.
void _paintFeatureGraphic(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_mid, _deep],
      ).createShader(Offset.zero & size),
  );

  const scatter = [
    [0.575, 0.10, 0.9],
    [0.545, 0.74, 0.7],
    [0.62, 0.42, 0.55],
    [0.035, 0.06, 0.6],
    [0.030, 0.83, 0.7],
  ];
  const palette = [_pink, _cyan, _yellow, _green, _orange, _hot];
  for (var i = 0; i < scatter.length; i++) {
    final s = scatter[i];
    final side = 46.0 * s[2];
    _bead(canvas, Rect.fromLTWH(w * s[0], h * s[1], side, side),
        palette[i % palette.length], rim: 5);
  }

  _text(canvas, 'COLORO', Offset(w * 0.06, h * 0.22),
      size: 104,
      weight: 700,
      shadows: const [
        Shadow(color: Color(0xAA000000), offset: Offset(0, 5), blurRadius: 12),
      ]);
  _text(canvas, 'Drain the pixels. Reveal the art.', Offset(w * 0.065, h * 0.54),
      size: 33, weight: 600, color: const Color(0xFFE3D8FF));
  _text(canvas, '300 LEVELS   .   PLAYS OFFLINE', Offset(w * 0.065, h * 0.72),
      size: 24, weight: 650, color: _yellow);

  // Framed mini board so the header shows the actual product.
  final side = h * 0.70;
  final board = Rect.fromLTWH(w - side - 34, (h - side) / 2, side, side);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(board.inflate(15), const Radius.circular(32)),
      Paint()..color = const Color(0xFF6C5DA8),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(20)),
      Paint()..color = const Color(0xFF150F2C),
    );
  // Top half still painted, bottom half already drunk away — the whole
  // mechanic in one glance.
  const art = [
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 2, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0],
  ];
  final cell = board.width / 7.6;
  for (var y = 0; y < 7; y++) {
    for (var x = 0; x < 7; x++) {
      final v = art[y][x];
      final r = Rect.fromLTWH(board.left + cell * 0.3 + x * cell,
          board.top + cell * 0.3 + y * cell, cell * 0.86, cell * 0.86);
      if (v == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22)),
          Paint()..color = Colors.white.withValues(alpha: 0.07),
        );
      } else {
        _bead(canvas, r, [_deep, _pink, _yellow, _cyan][v]);
      }
    }
  }
}

/// Caption band on top, product below — the layout that converts on Play.
void _composeScreenshot(
  Canvas canvas,
  Size size,
  ui.Image shot,
  String headline,
  String sub,
) {
  final w = size.width;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_mid, _deep],
      ).createShader(Offset.zero & size),
  );

  _text(canvas, headline, Offset(w / 2, 92),
      size: 76,
      weight: 700,
      align: TextAlign.center,
      maxWidth: w * 0.9,
      shadows: const [
        Shadow(color: Color(0xAA000000), offset: Offset(0, 4), blurRadius: 12),
      ]);
  _text(canvas, sub, Offset(w / 2, 206),
      size: 38,
      weight: 600,
      color: const Color(0xFFD9CBFF),
      align: TextAlign.center,
      maxWidth: w * 0.86);

  const bandH = 300.0;
  // Fit the whole device screen: a clipped tray reads as a broken mockup.
  final scale = math.min(
    (w * 0.90) / shot.width,
    (size.height - bandH - 40) / shot.height,
  );
  final dest = Rect.fromLTWH(
    (w - shot.width * scale) / 2,
    bandH,
    shot.width * scale,
    shot.height * scale,
  );
  final rrect = RRect.fromRectAndRadius(dest, const Radius.circular(46));
  canvas
    ..drawRRect(
      rrect.shift(const Offset(0, 16)),
      Paint()..color = const Color(0x66000000),
    )
    ..save()
    ..clipRRect(rrect)
    ..drawImageRect(
      shot,
      Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
      dest,
      Paint()..filterQuality = FilterQuality.high,
    )
    ..restore()
    ..drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.35),
    );
}
