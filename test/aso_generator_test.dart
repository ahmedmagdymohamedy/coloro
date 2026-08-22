@Tags(['aso'])
library;

import 'dart:io';
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
///   ASO_OUT=aso flutter test test/aso_generator_test.dart --tags aso
///
/// Skipped in normal runs — it is a generator, not a check.
void main() {
  final outDir = Platform.environment['ASO_OUT'];

  setUpAll(() async {
    final data = rootBundle.load('assets/fonts/Fredoka.ttf');
    await (FontLoader('Fredoka')..addFont(data)).load();
    if (outDir != null) Directory(outDir).createSync(recursive: true);
  });

  Future<void> save(ui.Image image, String name) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('  → $name (${image.width}×${image.height})');
  }

  Future<ui.Image> paint(
    int width,
    int height,
    void Function(Canvas canvas, Size size) painter,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, Size(width.toDouble(), height.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  testWidgets('generate store assets', (tester) async {
    if (outDir == null) return;

    // ---- 1. App icon -----------------------------------------------------
    await save(await paint(1024, 1024, (c, s) => _paintIcon(c, s)), 'icon.png');
    // Android adaptive icon: the foreground must sit inside the safe circle,
    // so it is drawn smaller on a transparent canvas.
    await save(
      await paint(1024, 1024, (c, s) => _paintIcon(c, s, adaptive: true)),
      'icon_foreground.png',
    );

    // ---- 2. Feature graphic (Play store header) --------------------------
    await save(
      await paint(1024, 500, (c, s) => _paintFeatureGraphic(c, s)),
      'feature_graphic.png',
    );

    // ---- 3. Phone screenshots from the live game -------------------------
    SharedPreferences.setMockInitialValues({'unlocked_level': 24});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RepaintBoundary(child: ColoroApp()));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    Future<ui.Image> shoot() async {
      final boundary = find.byType(RepaintBoundary).evaluate().first.renderObject!
          as RenderRepaintBoundary;
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage(pixelRatio: 3);
      });
      return image;
    }

    Future<void> shot(String file, String headline, String sub) async {
      final raw = await shoot();
      final composed = await paint(
        1080,
        1920,
        (c, s) => _composeScreenshot(c, s, raw, headline, sub),
      );
      await save(composed, file);
      raw.dispose();
    }

    await shot('screenshot_1.png', '300 pixel pictures', 'Every one hand-tuned');

    // Open a colourful mid-campaign level and play into it.
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

    await shot('screenshot_2.png', 'Drain it colour by colour', 'Bottles drink the bottom edge');

    final game =
        tester.state<GameScreenState>(find.byType(GameScreen)).debugGame!;
    for (var i = 0; i < 60; i++) {
      if (game.hasFreeSlot) {
        for (var c = 0; c < 4; c++) {
          final col = game.tray[c];
          if (col.isNotEmpty &&
              game.takableCountFor(col.first.colorIndex) > 0 &&
              game.hasFreeSlot) {
            await tester.tap(trayFinder.at(c), warnIfMissed: false);
          }
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('screenshot_3.png', 'Pick the right bottle', 'Guess wrong and the machine jams');

    for (var i = 0; i < 120; i++) {
      if (game.hasFreeSlot) {
        for (var c = 0; c < 4; c++) {
          final col = game.tray[c];
          if (col.isNotEmpty &&
              game.takableCountFor(col.first.colorIndex) > 0 &&
              game.hasFreeSlot) {
            await tester.tap(trayFinder.at(c), warnIfMissed: false);
          }
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('screenshot_4.png', 'Watch the picture vanish', 'Oddly satisfying, every time');

    // Back to the menu for the level-carousel shot.
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await shot('screenshot_5.png', 'Replay any level', 'Swipe your whole collection');
  });
}

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

const _deep = Color(0xFF1B1140);
const _mid = Color(0xFF3B2B75);
const _violet = Color(0xFF8B5CF6);
const _pink = Color(0xFFFF5CA8);
const _orange = Color(0xFFFFA94D);
const _yellow = Color(0xFFFFD43B);
const _cyan = Color(0xFF66D9E8);
const _green = Color(0xFF69DB7C);
const _white = Color(0xFFFDFEFF);

void _bead(Canvas canvas, Rect r, Color color) {
  final hsl = HSLColor.fromColor(color);
  final light = hsl.withLightness((hsl.lightness + 0.18).clamp(0, 1)).toColor();
  final dark = hsl.withLightness((hsl.lightness - 0.18).clamp(0, 1)).toColor();
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.26));
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
        Rect.fromLTWH(
          r.left + r.width * 0.16,
          r.top + r.height * 0.12,
          r.width * 0.34,
          r.height * 0.2,
        ),
        Radius.circular(r.width * 0.12),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );
}

/// The icon: a potion flask packed with pixel beads. It fuses the two
/// things the game is about — bottles and pixel art — and the silhouette
/// still reads at 48 px.
void _paintIcon(Canvas canvas, Size size, {bool adaptive = false}) {
  final w = size.width, h = size.height;

  if (!adaptive) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mid, _deep],
        ).createShader(Offset.zero & size),
    );
    // Soft glow behind the subject.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.56),
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [_violet.withValues(alpha: 0.55), _violet.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.5, h * 0.56), radius: w * 0.42),
        ),
    );
  }

  // Adaptive foregrounds must stay inside the safe circle (~66% of canvas).
  final scale = adaptive ? 0.62 : 1.0;
  canvas
    ..save()
    ..translate(w / 2, h / 2)
    ..scale(scale)
    ..translate(-w / 2, -h / 2);

  final cx = w * 0.5, bodyCy = h * 0.60, bodyR = w * 0.30;

  // Glass body.
  canvas.drawCircle(
    Offset(cx, bodyCy),
    bodyR,
    Paint()..color = _white,
  );
  canvas.drawCircle(
    Offset(cx, bodyCy),
    bodyR - w * 0.035,
    Paint()..color = _deep,
  );

  // Pixel beads inside the flask, arranged as a tiny picture.
  const rows = [
    [_pink, _orange, _yellow],
    [_orange, _yellow, _cyan],
    [_cyan, _green, _pink],
  ];
  final cell = bodyR * 0.46;
  final gridTop = bodyCy - cell * 1.5;
  final gridLeft = cx - cell * 1.5;
  for (var y = 0; y < 3; y++) {
    for (var x = 0; x < 3; x++) {
      // Bottom-right bead is "already drained" — a nod to the mechanic.
      if (y == 2 && x == 2) continue;
      _bead(
        canvas,
        Rect.fromLTWH(
          gridLeft + x * cell + cell * 0.06,
          gridTop + y * cell + cell * 0.06,
          cell * 0.88,
          cell * 0.88,
        ),
        rows[y][x],
      );
    }
  }

  // Neck, collar and cork.
  final neck = Rect.fromCenter(
    center: Offset(cx, bodyCy - bodyR - h * 0.045),
    width: w * 0.17,
    height: h * 0.12,
  );
  canvas
    ..drawRect(neck, Paint()..color = _white)
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, neck.top),
          width: w * 0.26,
          height: h * 0.055,
        ),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = _white,
    );
  final corkBottom = neck.top - h * 0.012;
  final cork = Path()
    ..moveTo(cx, corkBottom - h * 0.14)
    ..lineTo(cx + w * 0.10, corkBottom - h * 0.04)
    ..quadraticBezierTo(
        cx + w * 0.085, corkBottom, cx + w * 0.04, corkBottom)
    ..lineTo(cx - w * 0.04, corkBottom)
    ..quadraticBezierTo(
        cx - w * 0.085, corkBottom, cx - w * 0.10, corkBottom - h * 0.04)
    ..close();
  canvas.drawPath(cork, Paint()..color = _orange);

  // Sparkles.
  for (final p in [
    Offset(w * 0.18, h * 0.30),
    Offset(w * 0.83, h * 0.24),
    Offset(w * 0.86, h * 0.68),
  ]) {
    final arm = w * 0.045;
    final paint = Paint()
      ..color = _yellow
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(p.translate(-arm, 0), p.translate(arm, 0), paint)
      ..drawLine(p.translate(0, -arm), p.translate(0, arm), paint);
  }

  canvas.restore();
}

