@Tags(['aso'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:coloro/app/coloro_app.dart';
import 'package:coloro/data/bottle_factory.dart';
import 'package:coloro/data/level_catalog.dart';
import 'package:coloro/game/game_controller.dart';
import 'package:coloro/screens/game/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the App-campaign video's gameplay frames from the REAL game —
/// the same guarantee as the ASO generator: an ad can never show something
/// the app doesn't do.
///
///   PROMO_OUT=/tmp/promo flutter test test/promo_video_test.dart
///
/// Frames land as `PROMO_OUT/scene/f_#####.png`, 1080x1920 at 30fps of
/// game time (dissolve runs at 3x). Assembly into the 15s cut is ffmpeg's
/// job — see marketing/MARKETING_PLAN.md §2.4 for the shot list.
///
/// It is a generator, not a check: without PROMO_OUT it does nothing.

const _frameMs = 33; // ~30fps of game time per captured frame

void main() {
  final outDir = Platform.environment['PROMO_OUT'];

  setUpAll(() async {
    // Same font bootstrap as the ASO generator: without it every HUD label
    // and card renders as tofu bars.
    final data = rootBundle.load('assets/fonts/Fredoka.ttf');
    await (FontLoader('Fredoka')..addFont(data)).load();
    final root = Platform.environment['FLUTTER_ROOT'] ??
        (() {
          final exe =
              Process.runSync('which', ['flutter']).stdout.toString().trim();
          return exe.isEmpty ? '' : File(exe).parent.parent.path;
        })();
    final iconFont = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFont.existsSync()) {
      final bytes = iconFont.readAsBytesSync();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();
    }
  });

  Future<GameDrive> boot(WidgetTester tester, {required int levelIndex}) async {
    SharedPreferences.setMockInitialValues({'unlocked_level': 300});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RepaintBoundary(child: ColoroApp()));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final catalog = await tester.runAsync(LevelCatalog.load);
    final level = catalog!.levels[levelIndex];
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

    // Reconstruct the deal from the untouched tray (dealt round-robin) and
    // let the real solver hand back a proven winning dock order to replay.
    final dyn = game as dynamic;
    final List<List> tray = [for (var c = 0; c < 4; c++) dyn.tray[c] as List];
    final total = tray.fold<int>(0, (n, col) => n + col.length);
    final deal = <dynamic>[
      for (var i = 0; i < total; i++) tray[i % 4][i ~/ 4],
    ];
    final order = await tester.runAsync(() async =>
        BottleFactory.solveDealOrder(dyn.grid, deal.cast()));
    return GameDrive(tester, game, trayFinder, outDir!,
        orderIds: [for (final b in order ?? deal) b.id as int]);
  }

  testWidgets('caption strips', (tester) async {
    if (outDir == null) return;
    const lines = [
      'Pick a bottle.',
      'It drinks the picture.',
      'Pick wrong, it jams.',
      '300 levels.',
    ];
    for (var i = 0; i < lines.length; i++) {
      await tester.runAsync(() async {
        const w = 1080, h = 160;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final tp = TextPainter(
          text: TextSpan(
            text: lines[i],
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 66,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pill = Rect.fromCenter(
          center: const Offset(w / 2, h / 2),
          width: tp.width + 96,
          height: tp.height + 44,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(pill, Radius.circular(pill.height / 2)),
          Paint()..color = const Color(0xC225103F),
        );
        tp.paint(canvas,
            Offset((w - tp.width) / 2, (h - tp.height) / 2));
        final image =
            await recorder.endRecording().toImage(w, h);
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/caption_$i.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('play scene', (tester) async {
    if (outDir == null) return;
    final d = await boot(tester, levelIndex: 44); // level 45 — 7 colours

    // A: the fresh board holds for a beat, then the first bottle goes in.
    await d.capture('play', frames: 20);
    await d.tapBest();
    await d.capture('play', frames: 46);

    // B: keep the machine fed so the picture visibly drains. Captured at
    // 1.5x game speed — the real fill rate reads as too slow in a 4s shot.
    for (var burst = 0; burst < 8; burst++) {
      await d.tapBest();
      await d.capture('play', frames: 15, stepMs: 50);
    }

    // Fast-forward (uncaptured) toward the endgame, stopping well short of
    // completion so the dissolve still has a board to eat.
    var guard = 0;
    while ((d.game.progress as double) < 0.70 &&
        d.game.phase == GamePhase.playing &&
        guard++ < 4000) {
      await d.tapBest();
      await tester.pump(const Duration(milliseconds: 100));
    }

    // D: the dissolve, 3x speed, through completion and the win sweep.
    guard = 0;
    while (d.game.phase == GamePhase.playing && guard++ < 400) {
      await d.tapBest();
      await d.capture('dissolve', frames: 1, stepMs: 100);
    }
    await d.capture('dissolve', frames: 36, stepMs: 100);

    // Let the win card's one-shot timers fire so teardown finds none.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('jam scene', (tester) async {
    if (outDir == null) return;
    final d = await boot(tester, levelIndex: 44);

    // Feed the machine in REVERSE tray order — the deal approximates a
    // winning order, so the back of the tray is maximally wrong and the
    // slots starve fast. Capture everything; the edit picks the red pulse.
    var guard = 0;
    while (d.game.phase == GamePhase.playing && guard++ < 240) {
      await d.tapWorst();
      await d.capture('jam', frames: 1);
    }
    await d.capture('jam', frames: 20);

    // Let the fail card's one-shot timers fire so teardown finds none.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });
}

/// Drives one GameScreen and writes numbered PNG frames per scene.
class GameDrive {
  GameDrive(this.tester, this.game, this.trayFinder, this.outDir,
      {required this.orderIds});

  final WidgetTester tester;
  final dynamic game; // GameController — typed dynamic to reach debug API.
  final Finder trayFinder;
  final String outDir;
  final List<int> orderIds;
  int _ptr = 0;
  final Map<String, int> _frame = {};

  /// Dock the next bottle of the solver's winning line, as soon as a slot
  /// is free and that bottle is a column head. Replaying a proven order is
  /// what lets the whole level be played to completion on camera.
  Future<void> tapBest() async {
    if (!(game.hasFreeSlot as bool)) return;
    if (_ptr >= orderIds.length) return;
    final want = orderIds[_ptr];
    for (var c = 0; c < 4; c++) {
      final List col = game.tray[c] as List;
      if (col.isNotEmpty && (col.first.id as int) == want) {
        await tester.tap(trayFinder.at(c), warnIfMissed: false);
        _ptr++;
        return;
      }
    }
  }

  /// Tap the rightmost non-empty tray head, preferring one that CANNOT
  /// drink — the wrong-bottle move the jam scene needs.
  Future<void> tapWorst() async {
    if (!(game.hasFreeSlot as bool)) return;
    for (var c = 3; c >= 0; c--) {
      final List col = game.tray[c] as List;
      if (col.isEmpty) continue;
      if ((game.takableCountFor(col.first.colorIndex as int) as int) == 0) {
        await tester.tap(trayFinder.at(c), warnIfMissed: false);
        return;
      }
    }
    for (var c = 3; c >= 0; c--) {
      final List col = game.tray[c] as List;
      if (col.isNotEmpty) {
        await tester.tap(trayFinder.at(c), warnIfMissed: false);
        return;
      }
    }
  }

  Future<void> capture(String scene, {required int frames, int stepMs = _frameMs}) async {
    final dir = Directory('$outDir/$scene')..createSync(recursive: true);
    for (var i = 0; i < frames; i++) {
      await tester.pump(Duration(milliseconds: stepMs));
      final boundary = find
          .byType(RepaintBoundary)
          .evaluate()
          .first
          .renderObject! as RenderRepaintBoundary;
      final n = _frame[scene] = (_frame[scene] ?? 0) + 1;
      await tester.runAsync(() async {
        final raw = await boundary.toImage(pixelRatio: 3);
        final bytes = await raw.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/f_${n.toString().padLeft(5, '0')}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        raw.dispose();
      });
    }
  }
}
