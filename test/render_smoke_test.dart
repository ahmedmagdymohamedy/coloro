import 'dart:io';
import 'dart:ui' as ui;

import 'package:coloro/app/coloro_app.dart';
import 'package:coloro/data/level_catalog.dart';
import 'package:coloro/game/game_controller.dart';
import 'package:coloro/screens/game/game_screen.dart';
import 'package:coloro/screens/game/widgets/level_complete_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the real menu and game screens at phone size and dumps PNG
/// captures (when COLORO_RENDER_DIR is set) so a human can eyeball them.
/// Also acts as an end-to-end smoke test of asset loading + level
/// processing + gameplay wiring.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load the real display font so captures aren't Ahem boxes.
    final data = rootBundle.load('assets/fonts/Fredoka.ttf');
    final loader = FontLoader('Fredoka')..addFont(data);
    await loader.load();
  });

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['COLORO_RENDER_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final element = find.byType(RepaintBoundary).evaluate().first;
      final boundary = element.renderObject! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('menu and gameplay render end-to-end', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const RepaintBoundary(child: ColoroApp()),
    );

    // Let catalog/progress/preview futures complete with real async.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PLAY'), findsOneWidget);
    await capture(tester, '1_menu');

    // Open level 2 (built-in heart pixel art) directly.
    final catalog = await tester.runAsync(LevelCatalog.load);
    final level = catalog!.levels[1];
    final context = tester.element(find.text('PLAY'));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GameScreen(level: level, hasNextLevel: true),
    ));

    // Finish the route transition, then wait until the level is processed
    // (decode/quantize isolate + atlas build need real async).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final trayFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TrayColumn',
    );
    for (var attempt = 0;
        attempt < 20 && trayFinder.evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GameScreen), findsOneWidget);
    await capture(tester, '2_game_loaded');

    // Launch the workable tray bottles and let the machine spray.
    expect(trayFinder, findsWidgets);
    final warmupGame = tester
        .state<GameScreenState>(find.byType(GameScreen))
        .debugGame!;
    for (var i = 0; i < 4; i++) {
      final column = warmupGame.tray[i];
      if (column.isNotEmpty &&
          warmupGame.takableCountFor(column.first.colorIndex) > 0) {
        await tester.tap(trayFinder.at(i), warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 120));
    }

    // Let the simulation run a while (ticker advances with pump).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture(tester, '3_game_midplay');

    // The board should visibly be filling up.
    final progressText = find.textContaining('%');
    expect(progressText, findsOneWidget);

    // Play like a decent human until the picture completes: only launch
    // bottles whose color is currently exposed on the picture's edge, and
    // park at most one waiting bottle while keeping a slot free.
    final game = tester
        .state<GameScreenState>(find.byType(GameScreen))
        .debugGame!;
    final overlayFinder = find.byType(LevelCompleteOverlay);
    for (var i = 0; i < 14000 && overlayFinder.evaluate().isEmpty; i++) {
      if (game.phase == GamePhase.playing) {
        // Dock a color only when there is spare work beyond the capacity
        // already docked for it — greedy same-color stacking self-jams.
        int spareWork(int color) {
          final docked = game.slots
              .where((s) => s != null && s.bottle.colorIndex == color)
              .fold<int>(0, (a, s) => a + s!.remaining);
          return game.takableCountFor(color) - docked;
        }

        var tapped = false;
        for (var c = 0; c < 4; c++) {
          final column = game.tray[c];
          if (column.isEmpty || !game.hasFreeSlot) continue;
          if (spareWork(column.first.colorIndex) > 0) {
            await tester.tap(trayFinder.at(c), warnIfMissed: false);
            tapped = true;
          }
        }
        if (!tapped) {
          // Dig: park fronts of the column whose nearest workable bottle
          // is shallowest, always keeping one slot free for it.
          final freeSlots = game.slots.where((s) => s == null).length;
          if (freeSlots >= 2) {
            int? best;
            var bestDepth = 1 << 30;
            for (var c = 0; c < 4; c++) {
              final col = game.tray[c];
              for (var k = 0; k < col.length; k++) {
                if (spareWork(col[k].colorIndex) > 0) {
                  if (k < bestDepth) {
                    bestDepth = k;
                    best = c;
                  }
                  break;
                }
              }
            }
            if (best != null) {
              await tester.tap(trayFinder.at(best), warnIfMissed: false);
            }
          }
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.phase, isNot(GamePhase.failed),
        reason: 'smart play should never jam the machine');
    expect(overlayFinder, findsOneWidget);

    // Let the card spring in and the stars ding.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Level Complete!'), findsOneWidget);
    expect(find.text('NEXT LEVEL'), findsOneWidget);
    await capture(tester, '4_complete');
  });
}