void _text(
  Canvas canvas,
  String text,
  Offset topLeft, {
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
  final dx = align == TextAlign.center ? topLeft.dx - tp.width / 2 : topLeft.dx;
  tp.paint(canvas, Offset(dx, topLeft.dy));
}

/// 1024×500 Play Store header: brand left, product right.
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

  // Drifting beads in the background.
  const scatter = [
    [0.72, 0.18, 0.9],
    [0.80, 0.62, 0.7],
    [0.90, 0.34, 1.1],
    [0.64, 0.80, 0.6],
    [0.06, 0.80, 0.7],
    [0.12, 0.16, 0.55],
  ];
  const palette = [_pink, _cyan, _yellow, _green, _orange, _violet];
  for (var i = 0; i < scatter.length; i++) {
    final s = scatter[i];
    final side = 42.0 * s[2];
    _bead(
      canvas,
      Rect.fromLTWH(w * s[0], h * s[1], side, side),
      palette[i % palette.length].withValues(alpha: 0.85),
    );
  }

  // Title block.
  _text(canvas, 'COLORO', Offset(w * 0.07, h * 0.24), size: 96, weight: 700,
      shadows: const [
        Shadow(color: Color(0x99000000), offset: Offset(0, 4), blurRadius: 10),
      ]);
  _text(canvas, 'Drain the pixels. Reveal the art.',
      Offset(w * 0.075, h * 0.53),
      size: 34, weight: 600, color: const Color(0xFFCDC2F5));
  _text(canvas, '300 LEVELS  ·  NO WIFI NEEDED', Offset(w * 0.075, h * 0.70),
      size: 24, weight: 650, color: _yellow);

  // A framed mini board on the right, so the header shows the product.
  final boardSide = h * 0.62;
  final board = Rect.fromLTWH(
      w * 0.68, (h - boardSide) / 2, boardSide, boardSide);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(board.inflate(14), const Radius.circular(30)),
      Paint()..color = const Color(0xFF6C5DA8),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(20)),
      Paint()..color = const Color(0xFF150F2C),
    );
  const art = [
    [0, 1, 1, 0, 1, 1, 0],
    [1, 2, 2, 1, 2, 2, 1],
    [1, 2, 2, 2, 2, 2, 1],
    [0, 1, 2, 2, 2, 1, 0],
    [0, 0, 1, 2, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [3, 0, 0, 0, 0, 0, 3],
  ];
  final cell = board.width / 7.6;
  for (var y = 0; y < 7; y++) {
    for (var x = 0; x < 7; x++) {
      final v = art[y][x];
      final r = Rect.fromLTWH(
        board.left + cell * 0.3 + x * cell,
        board.top + cell * 0.3 + y * cell,
        cell * 0.86,
        cell * 0.86,
      );
      if (v == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22)),
          Paint()..color = _violet.withValues(alpha: 0.10),
        );
      } else {
        _bead(canvas, r, [_deep, _pink, _white, _yellow][v]);
      }
    }
  }
}

/// Wraps a live screenshot in a caption band, the layout that converts on
/// the Play store: one benefit line, one supporting line, product below.
void _composeScreenshot(
  Canvas canvas,
  Size size,
  ui.Image shot,
  String headline,
  String sub,
) {
  final w = size.width, h = size.height;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_mid, _deep],
      ).createShader(Offset.zero & size),
  );

  const bandH = 330.0;
  _text(canvas, headline, Offset(w / 2, 96),
      size: 74,
      weight: 700,
      align: TextAlign.center,
      maxWidth: w * 0.9,
      shadows: const [
        Shadow(color: Color(0x99000000), offset: Offset(0, 4), blurRadius: 12),
      ]);
  _text(canvas, sub, Offset(w / 2, 208),
      size: 38,
      weight: 600,
      color: const Color(0xFFBCAEE8),
      align: TextAlign.center,
      maxWidth: w * 0.86);

  // The device shot, scaled to fill the remaining space.
  final available = Rect.fromLTWH(0, bandH, w, h - bandH);
  final scale = (available.width * 0.92) / shot.width;
  final drawW = shot.width * scale, drawH = shot.height * scale;
  final dest = Rect.fromLTWH(
    (w - drawW) / 2,
    bandH + 24,
    drawW,
    drawH,
  );
  final rrect = RRect.fromRectAndRadius(dest, const Radius.circular(46));
  canvas
    ..drawRRect(
      rrect.shift(const Offset(0, 14)),
      Paint()..color = const Color(0x80000000),
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
        ..color = _violet.withValues(alpha: 0.6),
    );
}
